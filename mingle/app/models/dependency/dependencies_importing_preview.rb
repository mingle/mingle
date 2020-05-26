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

class DependenciesImportingPreview
  include ProgressBar
  include DeliverableImportExport::ImportFileSupport
  include DeliverableImportExport::ExportFileUpgrade
  include DependenciesImportSupport

  attr_accessor :user, :progress, :directory
  delegate :status, :progress_message, :error_count, :warning_count, :total, :completed, :to => :@progress
  delegate :status=, :progress_message=, :error_count=, :warning_count=, :total=, :completed=, :to => :@progress

  def self.export_after_upgrade(identifier, projects, import_directory)
    upgrade_user = if User.count == 0
      User.create!(:name => 'upgrade user', :login => 'mingle', :email => 'upgradeuser@example.com', :password => 'p', :password_confirmation => 'p')
    else
      User.find(:first)
    end

    models, select_sql = DependenciesExport.models, DependenciesExporter::SQL_METHOD

    temporary_directory = RailsTmpDir::DependenciesExport.new_temporary_directory(identifier)
    basedir = temporary_directory.dirname

    table = ImportExport::TableWithModel.new(basedir, 'schema_migrations', nil)
    table.write("SELECT * FROM #{ActiveRecord::Base.connection.safe_table_name('schema_migrations')}", Dependency.connection)

    models.each do |model|
      table_name = model.table_name
      if table_name =~ /^#{ActiveRecord::Base.table_name_prefix}(.*)/
        table_name = $1
      end
      table = ImportExport::TableWithModel.new(basedir, table_name, model)
      table.write_pages(select_sql, projects)
    end
    ['attachments*', 'user', 'project'].each do |dir|
      Dir.glob(File.join(import_directory, dir)) do |dir|
        FileUtils.mv(dir, basedir)
      end
    end
    basedir
  end

  def self.fromActiveMQMessage(message)
    new.tap do |preview|
      preview.progress = AsynchRequest.find message[:request_id]
      preview.user = User.find message[:user_id]
      preview.mark_queued
    end
  end

  def process!
    @progress.with_progress do |in_progress|
      begin
        @progress.step("Extracting import file") {
          set_directory unzip_export(@progress.localize_tmp_file, "dependencies")
        }
        @progress.step("Creating importing dependencies preview") { create_importing_dependencies_preview }
      rescue Zipper::InvalidZipFile => e
        log_error(e, e.message)
        @progress.add_error_view('invalid_import_file')
        update_progress("Invalid import file")
      rescue ProjectNotFoundException => e
        log_error(e, e.message)
        @progress.add_error_view("project_not_found")
        update_progress("Could not find raising or resolving project")
      rescue Exception => e
        log_error(e, e.message)
        update_progress(e.message)
      end
    end
  end

  def plugins_valid?
    true
  end

  def use_new_import_dir(export_file)
    set_directory(export_file)
    @tables = {}
    @table_by_model = {}
  end

  def set_directory(exported_directory)
    clear_tmp_files
    @export_file = exported_directory
    self.directory = exported_directory
  end

  def clear_tmp_files
    return if MingleConfiguration.no_cleanup?
    if @export_file && File.exists?(@export_file)
      FileUtils.rm_rf(@export_file) if @export_file
    end
    FileUtils.rm_rf(directory) if directory
  rescue => e
    Kernel.log_error(e, 'clear project import tmp files failed', :force_full_trace => true)
  end

  def create_importing_dependencies_preview
    upgrade_if_needed

    table("deliverables", Project)
    dependencies = table("dependencies", Dependency)
    table("dependency_resolving_cards", Dependency)

    dependencies.each do |record|
      if !can_be_imported(record)
        raise ::ProjectNotFoundException
      end
      dep_hash = create_dependency(record)
      dep_hash["raising_card"] ? @progress.add_dependency(dep_hash) : @progress.add_dependencies_error(dep_hash)
    end

    @progress.set_exploded_directory(self.directory)
  end

  def create_dependency(dependency_record)
    dependency_hash = {}
    dependency_hash['name'] = dependency_record['name']
    dependency_hash['number'] = dependency_record['number']
    dependency_hash['resolving_project'] =  create_project_hash(dependency_record["resolving_project_id"])
    dependency_hash['raising_project'] =  create_project_hash(dependency_record["raising_project_id"])
    dependency_hash['raising_card'] =  create_card_hash(dependency_record["raising_project_id"], dependency_record["raising_card_number"])
    dependency_hash['resolving_cards'] = resolving_cards_hash(dependency_record["id"], dependency_record["resolving_project_id"])
    dependency_hash
  end

  def with_local_project(project_id, &block)
    result = nil
    database_project(project_id).with_active_project do |project|
      result = block.call(project) if block_given?
    end
    result
  end

  def create_project_hash(project_id)
    project = project_record(project_id)
    {"name" => project["name"], "identifier" => project["identifier"]}
  end

  def resolving_cards_hash(dependency_id, project_id)
    with_local_project(project_id) do |project|
      imported_dependency_resolving_cards.inject([]) do |memo, dep_res_card|
        if dep_res_card["dependency_id"] == dependency_id
          card = project.cards.find_by_number(dep_res_card["card_number"].to_i)
          memo << {"number" => card.number, "name" => card.name} if card.present?
        end
        memo
      end
    end
  end

  def create_card_hash(project_id, card_number)
    card = with_local_project(project_id) do |project|
      project.cards.find_by_number(card_number.to_i)
    end
    return nil unless card.present?

    {"number" => card.number, "name" => card.name}
  end

  def can_be_imported(record)
    project_exists(record['raising_project_id']) && project_exists(record['resolving_project_id'])
  end

  def project_exists(project_id)
    project_record(project_id) && Project.exists?(:identifier => project_record(project_id)["identifier"])
  end

  def imported_dependency_resolving_cards
    dependency_resolving_cards = []
    @tables['dependency_resolving_cards'].each do |record|
      dependency_resolving_cards << record if record["dependency_type"] == "Dependency"
    end
    dependency_resolving_cards
  end
  memoize :imported_dependency_resolving_cards

end

class ProjectNotFoundException < StandardError; end
