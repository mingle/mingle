#  Copyright 2020 ThoughtWorks, Inc.
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as
#  published by the Free Software Foundation, either version 3 of the
#  License, or (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#  
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.

class DependenciesImporter
  include ProgressBar
  include DeliverableImportExport::ImportFileSupport
  include DeliverableImportExport::SQLBindSupport
  include DeliverableImportExport::RecordImport
  include DeliverableImportExport::ImportUsers
  include DeliverableImportExport::ImportAttachments
  include DependenciesImportSupport

  attr_accessor :user, :progress, :directory, :import_preview_request
  attr_reader :history_generated_for
  delegate :status, :progress_message, :error_count, :warning_count, :total, :completed, :to => :@progress
  delegate :status=, :progress_message=, :error_count=, :warning_count=, :total=, :completed=, :to => :@progress

  RESOLVING_OUR_OWN_ASSOCIATIONS = [
    { :table => Dependency.table_name, :column => "raising_project_id" },
    { :table => Dependency.table_name, :column => "resolving_project_id" },
    { :table => Dependency.table_name, :column => "raising_card_number" },
    { :table => Dependency::Version.table_name, :column => "raising_project_id" },
    { :table => Dependency::Version.table_name, :column => "resolving_project_id" },
    { :table => Dependency::Version.table_name, :column => "raising_card_number" },
    { :table => DependencyResolvingCard.table_name, :column => "project_id" },
    { :table => Attachment.table_name, :column => "project_id" },
    { :table => Event.table_name, :column => "deliverable_id" },
  ]

  def self.fromActiveMQMessage(message)
    new.tap do |importer|
      importer.progress = AsynchRequest.find(message[:request_id])
      importer.import_preview_request = AsynchRequest.find(message[:import_preview_asynch_request_id])
      importer.user = User.find(message[:user_id])
      importer.mark_new
    end
  end

  def mark_new
    @progress.update_progress_message("Dependencies import has been queued. Please wait here for import to begin.")
    @progress.mark_queued
  end

  def process!
    @progress.with_progress do |in_progress|
      begin
        @progress.step("Extracting import file") {
          self.directory = unzip_export(@import_preview_request.exported_package, "dependencies")
        }
        import_tables
      rescue Exception => e
        log_error(e, e.message)
        update_progress(e.message)
      end
    end
  end

  def import_tables
    begin

      table("deliverables", Project)
      import_users(table("users", User)) # import before dependencies so raising_user_id can resolve users

      import_table(table(Dependency.table_name, Dependency), &select_previewed_dependencies_and_update_dependency_numbers)
      import_table(table(Dependency::Version.table_name, Dependency::Version), &select_previewed_dependencies_and_update_dependency_numbers)

      # happens AFTER dependencies imported because we need to associate raising_user_id with raising_project_id
      ensure_raising_users_have_project_membership

      import_table(table(DependencyResolvingCard.table_name, DependencyResolvingCard)) do |record, old_id, new_id|
        dependency_was_imported?(record["dependency_id"], record["dependency_type"]) && card_exists_in_project?(record["project_id"], record["card_number"])
      end

      import_attachments(table(Attachment.table_name, Attachment))
      import_attachings(["Dependency", "Dependency::Version"]) do |record, old_id, new_id|
        dependency_was_imported?(record["attachable_id"], record["attachable_type"])
      end

      import_table(table("events", Event)) do |record, old_id, new_id|
        record["type"] == "DependencyVersionEvent" && dependency_was_imported?(record["origin_id"], record["origin_type"])
      end

      ensure_history_generated_for_events

      # because resolving cards may or may not have been imported, status needs to be recalculated
      ensure_dependency_status_recalculated

    rescue Exception => e
      log_error(e, e.message)
      raise e
    end
  end

  def resolving_our_own_associations
    RESOLVING_OUR_OWN_ASSOCIATIONS
  end

  def resolve_your_own_associations(real_model, table, record)
    resolve_project_and_card_associations_on_dependencies(real_model, table, record)
    resolve_project_associations(real_model, table, record)
  end

  def resolve_project_and_card_associations_on_dependencies(real_model, table, record)
    return unless is_class_or_subclass_of?([Dependency, Dependency::Version], real_model)

    raising_project = database_project(record['raising_project_id'])
    record['raising_project_id'] = raising_project.id
    record['resolving_project_id'] = database_project(record['resolving_project_id']).id

    resolve_raising_card_associations(raising_project, record)
  end

  def resolve_project_associations(real_model, table, record)
    return unless is_class_or_subclass_of?([DependencyResolvingCard, Attachment, Event], real_model)

    record["project_id"] = database_project(record["project_id"]).id if record.has_key?("project_id")
    record["deliverable_id"] = database_project(record["deliverable_id"]).id if record.has_key?("deliverable_id") && record["deliverable_type"] == "Project"
  end

  def resolve_raising_card_associations(raising_project, record)
    raising_project.with_active_project do |proj|
      dep_hash = preview_dependencies_to_import[record["number"]]
      next unless dep_hash
      raising_card_number = dep_hash["raising_card"]["number"]
      database_raising_card = proj.cards.find_by_number(raising_card_number)
      record['raising_card_number'] = database_raising_card.number.to_i
    end
  end

  def for_each_imported_dependency_number(&block)
    return unless block_given?
    @dep_number_map.each_slice(25) do |slice|
      slice.each do |old_number, new_number|
        block.call(new_number)
      end
    end
  end

  def ensure_dependency_status_recalculated
    for_each_imported_dependency_number do |number|
      dependency = Dependency.find_by_number(number)
      dependency.recalculate_status.tap do |new_status|
        dependency.update_attribute(:status, new_status) unless new_status == dependency.status
      end
    end
  end

  def ensure_history_generated_for_events
    @history_generated_for ||= []
    for_each_imported_dependency_number do |number|
      dependency = Dependency.find_by_number(number)
      [dependency.raising_project_id, dependency.resolving_project_id].each do |project_id|
        unless @history_generated_for.include?(project_id)
          Project.find(project_id).with_active_project do |project|
            project.generate_changes
          end
          @history_generated_for << project_id
        end
      end
    end
  end

  def ensure_raising_users_have_project_membership
    for_each_imported_dependency_number do |number|
      dep = Dependency.find_by_number(number)
      dep.raising_project.with_active_project do |project|
        project.add_member(dep.raising_user) unless project.member?(dep.raising_user) || dep.raising_user.system?
      end
    end
  end

  def select_previewed_dependencies_and_update_dependency_numbers
    Proc.new do |record, old_id, new_id|
      preview_dependencies_to_import.has_key?(record["number"]).tap do |result|
        record["number"] = get_new_number_from_old_number(record["number"]) if result
      end
    end
  end

  def card_exists_in_project?(project_id, card_number)
    Project.find(project_id.to_i).with_active_project do |project|
      project.cards.find_by_number(card_number.to_i).present?
    end
  end

  def dependency_was_imported?(dependency_id, dependency_model_name)
    dependency_model_name.constantize.count(:conditions => ["id = ?", dependency_id.to_i]) > 0
  end

  def is_class_or_subclass_of?(classes, model)
    classes.any? do |klass|
      model <= klass
    end
  end

  def next_dep_number
    next_number = Sequence.find_table_sequence('dependency_numbers').next
    Dependency.find_by_number(next_number).blank? ? next_number : next_dep_number
  end

  def get_new_number_from_old_number(old_number)
    @dep_number_map ||= {}
    @dep_number_map[old_number] ||= next_dep_number
  end

  def preview_dependencies_to_import
    @import_preview_request.dependencies_to_import.inject({}) do |map, dep|
      map[dep["number"]] = dep
      map
    end
  end
  memoize :preview_dependencies_to_import
end
