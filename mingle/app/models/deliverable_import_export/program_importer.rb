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

module DeliverableImportExport

  require 'deliverable_import_export/program_export'

  class ProgramImporter
    include DeliverableImportExport::ImportFileSupport
    include SQLBindSupport
    include RecordImport
    include ExportFileUpgrade
    include ImportUsers

    delegate :step, :to => :@progress
    attr_accessor :directory

    RESOLVING_OUR_OWN_ASSOCIATIONS = [ { :table => "objective_filters", :column => "project_id"},
                                       { :table => "program_projects", :column => "project_id"},
                                       { :table => "program_projects", :column => "program_id"},
                                       { :table => "program_projects", :column => "done_status_id"},
                                       { :table => "program_projects", :column => "status_property_id"},
                                       { :table => "user_memberships", :column => "group_id"},
                                       { :table => "works", :column => "project_id"}
                                      ]

    def self.fromActiveMQMessage(message)
      progress = AsynchRequest.find message[:request_id]
      self.new(progress)
    end

    def initialize(progress)
      @progress = progress
      self.directory = unzip_export(progress.localize_tmp_file)
      init_tables
    end

    def process!
      Rails.logger.info("start importing a program")
      @progress.with_progress do
        upgrade_if_needed

        missing_project_names = missing_projects
        if missing_project_names.any?
          @progress.add_error projects_missing_error_message(missing_project_names)
          return
        end

        begin
          @progress.step("Create Program") { create_program }

          import_objective_types
          import_table(table('objectives', Objective))

          @program.reset_objective_number_sequence

          import_table(table('objective_filters', ObjectiveFilter))

          import_table(table('program_projects', ProgramProject))
          import_works
          import_users(table('users', User))
          import_table(table("user_memberships", UserMembership)) do |record, old_id, new_id|
            record["group_id"] != @program.team.id || (record["group_id"] == @program.team.id && record["user_id"] != User.current.id)
          end

          grant_program_access_to_members
          trigger_objective_sync
          @progress.step("Take snapshots") { take_snapshots }
          @progress.mark_completed_successfully
          @program.cache_key.touch_feed_key
        rescue => e
          @program.destroy rescue nil
          @program = nil
          raise e
        end
      end
      Rails.logger.info("finished importing program: #{@program.try(:identifier)}")
      @program
    end

    def use_new_import_dir(export_file)
      self.directory = unzip_export(export_file)
      init_tables
    end

    private

    def projects_missing_error_message(project_names)
      "Unable to locate the following projects. Make sure you have already migrated all projects to the new instance." +
        "<ul>" +
          "#{project_names.map { |name| "<li><b>#{name.escape_html}</b></li>"}.join('')}" +
        "</ul>"
    end

    def init_tables
      @table_by_model = {}
      @tables = ImportExport::TableModels.new(self.directory)
    end

    def missing_projects
      project_ids = table('program_projects', ProgramProject).map { |record| record['project_id'].to_i }
      names_for_missing_projects = []
      project_ids.each do |project_id_in_export|
        project_record = table('deliverables', Project).find { |d| d['type'] == 'Project' && d['id'].to_s == project_id_in_export.to_s }
        project = Project.find_by_identifier(project_record['identifier'])
        names_for_missing_projects << project_record['name'] if project.nil?
      end

      names_for_missing_projects
    end

    def grant_program_access_to_members
        @program.users.each do |member|
        @program.member_roles.setup_user_role(member, nil)
      end
    end

    def trigger_objective_sync
      objectives = @program.objectives.planned.reload
      @program.projects.each do |project|
        if objectives.any? {|objective| objective.auto_sync?(project) }
          SyncObjectiveWorkProcessor.enqueue(project.id)
        end
      end
    end

    def import_works
      import_table(table('works', Work))
      @program.program_projects.each do |program_project|
        raise "Project #{program_project.project.name.bold} has been updated after the plan was exported.  Please delete and re-import this project before importing the plan." if program_project.works.any?(&:invalid?)
        program_project.refresh_completed_status_of_work!
      end
    end

    def import_objective_types
      @program.objective_types.destroy_all

      import_table(table('objective_types', ObjectiveType))
    end

    def resolve_your_own_associations(real_model, table, record)
      resolve_program_membership_group(real_model, table, record)
      resolve_plan_to_project_associations(real_model, table, record)
      resolve_program_project(real_model, table, record)
    end

    def resolve_program_membership_group(real_model, table, record)
      return if real_model != UserMembership
      record['group_id'] = @program.groups.first.id
    end

    def resolve_program_project(real_model, table, record)
      return if real_model != ProgramProject

      database_id = map_export_project_id_to_database_project_id(record['project_id'])
      record['project_id'] = database_id
      record['program_id'] = @program.id

      project = Project.find(database_id)
      property_definition_record = table('property_definitions', PropertyDefinition).find { |pd| pd['id'] == record['status_property_id'] }
      enumeration_value_record = table('enumeration_values', EnumerationValue).find { |ev| ev['id'] == record['done_status_id'] }
      return unless property_definition_record && enumeration_value_record

      begin
        existing_property_definition = project.find_property_definition(property_definition_record['name'], {:with_hidden => true})
      rescue => e
        raise "#{e} in #{project.name}"
      end
      record['status_property_id'] = existing_property_definition.id
      enumeration_value = existing_property_definition.find_enumeration_value(enumeration_value_record['value'])
      raise "Property #{existing_property_definition.name.bold} does not have value #{enumeration_value_record['value'].bold} in #{project.name}" unless enumeration_value
      record['done_status_id'] = enumeration_value.id
    end

    def resolve_plan_to_project_associations(real_model, table, record)
      return unless real_model == Work || real_model == ObjectiveFilter
      record['project_id'] = map_export_project_id_to_database_project_id(record['project_id'])
    end

    def map_export_project_id_to_database_project_id(project_id_in_export)
      project_record = table('deliverables', Project).find { |d| d['type'] == 'Project' && d['id'] == project_id_in_export }
      project = Project.find_by_identifier(project_record['identifier'])
      raise "Unable to locate project, #{project_record['name']}. Make sure you have already migrated all projects to new instance." if project.nil?
      project.id.to_s
    end

   # probably some stuff can be shared with project version of this
    def table(table_name, model = nil)
      return nil unless yaml_file_exists?(self.directory, table_name)
      import_export_table = @tables.table(table_name, model)
      @table_by_model[model] = import_export_table if model
      import_export_table
    end

    def plugins_valid?
      true
    end

    def resolving_our_own_associations
      RESOLVING_OUR_OWN_ASSOCIATIONS
    end

    def create_objectives
      records = table('objectives').to_a
      records.each { |fields| Objective.create!(fields.merge!(:plan_id => @program.plan.id)) }
    end

    def create_program
      plans_table = table('plans', Plan)
      plans_table.imported = true

      plan_record = plans_table.first

      @program = Program.create!(unique_name_and_identifier)
      @program.plan.update_attributes :start_at => plan_record['start_at'], :end_at => plan_record['end_at']
      @progress.deliverable_identifier = @program.identifier
      @progress.progress_message = "Import is starting..."
      @progress.total = table_names_from_file_names.size
      @progress.completed = 0
      @progress.mark_queued
      @progress.save!

      program_table = table('deliverables',Program)
      program_table.map_ids(@old_id, @program.id)
      program_table.imported = true

      plans_table.map_ids(plan_record['id'], @program.plan.id)
    end

    def take_snapshots
      ObjectiveSnapshot.enqueue_snapshot_for(@program.plan)
    end

    def unique_name_and_identifier
      program_record = table('deliverables', Program).first_of_type(Program)
      unique_name = Program.unique(:name, program_record['name'])
      unique_identifier = Program.unique(:identifier, program_record['identifier'])
      @old_id = program_record['id']
      {:identifier => unique_identifier, :name => unique_name}
    end

    def schema_incompatible
      DeliverableImportExport::ExportFileUpgrade::SchemaIncompatible.new('The program you tried to import is from a newer version of Mingle than this version. Downgrades are not supported. Please select a different program and try importing again.')
    end
  end
end
