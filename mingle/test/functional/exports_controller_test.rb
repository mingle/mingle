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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class ExportsControllerTest < ActionController::TestCase
  include MetricsHelper
  def setup
    @controller = create_controller(ExportsController)
    @admin = login_as_admin
    Export.destroy_all
  end

  def test_should_render_empty_export_meta_data
    MingleConfiguration.overridden_to(export_data: true) do
      get :index
      element = Nokogiri.parse(@response.body).xpath("//div[@id='export-container']")
      assert_equal "null", element.attr('data-export').value
    end
  end

  def test_should_render_last_export_meta_data
    MingleConfiguration.overridden_to(export_data: true) do
      Export.create
      export_2 = Export.create
      get :index
      element = Nokogiri.parse(@response.body).xpath("//div[@id='export-container']")
      assert_equal export_2.to_json, element.attr('data-export').value
    end
  end

  def test_should_return_export_meta_data_as_json
    MingleConfiguration.overridden_to(export_data: true) do
      export = Export.create
      get :index, format: 'json', id: export.id
      assert_equal export.to_json, @response.body
    end
  end

  def test_should_create_new_export
    MingleConfiguration.overridden_to(export_data: true) do
      Export.any_instance.expects(:start).once
      post :create
      assert_equal 1, Export.count
    end
  end

  def test_should_not_create_new_export_when_one_export_is_in_progress
    MingleConfiguration.overridden_to(export_data: true) do
      Export.any_instance.expects(:start).never
      export = Export.create(status: Export::IN_PROGRESS)
      post :create
      assert_equal 1, Export.count
      assert_equal export.to_json, @response.body
    end
  end

  def test_should_create_new_export_when_last_progress_errored
    MingleConfiguration.overridden_to(export_data: true) do
      Export.any_instance.expects(:start).once
      export = Export.create(status: 'error')

      post :create

      assert_equal 2, Export.count
      assert_equal Export.find(export.id.next).to_json, @response.body
    end
  end

  def test_should_create_new_export_when_last_export_is_completed
    MingleConfiguration.overridden_to(export_data: true) do
      Export.any_instance.expects(:start).once
      export = Export.create(status: 'completed')
      post :create
      assert_equal 2, Export.count
      assert_equal Export.find(export.id.next).to_json, @response.body
    end
  end

  def test_index_endpoint_should_raise_invalid_resource_error_when_export_is_toggled_off_for_saas
    MingleConfiguration.overridden_to(:multitenancy_mode => true, :saas_env => 'test') do
      assert_raises ErrorHandler::InvalidResourceError, ErrorHandler::FORBIDDEN_MESSAGE do
        get :index
      end
    end
  end

  def test_create_endpoint_should_raise_invalid_resource_error_when_export_is_toggled_off_for_saas
    MingleConfiguration.overridden_to(:multitenancy_mode => true, :saas_env => 'test') do
      assert_raises ErrorHandler::InvalidResourceError, ErrorHandler::FORBIDDEN_MESSAGE do
        post :create
      end
    end
  end

  def test_download_endpoint_should_raise_invalid_resource_error_when_export_is_toggled_off_for_saas
    MingleConfiguration.overridden_to(:multitenancy_mode => true, :saas_env => 'test') do
      assert_raises ErrorHandler::InvalidResourceError, ErrorHandler::FORBIDDEN_MESSAGE do
        get :download
      end
    end
  end

  def test_mix_panel_event_is_created_on_initiating_an_export
    MingleConfiguration.overridden_to( saas_env: 'test', export_data: true, metrics_api_key: 'key') do
      Multitenancy.add_tenant('hello', "database_username" => current_schema)
      Multitenancy.activate_tenant('hello') do
        SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'NOT_INTEGRATED', team: {name: 'A Team', url: 'http://slack.team.url'}})
        post :create
        assert @controller.events_tracker.sent_event?('export_started', {:site_name=>"hello"})
      end
    end
  end

  def test_mix_panel_event_is__not_created_on_initiating_an_export_for_non_saas_customers
    MingleConfiguration.overridden_to( export_data: true, metrics_api_key: 'key') do
      Multitenancy.add_tenant('hello', "database_username" => current_schema)
      Multitenancy.activate_tenant('hello') do
        post :create
        assert_nil @controller.events_tracker.sent_event?('export_started', {:site_name=>"hello"})
      end
    end
  end

  def test_should_delete_the_running_export_and_return_the_last_export_as_json
    MingleConfiguration.overridden_to(export_data: true) do
      Export.any_instance.expects(:start).once
      export = Export.create(status: 'completed')
      post :create
      assert_equal 2, Export.count
      post :delete
      assert_equal 1, Export.count
      assert_equal Export.find(export.id).to_json, @response.body
    end
  end

  def test_should_not_delete_a_completed_export
    MingleConfiguration.overridden_to(export_data: true) do
      export = Export.create(status: 'completed')
      assert_equal 1, Export.count
      post :delete
      assert_equal 1, Export.count
      assert_equal Export.find(export.id).to_json, @response.body
    end
  end


  def test_should_render_users_and_all_projects_admins_count
    MingleConfiguration.overridden_to(export_data: true) do
      get :index
      assert_select '#users-and-project-admins .data-type-info' , text: "#{User.count} users, #{MemberRole.all_project_admins.count} project administrators"
    end
  end


  def test_should_render_projects_in_descending_order_of_their_last_activity
    MingleConfiguration.overridden_to(export_data: true) do
      time = DateTime.now.yesterday
      project_1 = project_2 = project_3 = nil
      with_new_project do |project|
        story_type = project.card_types.create(name: 'Story')
        status_prop_def = project.create_text_list_definition!(name: 'Status')
        status_prop_def.card_types = [story_type]
        status_prop_def.save!
        project.reload
        Timecop.travel(time + 4.days) do
          project.cards.create!(name: "Story 1", card_type: story_type, cp_status: 'new')
        end
        project_1 = project
      end

      with_new_project do |project|
        story_type = project.card_types.create(name: 'Story')
        status_prop_def = project.create_text_list_definition!(name: 'Status')
        status_prop_def.card_types = [story_type]
        status_prop_def.save!
        project.reload
        Timecop.travel(time + 2.days) do
          project.cards.create!(name: "Story 1", card_type: story_type, cp_status: 'new')
        end
        project_2 = project
      end

      with_new_project do |project|
        story_type = project.card_types.create(name: 'Story')
        status_prop_def = project.create_text_list_definition!(name: 'Status')
        status_prop_def.card_types = [story_type]
        status_prop_def.save!
        project.reload
        Timecop.travel(time + 3.days) do
          project.cards.create!(name: "Story 1", card_type: story_type, cp_status: 'new')
        end
        project_3 = project
      end

      get :index
      assert_select '.project-data', count: Project.count
      assert_select '.project-data-1 .data-type-name', text: project_1.name
      assert_select '.project-data-2 .data-type-name', text: project_3.name
      assert_select '.project-data-3 .data-type-name', text: project_2.name
    end
  end

  def test_should_render_the_programs_with_the_no_of_projects_associated
    MingleConfiguration.overridden_to(export_data: true) do
      program = Program.create!(:name => " new program ", :identifier => "newprogram")
      with_first_project do |project|
        program.projects << project
        property_to_map = project.find_property_definition("status")
        enumeration_value_to_map = property_to_map.enumeration_values.detect{|ev| ev.value == 'closed'}
        program_project = program.program_projects.first
        program_project.update_attributes(:status_property => property_to_map, :done_status => enumeration_value_to_map)
        program_project.reload
      end
      get :index
      assert_select '#programs-data .data-type-name' , text: program.name
      assert_select '#programs-data .data-type-info' , text: /1 projects/
    end
  end

  def test_should_not_render_the_mingle_admins_list_for_admins
    MingleConfiguration.overridden_to(export_data: true) do
      get :index
      assert_select '#mingle-admins-list' , :count => 0
    end
  end

  def test_should_not_render_the_export_checklist_form_for_non_mingle_administrators
    MingleConfiguration.overridden_to(export_data: true) do
      login_as_member
      get :index
      assert_select '#export-checklist-form' , :count => 0
    end
  end

  def test_should_render_the_mingle_admins_list_for_non_admins
    MingleConfiguration.overridden_to(export_data: true) do
      login_as_member
      get :index
      assert_select '#mingle-admins-list' , text: @admin.name
    end
  end

  private

  def current_schema
    ActiveRecord::Base.configurations['test']['username']
  end
end
