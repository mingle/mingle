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

require File.expand_path(File.dirname(__FILE__) + "/tree_fixtures")
require File.expand_path(File.dirname(__FILE__) + "/../test_helpers/setup_helper")
require File.expand_path(File.dirname(__FILE__) + "/../test_helpers/test_constants")

class UnitTestDataLoader
  USER_LOGINS = %w{ admin first member bob longbob proj_admin read_only_user } # load_users needs admin to be the first user.
  include TreeFixtures::PlanningTree

  def run(load_project=nil)
    Messaging.disable
    License.eula_accepted

    load_users
    UnitTestDataLoader.login('member@email.com')

    load_project ||= ENV['LP']
    if load_project
      paths = load_project.split(",").map do |lp|
        "#{File.join(File.dirname(__FILE__), 'loaders')}/#{lp.strip.underscore}.rb"
      end
      loaders = Dir[*paths]
    else
      loaders = Dir["#{File.join(File.dirname(__FILE__), 'loaders')}/*.rb"]
    end
    start_at = Time.now
    loaders.each do |loader|
      begin
        UnitTestDataLoader.login('member@email.com')
        loader_name = File.basename(loader, '.rb').camelize
        ActiveRecord::Base.logger.debug "#{Time.now} - Loading project: #{loader_name}"
        t = Time.now
        puts "Loader #{loader_name}: EXECUTING"
        require loader
        "Loaders::#{loader_name}".constantize.new.execute
        puts "Loader #{loader_name} DONE: #{Time.now - t}"
        ActiveRecord::Base.logger.debug "#{Time.now} - Loading project: #{loader_name} - Done. (#{Time.now - t})."
      rescue Exception => e
        puts "Error executing loader #{loader_name}: #{e.message}"
        puts e.backtrace.join("\n")
        raise e
      end
    end
    puts "Finished in #{Time.now - start_at} seconds."
    SetupHelper.register_license
  ensure
    Messaging.enable
  end

  def load_users
    custom_attributes = {'admin' => {:admin => true}}

    USER_LOGINS.each do |login|
      unless User.find_by_login(login)
        name = email = "#{login}@email.com"
        user = User.new({:login => login, :email => email, :name => name, :password => MINGLE_TEST_DEFAULT_PASSWORD}.merge(custom_attributes[login] || {}))
        user.save_with_validation(false)
      end
    end
  end

  class << self

    def preloaded_project?(project)
      @__names ||= Dir["#{File.join(File.dirname(__FILE__), 'loaders')}/*.rb"].collect do |loader|
        File.basename(loader, '.rb').downcase
      end
      @__names.include?(project.identifier) || project.identifier =~ /^sp_/
    end

    def preloaded_user_logins
      USER_LOGINS
    end

    def login(email)
      user = User.find_by_email(email)
      User.current = user
    end

    def setup_property_definitions(properties_with_values = {}, options={})
      project = Project.current.reload
      created_properties = []
      properties_with_values.keys.each do |property_name|

        project = Project.current.reload
        property_definition = create_enumerated_property_definition(project, property_name.to_s, properties_with_values[property_name], options)
        created_properties << property_definition
        project = Project.current.reload
        properties_with_values[property_name].collect{|v| v.to_s}.each_with_index do |value, index|
          enumeration_value = project.find_enumeration_value(property_definition.name, value, {:with_hidden => options[:hidden]||= false})
          enumeration_value.update_attributes(:position => index + 1, :nature_reorder_disabled => true)
        end
      end

      project.reload.update_card_schema
      project.activate
      created_properties
    end

    def setup_numeric_property_definition(name, values=[], options = {})
      project = Project.current.reload
      create_enumerated_property_definition(project, name, values, options.merge(:is_numeric => true)).tap do |prop_def|
        project.reload.update_card_schema
      end
    end

    def setup_managed_text_definition(name, values=[], options={})
      project = Project.current.reload
      create_enumerated_property_definition(project, name, values, options.merge(:is_numeric => false)).tap do |prop_def|
       project.reload.update_card_schema
      end
    end

    def setup_user_definition(name)
      name = name.to_s
      project = Project.current.reload
      property_definition = project.create_user_definition!(:name => name)
      project.card_types.first.add_property_definition property_definition
      property_definition.save!
      project.reload.update_card_schema
      property_definition
    end

    def setup_card_property_definition(name, valid_card_type)
      project = Project.current.reload
      property_definition = project.create_card_property_definition!(:name => name, :valid_card_type => valid_card_type)
      project.card_types.each do |type|
        type.add_property_definition property_definition
      end
      property_definition.save!
      project.reload.update_card_schema
      property_definition
    end

    def setup_text_property_definition(name, options={})
      create_text_property_definition(name, options.merge(:is_numeric => false))
    end

    def setup_formula_property_definition(name, formula)
      create_formula_property_definition(name, formula)
    end

    def setup_card_relationship_property_definition(name)
      create_card_relationship_property_definition(name)
    end

    def setup_aggregate_property_definition(name, aggregate_type, target_property_definition, tree_id, aggregate_card_type_id, aggregate_scope)
      project = Project.current.reload
      options = {:name => name, :aggregate_scope => aggregate_scope, :aggregate_type => aggregate_type, :aggregate_card_type_id => aggregate_card_type_id, :tree_configuration_id => tree_id}
      options.merge!(:aggregate_target_id => target_property_definition.id) if target_property_definition
      aggregate_def = project.create_aggregate_property_definition!(options)
      project.reload.update_card_schema
      aggregate_def.reload
      aggregate_def
    end

    def setup_numeric_text_property_definition(name)
      create_text_property_definition(name, :is_numeric => true)
    end

    def setup_date_property_definition(name)
      project = Project.current.reload
      result = project.create_date_property_definition!(:name => name)
      project.card_types.first.add_property_definition result
      project.reload.update_card_schema
      result
    end


    def delete_project(identifier)
      project = Project.find_by_identifier(identifier)
      if project
        project.with_active_project do |active_project|
          ProjectDelete.new(active_project).execute
        end
      end
    end

    def create_enumerated_property_definition(project, property_name, values=[], options={})
      property_name = property_name.to_s if property_name.kind_of?(Symbol)
      property_definition = project.find_property_definition_or_nil(property_name) ||
      project.create_text_list_definition!(:name => property_name, :is_numeric => options[:is_numeric], :hidden => options[:hidden]||= false)

      card_types = (options[:card_types] || [options[:card_type]]).compact
      card_types << project.card_types.first if card_types.empty?
      card_types.each do |card_type|
        card_type.add_property_definition property_definition
      end

      property_definition.save!

      project = Project.current.reload
      values.collect{|v| v.to_s}.each_with_index do |value, index|
        unless project.find_enumeration_value(property_definition.name, value, {:with_hidden => options[:hidden]})
          new_value = EnumerationValue.new(:nature_reorder_disabled => true, :value => value, :property_definition_id => property_definition.id)
          new_value.save!
        end
      end
      property_definition
    end

    def create_text_property_definition(name, options = {})
      project = Project.current.reload
      property_definition = project.create_any_text_definition!(options.merge(:name => name))
      project.card_types.first.add_property_definition property_definition
      project.reload.update_card_schema
      property_definition
    end

    def create_card_relationship_property_definition(name)
      project = Project.current.reload
      result = project.create_card_relationship_property_definition!(:name => name)
      project.card_types.first.add_property_definition result
      project.reload.update_card_schema
      result
    end

    def create_formula_property_definition(name, formula)
      (User.current.id ? User.current : User.first_admin).with_current do
        project = Project.current.reload
        result = project.create_formula_property_definition!(:name => name, :formula => formula)
        project.card_types.first.add_property_definition result
        project.reload.update_card_schema
        result
      end
    end

    def create_card_query_project(name, create_initial_card = true)
      Project.create!(:name => name, :identifier => name, :secret_key => 'this is secret',
                      :time_zone => ActiveSupport::TimeZone['Brisbane'].name, :corruption_checked => true).with_active_project do |project|
        project.add_member(User.find_by_login('member'))
        project.add_member(User.find_by_login('proj_admin'), :project_admin)

        UnitTestDataLoader.setup_property_definitions(
          :old_type => ['story'],
          :Priority => ['low', 'medium', 'high'],
          :Status => ['New', 'In Progress', 'Done', 'Closed'],
          "Status's" => [],
          :Release  => [1, 2],
          :Iteration => (1..5).to_a,
          :Estimate => (1..5).to_a,
          "Feature Thing" => ['Dashboard', 'Applications', 'Rate calculator', 'Profile builder', 'User administration'],
          :Feature => ['Dashboard', 'Applications', 'Rate calculator', 'Profile builder', 'User administration'],
          'In Scope'.humanize => ['Yes', 'No'],
          'Completed On Iteration'.humanize => [],
          'Came Into Scope on Iteration'.humanize => [1,2],
          'Planned for Iteration'.humanize => [1,2],
          'Development Done in Iteration'.humanize => [],
          'Analysis Done in Iteration'.humanize => [],
          'Flagged for release'.humanize => [1, 2]
        )

        UnitTestDataLoader.setup_card_relationship_property_definition('related card')

        UnitTestDataLoader.setup_user_definition('Assigned To')
        UnitTestDataLoader.setup_user_definition('owner')
        UnitTestDataLoader.setup_user_definition('tester')

        UnitTestDataLoader.setup_text_property_definition('freetext1')
        UnitTestDataLoader.setup_text_property_definition('freetext2')
        UnitTestDataLoader.setup_numeric_text_property_definition('numeric_free_text')

        UnitTestDataLoader.setup_date_property_definition('date_created')
        UnitTestDataLoader.setup_date_property_definition('date_deleted')

        UnitTestDataLoader.setup_numeric_property_definition('Size', (1..5).to_a)
        UnitTestDataLoader.setup_numeric_property_definition('accurate_estimate', ['1.00', '1.1234', '2.2345', '3.6666', '4.6779'])
        UnitTestDataLoader.setup_formula_property_definition('half', 'size/2')

        if create_initial_card
          card = UnitTestDataLoader.create_card_with_property_name(project, {:number => 1, :name => 'for card query test'},
              :old_type => 'story', :release => '1', :'assigned to' => User.find_by_login('member').id)
          card.reload.tag_with('tag1, tag2')
          card.save!
        end

        project.reset_card_number_sequence
        project
      end
    end

    def create_card_with_property_name(project,card_attributes={},properties={})
      card_attributes.symbolize_keys!
      properties.symbolize_keys!

      tags = card_attributes.delete(:tags)
      attachments = card_attributes.delete(:attachments)
      completed_checklist_items = card_attributes.delete(:completed_checklist_items)
      incomplete_checklist_items = card_attributes.delete(:incomplete_checklist_items)

      card_attributes[:card_type_name] = if properties.has_key?(:card_type)
        card_type = properties.delete(:card_type)
        card_type.respond_to?(:name) ? card_type.name : card_type
      elsif properties.has_key?(:card_type_name)
        properties.delete(:card_type_name)
      else
        project.card_types.first.name
      end
      card = Card.new(card_attributes.merge(:project_id => project.id))
      card.update_properties(properties, :include_hidden => true)
      card.tag_with(tags) if tags
      (attachments || []).each do |file|
        card.attach_files(sample_attachment(file))
      end
      card.add_checklist_items({CardImport::Mappings::INCOMPLETE_CHECKLIST_ITEMS => incomplete_checklist_items}) if incomplete_checklist_items
      card.add_checklist_items({CardImport::Mappings::COMPLETED_CHECKLIST_ITEMS => completed_checklist_items}) if completed_checklist_items
      card.save!
      card
    end

    def uploaded_file(path, filename=nil, content_type="application/octet-stream")
      filename ||= File.basename(path)
      t = Tempfile.new(filename)
      FileUtils.copy_file(path, t.path)
      (class << t; self; end;).class_eval do
        alias local_path path
        define_method(:original_filename) { filename }
        define_method(:content_type) { content_type }
      end
      t
    end

    def sample_attachment(filename=nil)
      uploaded_file("#{File.expand_path(Rails.root)}/test/data/sample_attachment.txt", filename)
    end

    def another_sample_attachment(filename=nil)
      uploaded_file("#{File.expand_path(Rails.root)}/test/data/another_sample_attachment.txt", filename)
    end

    def create_project_importer!(user, export_file, project_name="", project_identifier="")
      asynch_request = ProjectImportPublisher.new(user, project_name, project_identifier).publish_message(uploaded_file(export_file))
      DeliverableImportExport::ProjectImporter.fromActiveMQMessage(asynch_request.message)
    end

    def unique_project_name(prefix = nil)
      prefix = 'project' if prefix.blank?
      unique_name(prefix)
    end

    def unique_name(prefix = '')
      "#{prefix}#{''.uniquify[0..8]}"
    end
  end
end

if $0 == __FILE__
  require File.expand_path(File.dirname(__FILE__) + '/../../config/environment')
  UnitTestDataLoader.new.run
end
