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
  class ProjectImporter
    include ProgressBar
    include ImportFileSupport
    include SqlHelper
    include SQLBindSupport
    include RecordImport
    include ExportFileUpgrade
    include ImportUsers
    include ImportAttachments

    attr_accessor :user, :progress, :project_identifier, :project_name, :directory, :export_file_size, :export_file
    delegate :status, :progress_message, :error_count, :warning_count, :total, :completed, :to => :@progress
    delegate :status=, :progress_message=, :error_count=, :warning_count=, :total=, :completed=, :to => :@progress

    RESOLVING_OUR_OWN_ASSOCIATIONS = [
      { :table => "transition_actions" },
      { :table => "property_definitions", :column => "aggregate_target_id" }
    ]

    CONTENT_MODEL_TYPES = [
      "Card",
      "Card::Version",
      "Page",
      "Page::Version"
    ]

    module MigrationProject
      def all_property_definitions
        property_definitions_with_hidden_for_migration
      end

      def property_definitions_with_hidden
        property_definitions_with_hidden_for_migration
      end
    end

    class PluginNotExistError < StandardError; end

    class PluginNeedUpgradeError < StandardError; end

    def resolving_our_own_associations
      RESOLVING_OUR_OWN_ASSOCIATIONS
    end

    def self.fromActiveMQMessage(message)
      progress = AsynchRequest.find message[:request_id]
      self.new(:progress => progress)
    end

    def self.for_synchronous_import(project_name, project_identifier, export_file, asynch_request)
      self.new(:progress => asynch_request).tap do |import|
        import.set_directory(export_file)
        import.create_project_if_needed(project_name, project_identifier)
      end
    end

    def self.for_synchronous_import_into_existing_project(project, export_file, asynch_request)
      self.new(:progress => asynch_request).tap do |import|
        import.set_directory(export_file)
        import.project = project
      end
    end

    def initialize(attributes={})
      attributes.each { |k,v| self.send("#{k}=", v) }
      @newly_created_user_ids = []
    end

    def created_by
      progress.user
    end

    def set_directory(export_file)
      clear_tmp_files
      @export_file = export_file
      self.export_file_size = File.exists?(export_file) ? File.size(export_file) : 0
      self.directory = unzip_export(export_file)
    end

    def use_new_import_dir(export_file)
      set_directory(export_file)
      @tables = {}
      @table_by_model = {}
    end

    def project
      migration_project.extend(MigrationProject)
    end

    def project=(project)
      @project = project
    end

    def migration_project
      @project
    end

    def progress
      if defined?(@progress)
        return @progress
      else
        AsynchRequest::NullProgress.new
      end
    end

    def queue_empty?
      progress.queue_empty?
    end

    # this happens synchronously when starting the import process
    # should be relatively swift but should do as much validation as possible
    def save_file(zip_file)
      save_file_without_creating_project(zip_file)
      create_project_if_needed(project_name, project_identifier)
    end

    def create_project_if_needed(project_name, project_identifier, pre_defined_template=nil)
      unless self.project
        # will always use User.current because it uses the Project class
        self.project = create_project(project_name, project_identifier, pre_defined_template)
        return self if project.errors.any?
      end

      progress.update_attributes(
                                 :progress_message => "Import is starting...",
                                 :total => totals_for_progress,
                                 :completed => 0
                                 )
      self
    end

    def totals_for_progress
      table_names_from_file_names.size
    end


    # is run on a separate thread (or process)
    # should set up environment such as current project and user
    def import(options = {})
      created_by.with_current do
        step("Upgrading project...") do
          upgrade_if_needed
        end

        unless self.project
          step("Creating project") { self.project = create_project }
        end

        project.with_active_project do
          logger.info("start importing: #{project.identifier}")

          attachable_types = []
          if include_content = !importing_template?
            attachable_types = CONTENT_MODEL_TYPES
          end

          reset_timestamps = options.has_key?(:reset_timestamps) ? options[:reset_timestamps] : false
          # is imported by save_file but does not get persisted
          step("Importing schema_info...") do
            table('schema_migrations').imported = true
            if table('plugin_schema_info')
              table('plugin_schema_info').imported = true
            end
          end

          # this just records the id of the new project
          step("Importing project...") do
            import_project(project, table(Project.table_name))
          end

          users_table = table('users')
          if users_table
            step("Importing users") do
              import_users(table('users'), @newly_created_user_ids)
              import_groups
            end
          end

          import_table(table('card_types'))
          import_table(table('tree_configurations'))
          import_table(table('property_definitions'))
          import_table(table('property_type_mappings'))

          step("Updating card schema") do
            project.reload.update_card_schema
          end

          import_table(table('enumeration_values'))
          import_card_defaults(project)
          import_table(table('project_variables'))
          import_variable_bindings
          import_table(table('groups'))
          import_transitions

          if include_content
            import_table(table(old_cards_table))
            import_table(table(old_card_versions_table))
          else
            # in case table exists, just set imported to true
            if table(old_cards_table)
              table(old_cards_table).imported = true
              table(old_card_versions_table).imported = true
            end
            table('tree_belongings').imported = true if table('tree_belongings')
          end

          import_table(table(pages_table))
          import_table(table(page_versions_table))

          import_table(table('card_list_views'))
          import_favorites(table('favorites'), include_content)
          step("Importing history subscriptions") do
            import_history_subscriptions
          end

          step("Importing attachments") do
            import_attachments(table('attachments'), include_content)
          end

          import_attachings(attachable_types)

          import_table(table('tags'))
          import_taggings(include_content)
          import_events(include_content)

          import_member_roles(table('member_roles'))

          dependency_view_map = {}
          import_table(table("dependency_views", DependencyView)) do |record, old_id, new_id|
            key = [record["user_id"], record["project_id"]].join("/")

            # Eliminate duplicates from corrupted export files (15.2 - 16.1 have
            # a bug in project export which will generate duplicate entries for this table)
            # See: "[san_francisco_team_board/#944] Export DependencyViews is broken (creates duplicate entries)"
            has_not_been_inserted = !dependency_view_map.has_key?(key)
            if has_not_been_inserted
              dependency_view_map[key] = 1
            end
            has_not_been_inserted
          end

          tables.each do |table|
            next if team_import.responsible_for_importing?(table)
            import_table(table) # will set modified_by and created_by to User.current if users were not exported
          end

          if include_content
            step("Updating card property relationships") do
              fix_foreign_keys_to_cards_in_values_for(project.relationship_property_definitions + project.card_relationship_property_definitions_with_hidden)
              project.reload
            end
          end

          step("Updating project relationships...") do
            fix_project_variable_user_ids(project)
            fix_project_variable_card_ids(project) if include_content
            fix_transition_action_card_ids(project) if include_content
            fix_history_subscription_filter_and_last_max_id_fields(project)
            fix_aggregate_target_property_ids(project)
            fix_dependent_formula_ids(project)
            fix_all_card_id_association_as_value(project) unless include_content
          end

          step("Updating property definition columns") do
            shorten_property_definition_column_names_in_oracle(project)
          end

          step("Reset card number sequence") do
            project.reset_card_number_sequence
          end

          if reset_timestamps
            step("Reseting timestamps") do
              right_now = {:created_at => Clock.now, :updated_at => Clock.now}
              (ImportExport::TEMPLATE_MODELS() - [Project]).each do |model|
                sql, values, columns = find_table_by_model(model).reset_timestamps_sql(project)
                next if columns.empty?
                update_bind(sql, values, columns)
              end
            end
          end
          if users_table
            step("Importing team users") do
              import_team
            end
          end
          User.release_all_user_locks

          step('Updating team members...') do
            self.project.change_member_to_readonly_for_light_users
          end


          step("Regenerating project history changes. This can take a long time for a large project...") do
            project.generate_changes
          end
          step("Reindexing. This can take a long time for a large project...") do
            project.update_full_text_index
          end
          step("Recompute card aggregate properties. This can take a long time for a large project...") do
            project.compute_aggregates
          end

          step("Rebuild card murmur links") do
            project.rebuild_card_murmur_links
          end

          step("Project import complete") do
            self.project.hidden = false
            self.project.re_initialize_revisions_cache
            self.project.cache_key.touch_feed_key
            self.project.save!
          end

          self.progress.update_attribute(:completed, self.total)
          logger.info("finished importing: #{project.identifier}")
          project.reload
        end
      end
    end

    def with_temporary_card_id_mapping_table
      old_card_id_column = 'id_1'
      new_card_id_column = 'id_2'

      TemporaryIdStorage.with_session do |session_id|
        table(old_cards_table).new_ids_by_old_id.each_slice(1000) do |slice|
          values_to_insert = slice.collect do |old_id, new_id|
            "(SELECT '#{session_id}', #{as_integer(old_id)}, #{as_integer(new_id)} #{connection.from_no_table})"
          end.join(" UNION ALL ")
          connection.execute "INSERT INTO #{TemporaryIdStorage.table_name} (session_id, #{old_card_id_column}, #{new_card_id_column}) #{values_to_insert}"
        end
        yield session_id
      end
    end

    def fix_foreign_keys_to_cards_in_values_for(card_property_definitions)
      t = table(old_cards_table)
      return if t.nil? || t.new_ids_by_old_id.empty?
      with_temporary_card_id_mapping_table do |card_ids_session_id|
        update_statements = card_property_definitions.collect do |property_definition|
          connection.update_statements_for_card_property_definition(property_definition, card_ids_session_id)
        end.flatten
        update_statements.each { |statement| connection.execute(statement) }
      end
    end

    def fix_project_variable_card_ids(project)
      fix_project_variable_ids project, ProjectVariable::CARD_DATA_TYPE, table(old_cards_table)
    end

    def fix_project_variable_user_ids(project)
      fix_project_variable_ids project, ProjectVariable::USER_DATA_TYPE, table('users')
    end

    def fix_project_variable_ids(project, plv_data_type, id_map_table)
      project.project_variables.select { |pv| pv.data_type == plv_data_type }.each do |pv|
        unless pv.value.blank?
          new_id = if id_map_table
                     id_map_table.get_new_id(pv.value)
                   end
          plv_value_update_sql = SqlHelper.sanitize_sql("UPDATE #{ProjectVariable.table_name} SET value = ? WHERE id = ?", new_id, pv.id)
          Project.connection.execute(plv_value_update_sql)
        end
      end
    end

    # we would normally let resolve_associations do this, but aggregate_target_id on property_definitions points to another property definition, and so the
    # importing of prop defs must be completed before we can resolve the associations correctly (otherwise the map from old id to new id won't be complete)
    def fix_aggregate_target_property_ids(project)
      id_map_table = table('property_definitions')
      project.aggregate_property_definitions_with_hidden.each do |aggregate_property_definition|
        unless (old_id = aggregate_property_definition.aggregate_target_id).nil?
          update_sql = SqlHelper.sanitize_sql("UPDATE #{PropertyDefinition.table_name} SET aggregate_target_id = ? WHERE id = ?", id_map_table.get_new_id(old_id), aggregate_property_definition.id)
          Project.connection.execute(update_sql)
        end
      end
      project.reload
    end

    def fix_dependent_formula_ids(project)
      id_map_table = table('property_definitions')
      project.aggregate_property_definitions_with_hidden.each do |aggregate_property_definition|
        next if aggregate_property_definition.dependant_formulas.nil?
        new_dependent_formula_ids = aggregate_property_definition.dependant_formulas.map { |formula_id| id_map_table.get_new_id(formula_id) }.compact
        aggregate_property_definition.dependant_formulas = new_dependent_formula_ids
        aggregate_property_definition.save
      end
    end

    def fix_transition_action_card_ids(project)
      transition_actions = project.card_defaults.collect(&:actions).flatten + project.transitions.collect(&:property_definition_transition_actions).flatten + project.transitions.collect(&:prerequisites).flatten

      transition_actions.reject! { |ta| ta.property_definition.nil?  }

      transition_actions.select { |ta| PropertyType::CardType === ta.property_definition.property_type}.each do |ta|
        unless ta.value.blank?
          ta.value = table(old_cards_table).get_new_id(ta.value)
          ta.save
        end
      end
    end

    def import_events(include_content)
      table = table("events")
      return unless table

      # filter out dependency events until we figure out import/export
      # filtering at the YAML load step happens before trying to resolve associations
      def table.load(file)
        (super).reject do |record|
          record["origin_type"].to_s =~ /^Dependenc/i
        end
      end

      step("Importing #{table.name}...") do
        import_table(table) do |record, old_id, new_id|
          if ["Card::Version", "Page::Version"].include?(record["origin_type"])
            include_content
          else
            true
          end
        end
      end
    end

    def import_history_subscriptions
      history_subscriptions_table = table('history_subscriptions')
      return unless history_subscriptions_table
      if SmtpConfiguration.load
        import_table(history_subscriptions_table)
      else
        history_subscriptions_table.imported = true
      end
    end

    def fix_history_subscription_filter_and_last_max_id_fields(project)
      return unless table('history_subscriptions') && table('users')
      user_property_names = project.user_property_definitions_with_hidden.collect { |pd| pd.name.downcase }
      card_property_names = project.relationship_property_definitions.collect { |pd| pd.name.downcase }
      project.history_subscriptions.each do |hs|
        history_filter_params = hs.to_history_filter_params

        if hs.has_filter_user
          hs.change_filter_user(table('users').get_new_id(hs.filter_user_id))
        end

        if history_filter_params.involved_filter_properties
          history_filter_params.involved_filter_properties.each do |property_name, value|
            next if value.blank?
            if card_property_names.include?(property_name.downcase)
              hs.rename_involved_filter_property_value(property_name, value, table(old_cards_table).get_new_id(value))
            end
            if user_property_names.include?(property_name.downcase)
              hs.rename_involved_filter_property_value(property_name, value, table('users').get_new_id(value))
            end
          end
        end

        if history_filter_params.acquired_filter_properties
          history_filter_params.acquired_filter_properties.each do |property_name, value|
            next if (value.blank? || value == "(any change)")
            if card_property_names.include?(property_name.downcase)
              hs.rename_acquired_filter_property_value(property_name, value, table(old_cards_table).get_new_id(value))
            end
            if user_property_names.include?(property_name.downcase)
              hs.rename_acquired_filter_property_value(property_name, value, table('users').get_new_id(value))
            end
          end
        end

        project.make_history_subscription_current(hs)
        hs.save
      end
    end

    def fix_all_card_id_association_as_value(project)
      project.project_variables.select { |pv| pv.data_type == ProjectVariable::CARD_DATA_TYPE}.each do |pv|
        pv.value = nil
        pv.save
      end

      (project.transitions + project.card_defaults).each(&:clean_card_property_definitions!)

      project.card_list_views.select do |view|
        if view.filters.using_card_as_value?
          view.destroy
        elsif !view.expands.empty?
          view.clear_expands!
        end
      end
    end

    def import_variable_bindings
      import_table(table('variable_bindings'))
    end

    def old_cards_table
      ActiveRecord::Base.table_name_prefix + @old_cards_table if @old_cards_table
    end

    def old_card_versions_table
      ActiveRecord::Base.table_name_prefix + @old_card_versions_table if @old_card_versions_table
    end

    def pages_table
      "pages"
    end

    def page_versions_table
      "page_versions"
    end

    def infer_model_from_table_name(table_name)
      if table_name == old_cards_table
        Card
      elsif table_name == old_card_versions_table
        Card::Version
      else
        ImportExport::ALL_MODELS().find{|m| m.table_name == ActiveRecord::Base.table_name_prefix + table_name}
      end
    end

    def create_project(project_name=nil, project_identifier=nil, pre_defined_template=nil)
      # this may be called before do upgrade, so need to check both projects and deliverables tables
      record = (table('projects') || table('deliverables')).to_a.first

      record['name'] = project_name || record['name']
      record['identifier'] = project_identifier || record['identifier']

      record['name'] = Project.unique(:name, record['name'])
      record['identifier'] = Project.unique(:identifier, record['identifier'])
      record['pre_defined_template'] = pre_defined_template

      attributes = record.merge('hidden' => true, 'icon' => icon_file_from(record, Project, record['id']))
      attributes.delete_if { |name, value| !Project.column_names.include?(name) }
      Project.create(attributes).tap do |project|
        project.card_types.each(&:destroy)
        project.events.each(&:destroy)
      end
    end

    def importing_template?
      value = table(Project.table_name).to_a.first['template']
      return false if ActiveRecord::ConnectionAdapters::Column::FALSE_VALUES.include?(value)
      !value.blank?
    end

    def import_project(project, table)
      table.imported = true

      project_record = table.to_a.first
      old_id = project_record['id']
      @old_project_identifier = project_record['identifier']
      @old_cards_table = project_record['cards_table']
      @old_card_versions_table = project_record['card_versions_table']

      table.map_ids(old_id, project.id)
      project.card_keywords = project_record['card_keywords']
      project.precision = project_record['precision']
      project.ordered_tab_identifiers = project_record['ordered_tab_identifiers']
      project.team.destroy
      MemberRole.delete_all(:deliverable_id => project.id)
      project.save!
    end

    def import_transitions
      import_table(table('transitions'))
      step("Importing transition prerequisites") do
        import_transition_prerequisites
      end
      step("Importing transition actions") do
        import_transition_actions
      end
    end

    def import_transition_prerequisites
      table = table('transition_prerequisites')
      table.imported = true
      table.each do |record|
        old_id = record.delete('id')
        id_column_name = 'property_definition_id'
        new_property_definition_id = table('property_definitions').get_new_id(record[id_column_name]).to_i

        new_user_definitions = project.reload.user_property_definitions_with_hidden.collect(&:id)
        original_project_variable_id = record['project_variable_id']

        unless table('user_memberships')
          pv_record = table('project_variables').find{ |pv| pv['id'] == original_project_variable_id }
          next if(pv_record && pv_record['data_type'] == "UserType")
        end

        new_id = if new_user_definitions.include?(new_property_definition_id) && record['value'] != PropertyType::UserType::CURRENT_USER
           # if no team member imported, we should not set user property to specified team member
          if record['value'].blank? || table('user_memberships')
            user_association = OpenStruct.new(:macro => :belongs_to, :options => {}, :klass => ::User, :primary_key_name => 'value')
            import_record(table, record, [user_association])
          end
        else
          import_record(table, record, [])
        end
        table.map_ids(old_id, new_id) if new_id
      end
    end

    def import_transition_actions
      table = table('transition_actions')
      table.imported = true
      table.each do |record|
        new_record = {}
        new_record['executor_id'] = find_table_by_model(record['executor_type'].constantize).get_new_id(record['executor_id'])
        new_record['executor_type'] = record['executor_type']
        new_record['variable_binding_id'] = table('variable_bindings').get_new_id(record['variable_binding_id'])
        new_record['value'] = record['value'] # card property definition value keeps its orginal id after import
        new_record['type'] = record['type']

        target_id_associated_table = record['type'] == 'RemoveFromTreeTransitionAction' ? 'tree_configurations' : 'property_definitions'
        new_record['target_id'] = table(target_id_associated_table).get_new_id(record['target_id'])

        # the following if block is trying to fix user ids exported with user property definition transition action
        if record['type'] == 'PropertyDefinitionTransitionAction' && table('property_definitions').any? {|pd| pd['id'] == record['target_id'] && pd['type'] == 'UserPropertyDefinition'}
          set_action_value_to_not_set = record['value'].blank? && record['variable_binding_id'].blank?
          special_user_prop_action_values = [PropertyType::UserType::CURRENT_USER].concat(Transition::USER_INPUT_VALUES)
          if !set_action_value_to_not_set && !special_user_prop_action_values.include?(record['value'])
            if table('users') # when we import template, there is no users table
              new_record['value'] = table('users').get_new_id(record['value'])
            else
              new_record['value'] = nil
              new_record['variable_binding_id'] = nil
              new_record['type'] = 'UserInputRequiredTransitionAction' if record['executor_type'] == 'Transition'
            end
          end
        end

        new_id = import_record(table, new_record, [])
        table.map_ids(record['id'], new_id) if new_id
      end
    end

    def import_groups
      import_table(table('groups'))
    end

    def import_team
      team_import.execute
    end

    def team_import
      @team_import ||= DeliverableImportExport::TeamImport.new(self)
    end

    def import_favorites(table, include_content)
      return if table.imported?
      step("Importing #{table.name}...") do
        table.imported = true
        table.each do |record|
          next if (!include_content && record['favorited_type'] == 'Page')
          old_id = record.delete('id')
          record['user_id'] = table('users').get_new_id(record['user_id']) if record['user_id']
          new_id = import_record(table, record)
          table.map_ids(old_id, new_id)
        end

        project.gsub_ordered_tab_identifiers(table.new_ids_by_old_id)
        project.save
      end
    end

    def import_taggings(include_content)
      table = table('taggings')
      return if table.nil? || table.imported?
      step("Importing #{table.name}...") do
        import_table(table) do |record, old_id, new_id|
          import_card_taggings?(include_content, record) || import_page_taggings?(include_content, record)
        end
      end
    end

    def import_member_roles(table)
      return unless table
      return if table.imported?
      step("Importing #{table.name}...") do
        # keys = deliverable_id, member_type, member_id
        index = []
        import_table(table) do |record, old_id, new_id|
          k = [record['deliverable_id'], record['member_type'], record['member_id']]
          if index.include?(k)
            false
          else
            index << k
            true
          end
        end
      end
    end

    def import_card_taggings?(include_content, record)
      include_content && (record['taggable_type'] == 'Card' ||record['taggable_type'] == 'Card::Version' ) && check_taggable_ids_exist?(record)
    end

    def import_page_taggings?(include_content, record)
      include_content && (record['taggable_type'] == 'Page' ||record['taggable_type'] == 'Page::Version' ) && check_taggable_ids_exist?(record)
    end

    def check_taggable_ids_exist?(record)
      # check taggable_id exists; as some old project exports may have this missing and we should not import these records
      record['taggable_id'] && record['tag_id']
    end

    def import_card_defaults(project)
      import_table(table('card_defaults'))
      step("Ensuring all card types have defaults") do
        project.card_types.each { |card_type| card_type.create_card_defaults_if_missing }
      end
    end

    def shorten_property_definition_column_names_in_oracle(project)
      project.all_property_definitions.each do |pd|
        shortened_column_name = Project.connection.column_name(pd.column_name)
        if shortened_column_name != pd.column_name
          pd.column_name = shortened_column_name
          pd.save_without_validation!
        end
      end
    end

    def tables
      table_names_from_file_names.collect{|table_name| table(table_name)}
    end

    def on_fatal_error(e, message)
      add_error(message)
      Kernel.log_error(e, 'Unable to import project', :force_full_trace => true)
      if self.project
        self.project.with_active_project do
          self.project.destroy
        end
      end
      User.each_by(:id, @newly_created_user_ids, &:destroy) if @newly_created_user_ids.any?
    end

    def validate_unique_user_emails(users_table=table("users"))
      return if users_table.nil?
      emails = []
      dupes = users_table.inject([]) do |result, record|
        unless record["email"].blank?
          if emails.include? record["email"].downcase
            result << record["email"].downcase
          else
            emails << record["email"].downcase
          end
        end
        result
      end

      raise "The following emails are shared among multiple users: #{dupes.join(", ")}.\n\nPlease ensure each user has a unique (case-insensitive) email. Contact support if you need assistance (#{THOUGHTWORKS_STUDIOS_SUPPORT_URL})." unless dupes.empty?
    end

    def process!(import_options={})
      with_progress do
        begin
          prepare_for_import
          import(import_options)
        rescue Zipper::InvalidZipFile => e
          on_fatal_error(e, "Invalid export file")
        rescue Exception => e
          on_fatal_error(e, e.message)
        end
      end

      ProjectCacheFacade.instance.clear_cache(project.identifier) unless project.nil?
      project
    ensure
      clear_tmp_files
    end

    def step(description = nil, &block)
      progress.step(description, &block)
      update_attribute :completed, [self.total, @tables.values.select(&:imported?).size].min
    end

    def clear_tmp_files
      return if MingleConfiguration.no_cleanup?
      if @export_file && File.exists?(@export_file)
        FileUtils.rm_rf(@export_file)
      end
      delete_directory
    rescue => e
      Kernel.log_error(e, 'clear project import tmp files failed', :force_full_trace => true)
    end

    def delete_directory
      FileUtils.rm_rf(directory) if directory
    end

    def clean_name_and_identifer
      self.project_name = clean_str(self.project_name)
      self.project_identifier = clean_str(self.project_identifier)
    end

    def clean_str(str)
      str.blank? ? nil : str.strip
    end

    def plugins_valid?
       return true if importing_template?
       plugins = table("#{ActiveRecord::Base.table_name_prefix}schema_migrations").to_a.map do |migration|

        if migration['version'] =~ /(\d+)-(\w+)/
          { 'plugin_name' => $2, 'version' => $1 }
        end
      end.compact

      any_plugin_needs_migration?(plugins)
    end

    def any_plugin_needs_migration?(plugins)
      plugins = plugins_with_max_version(plugins)

      plugins.all? do |import_plugin|
        plugin = Engines.plugins[import_plugin['plugin_name']]

        if plugin.blank?
          raise PluginNotExistError.new("Couldn't find plugin #{import_plugin['plugin_name'].bold} in this Mingle instance.")
        end

        if plugin.current_migration < import_plugin['version'].to_i
          raise PluginNeedUpgradeError.new("This upgrade includes a later version of Mingle plugin #{plugin.name.bold}. Downgrades of an export of plugin is not yet supported. ")
        end

        import_plugin['version'].to_i == plugin.current_migration
      end
    end

    def plugins_with_max_version(plugins)
      plugins.inject({}) do |unique_versions, import_plugin|
        migration_plugin = import_plugin['plugin_name']

        if unique_versions.keys.include?(migration_plugin)
          if import_plugin['version'] > unique_versions[migration_plugin]['version']
            unique_versions[migration_plugin] = import_plugin
          end
        else
          unique_versions[migration_plugin] = import_plugin
        end

        unique_versions
      end.values
    end

    def default_identifier(unzipped_import_directory, identifier)
      Project.unique(:identifier, identifier.blank? ? project_table_attribute(unzipped_import_directory, 'identifier') : identifier)
    end

    def default_name(unzipped_import_directory, name)
      Project.unique(:name, name.blank? ? project_table_attribute(unzipped_import_directory, 'name') : name)
    end

    protected

    def prepare_for_import
      message = progress.message
      localized_tmp_file = nil
      @tables ||= {}
      step("Moving export file to local temporary directory") do
        localized_tmp_file = if message[:s3_object_name]
          download_from_s3(message)
        else
          progress.localize_tmp_file
        end
      end

      step("Extracting export file") do
        set_directory(localized_tmp_file)
      end

      validate_unique_user_emails

      project_identifier = default_identifier(directory, message[:project_identifier])
      project_name = default_name(directory, message[:project_name])
      progress.update_attributes(:deliverable_identifier => project_identifier)
      create_project_if_needed(project_name, project_identifier, message[:pre_defined_template])
    end

    def download_from_s3(message)
      import_files_bucket = AWS::S3.new.buckets[MingleConfiguration.import_files_bucket_name]
      s3_object = import_files_bucket.objects[message[:s3_object_name]]
      Rails.logger.info("Downloading file #{message[:s3_object_name]} from s3")
      local_file = localize(s3_object)
      Rails.logger.info("Completed downloading file #{message[:s3_object_name]} from s3")
      local_file
    end

    private

    def table_name_for_deliverables_in_project_file(unzipped_import_directory)
      schema_table = ImportExport::Table.new(unzipped_import_directory, "schema_migrations")
      versions = schema_table.collect { |migration| migration['version']}
      versions.collect(&:to_i).include?(20110620181447) ? 'deliverables' : 'projects'
    end

    def project_table_attribute(unzipped_import_directory, attribute_name)
      table = ImportExport::Table.new(unzipped_import_directory, table_name_for_deliverables_in_project_file(unzipped_import_directory))
      attribute_values = table.collect { |p| p[attribute_name] }
      raise 'Export contains information for more than one project' if attribute_values.size > 1
      raise 'Export contains no information for more any project' if attribute_values.empty?
      attribute_values.first
    end

    def localize(s3_object)
      tmp_file = [SecureRandomHelper.random_32_char_hex, 'tmp'].join('.')

      File.join(RAILS_TMP_DIR, 'asynch_request', tmp_file).tap do |local_tmp_file|
        FileUtils.mkdir_p(File.dirname(local_tmp_file))
        File.open(local_tmp_file, 'wb') do |file|
          s3_object.read do |chunk|
            file.write(chunk)
          end
        end
        local_tmp_file
      end

    end

    def resolve_your_own_associations(real_model, table, record)
      resolve_user_property_definition_associations_on_cards_and_card_versions(real_model, table, record)
    end

    def resolve_user_property_definition_associations_on_cards_and_card_versions(real_model, table, record)
      return unless (real_model == Card || real_model == Card::Version) && table('users')
      project.user_property_definitions_with_hidden.each do |updf|
        foreign_key = if record.has_key?(updf.column_name)
                        updf.column_name
                      else
                        Project.connection.column_name(updf.column_name)
                      end
        if old_user_id = record[foreign_key]
          association_table = find_table_by_model(::User)
          import_table(association_table)
          record[foreign_key] = association_table.get_new_id(old_user_id)
        end
      end
    end

    def schema_incompatible
      DeliverableImportExport::ExportFileUpgrade::SchemaIncompatible.new('The project you tried to import is from a newer version of Mingle than this version. Downgrades are not supported. Please select a different project and try importing again.')
    end
  end
end
