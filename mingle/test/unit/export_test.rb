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

class ExportTest < ActiveSupport::TestCase


  def setup
    CurrentLicense.register!(license_key, licensed_to)
  end

  def teardown
    Multitenancy.clear_tenants
  end

  def test_export_filename_should_use_current_time_and_tenant_name
    MingleConfiguration.with_app_namespace_overridden_to('tenant') do
      export = Export.create
      assert_equal "MingleExport_tenant_#{Clock.now.strftime("%d%b%Y_%H%M%Z")}.zip", export.filename
    end
  end

  def test_export_dirname_should_use_current_time_and_tenant_name
    MingleConfiguration.with_app_namespace_overridden_to('foooo') do
      export = Export.create
      assert_equal "MingleExport_foooo_#{Clock.now.strftime("%d%b%Y_%H%M%Z")}", export.dirname
    end
  end

  def test_dependency_and_program_exports_should_not_be_triggered_for_non_mingle_plus_customers
    MingleConfiguration.with_app_namespace_overridden_to('foooo') do
      Program.create(name: 'Test Program')
      CurrentLicense.register!(license_key, licensed_to)
      DependencyDataExportPublisher.any_instance.stubs(:publish_message).never
      ProgramDataExportPublisher.any_instance.stubs(:publish_message).never
      Export.create.start
    end
  end

  def test_should_export_slack_integrations_data_only_for_saas_env
      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: 'A Team', url: 'http://slack.team.url'}})

      IntegrationsExportPublisher.any_instance.stubs(:publish_message).never
      Export.create.start
  end

  def test_should_export_slack_integrations_data_for_integrated_tenant
    MingleConfiguration.overridden_to(saas_env: 'test') do
      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'INTEGRATED', team: {name: 'A Team', url: 'http://slack.team.url'}})

      IntegrationsExportPublisher.any_instance.stubs(:publish_message).once
      Export.create.start
    end
  end

  def test_should_not_export_slack_integrations_data_for_not_integrated_tenant
    MingleConfiguration.overridden_to( :saas_env => 'test') do
      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'NOT_INTEGRATED', team: {name: 'A Team', url: 'http://slack.team.url'}})

      IntegrationsExportPublisher.any_instance.stubs(:publish_message).never
      Export.create.start
    end
  end

  def test_should_update_running_exports_for_activated_tenant_in_multitenancy_mode
    MingleConfiguration.overridden_to(:saas_env => 'test') do
      Multitenancy.add_tenant('hello', "database_username" => current_schema)
      Multitenancy.activate_tenant('hello') do
        SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'NOT_INTEGRATED', team: {name: 'A Team', url: 'http://slack.team.url'}})

        Export.any_instance.stubs(:update_running_exports).once
        Export.create.start
      end
    end
  end

  def test_should_not_update_running_exports_in_multitenancy_mode_with_no_activated_tenants
    MingleConfiguration.overridden_to(:saas_env => 'test') do
      SlackApplicationClient.any_instance.stubs(:integration_status => {status: 'NOT_INTEGRATED', team: {name: 'A Team', url: 'http://slack.team.url'}})

      Export.any_instance.stubs(:update_running_exports).never
      Export.create.start
    end
  end

  def test_should_invoke_last_data_exported_on_endpoint_on_profile_server
    ProfileServer.stubs(:configured?).returns(true)
    ProfileServer.stubs(:update_last_data_exported_on).once
    Export.create
  end

  def test_should_not_publish_project_data_export_message_when_not_given
    export = Export.create
    create_project
    ProjectDataExportPublisher.any_instance.stubs(:publish_message).never
    export.start
  end

  def test_should_not_publish_project_data_export_message_when_given_but_excluded
      project_1 = create_project

      export = Export.create(config: {projects: {
            project_1.identifier => {data: false},
        }})

      ProjectDataExportPublisher.any_instance.stubs(:publish_message).never

      export.start
  end

  def test_should_publish_project_data_export_message_when_given
    project_1 = create_project
    project_2 = create_project
    export = Export.create(config: {projects: {
        project_1.identifier => {data: true},
        project_2.identifier => {data: true},
    }})
    create_project
    create_project

    Project.stubs(:all_selected).with([project_1.identifier, project_2.identifier]).returns([project_1, project_2])
    ProjectDataExportPublisher.any_instance.stubs(:publish_message).with(anything, project_1)
    ProjectDataExportPublisher.any_instance.stubs(:publish_message).with(anything, project_2)
    export.start
  end

  def test_should_not_publish_project_history_export_message_when_not_given
    export = Export.create
    create_project

    ProjectHistoryDataExportPublisher.any_instance.stubs(:publish_message).never
    export.start
  end

  def test_should_not_publish_project_history_export_message_when_given_but_excluded
    project_1 = create_project
    export = Export.create(config: {projects: {
        project_1.identifier => {data: true, history:false},
    }})
    create_project

    ProjectHistoryDataExportPublisher.any_instance.stubs(:publish_message).never

    export.start
  end

  def test_should_not_publish_project_history_export_message_when_data_export_is_excluded
    project_1 = create_project
    export = Export.create(config: {projects: {
        project_1.identifier => {data: false, history:true},
    }})
    create_project

    ProjectHistoryDataExportPublisher.any_instance.stubs(:publish_message).never

    export.start
  end

  def test_should_publishing_project_history_export_message_when_given
    project_1 = create_project
    project_2 = create_project
    export = Export.create(config: {projects: {
        project_1.identifier => {data: true, history:true},
        project_2.identifier => {data: true, history:true},
    }})
    create_project
    create_project

    Project.stubs(:all_selected).with([project_1.identifier, project_2.identifier]).returns([project_1, project_2])
    ProjectHistoryDataExportPublisher.any_instance.stubs(:publish_message).with(anything, project_1)
    ProjectHistoryDataExportPublisher.any_instance.stubs(:publish_message).with(anything, project_2)
    export.start
  end

  def test_should_publish_instance_data_export_message
    export1 = Export.create(config: {all_users_and_projects_admins: true, user_icons: true})
    export2 = Export.create(config: {all_users_and_projects_admins: true, user_icons: false})
    InstanceDataExportPublisher.any_instance.stubs(:publish_message).with(anything, {include_users_and_projects_admin:true, include_user_icons: true})
    InstanceDataExportPublisher.any_instance.stubs(:publish_message).with(anything, {include_users_and_projects_admin:true, include_user_icons: false})

    export1.start
    export2.start
  end

  def test_should_publish_dependency_export_message_when_included_and_dependencies_exists
    CurrentLicense.register!(license_key_hash.merge(:product_edition => Registration::ENTERPRISE).to_query, licensed_to)
    Dependency.stubs(:count).returns(1)
    DependencyDataExportPublisher.any_instance.stubs(:publish_message).once
    Export.create(config: {dependencies: true}).start
  end

  def test_should_publish_dependency_export_message_for_non_enterprise_edition_when_included_and_dependencies_exists
    CurrentLicense.register!(license_key_hash.merge(:product_edition => Registration::NON_ENTERPRISE).to_query, licensed_to)
    Dependency.stubs(:count).returns(1)
    DependencyDataExportPublisher.any_instance.stubs(:publish_message).never
    Export.create(config: {dependencies: true}).start
  end

  def test_should_not_publish_dependency_export_message_when_included_and_dependencies_does_not_exists
    CurrentLicense.register!(license_key_hash.merge(:product_edition => Registration::ENTERPRISE).to_query, licensed_to)
    Dependency.stubs(:count).returns(0)
    DependencyDataExportPublisher.any_instance.stubs(:publish_message).never
    Export.create(config: {dependencies: true}).start
  end

  def test_should_not_publish_dependency_export_message_when_dependencies_exists_but_excluded
    CurrentLicense.register!(license_key_hash.merge(:product_edition => Registration::ENTERPRISE).to_query, licensed_to)
    Dependency.stubs(:count).returns(1)
    DependencyDataExportPublisher.any_instance.stubs(:publish_message).never
    Export.create(config: {dependencies: false}).start
  end

  def test_should_not_publish_programs_data_export_message_for_non_enterprise_edition
    with_first_admin do
      program_1 = create_program
      export = Export.create(config: {programs: {program_1.identifier => true}})
      ProgramDataExportPublisher.any_instance.stubs(:publish_message).never
      export.start
    end
  end

  def test_should_publish_programs_data_export_message_when_given_for_enterprise_edition
    with_first_admin do
      CurrentLicense.register!(license_key_hash.merge(:product_edition => Registration::ENTERPRISE).to_query, licensed_to)
      program_1 = create_program
      program_2 = create_program
      export = Export.create(config: {programs: {
          program_1.identifier => true,
          program_2.identifier => true
      }})

      Program.stubs(:all_selected).with([program_1.identifier, program_2.identifier]).returns([program_1, program_2])
      ProgramDataExportPublisher.any_instance.stubs(:publish_message).with(anything, program_1)
      ProgramDataExportPublisher.any_instance.stubs(:publish_message).with(anything, program_2)
      export.start
    end
  end

  def test_should_not_publish_programs_data_export_message_when_not_given_for_enterprise_edition
    with_first_admin do
      CurrentLicense.register!(license_key_hash.merge(:product_edition => Registration::ENTERPRISE).to_query, licensed_to)
      export = Export.create
      create_program

      ProgramDataExportPublisher.any_instance.stubs(:publish_message).never
      export.start
    end
  end

  def test_should_not_publish_programs_data_export_message_for_exclude_program
    with_first_admin do
      CurrentLicense.register!(license_key_hash.merge(:product_edition => Registration::ENTERPRISE).to_query, licensed_to)
      program_1 = create_program
      program_2 = create_program
      export = Export.create(config: {programs: {
      program_1.identifier => false,
      program_2.identifier => true
      }})

      Program.stubs(:all_selected).with([program_2.identifier]).returns([ program_2])
      ProgramDataExportPublisher.any_instance.stubs(:publish_message).with(anything, program_2)
      export.start
    end
  end

  private

  def license_key_hash
    {:licensee =>licensed_to, :max_active_users => '10' ,:expiration_date => '2008-07-13', :max_light_users => '8', :product_edition => Registration::NON_ENTERPRISE}
  end

  def license_key(options = {})
    license_key_hash.merge(options).to_query
  end

  def licensed_to
    'barbobo'
  end

  def current_schema
    ActiveRecord::Base.configurations['test']['username']
  end
end
