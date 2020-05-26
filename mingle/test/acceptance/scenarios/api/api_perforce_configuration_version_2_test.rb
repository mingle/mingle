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

require File.expand_path(File.dirname(__FILE__) + '/api_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../acceptance_test_helper')

# Tags: api_version_2
class ApiPerforceConfigurationVersion2Test < ActiveSupport::TestCase

  fixtures :users, :login_access

  def version
    "v2"
  end

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra') { |project| create_cards(project, 3) }
    end

    API::Project.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}"
    API::Project.prefix = "/api/#{version}"

    API::PerforceConfiguration.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}"

    #reset prefix, 'ActiveResource::Base#prefix=' will reset prefix method and cache it
    API::PerforceConfiguration.prefix = "/api/#{version}/projects/#{@project.identifier}/"
  end

  def teardown
    disable_basic_auth
  end

  def test_get_configuration
    requires_perforce_available do
      params = {:username => "bob", :host => 'localhost', :port => '1666', :repository_path => '//depot', :password => 'foobar', :project => @project}
      p4_config = PerforceConfiguration.new(params)
      p4_config.save!

      config = API::PerforceConfiguration.find(:all).first

      assert_equal p4_config.id, config.id
      assert_equal "bob", config.username
      assert_equal '//depot', config.repository_path
      assert_equal 'localhost', config.host
      assert_equal '1666', config.port
      assert_equal false, config.marked_for_deletion
      assert_equal @project.identifier, config.project.identifier
      assert_equal @project.name, config.project.name
      assert !config.respond_to?(:password)
    end
  end

  # bug 10760
  def test_get_configuration_returns_not_found_when_none_exist
    requires_perforce_available do
      response = get("#{API::PerforceConfiguration.site}/perforce_configurations.xml", {})
      assert_equal '404', response.code
    end
  end

  def test_get_configuration_returns_not_found_when_none_exist_but_another_type_does
    requires_perforce_available do
      SubversionConfiguration.create!(:project => @project, :password => 'open sesame', :username => "bob", :repository_path => "/opt/svn_repositories/svn_sandbox")
      response = get("#{API::PerforceConfiguration.site}/perforce_configurations.xml", {})
      assert_equal '404', response.code
    end
  end

  def test_create_configuration
    requires_perforce_available do
      params = {"perforce_configuration[username]" => "bob", "perforce_configuration[host]" => 'localhost', "perforce_configuration[port]" => '1666', "perforce_configuration[repository_path]" => '//depot', "perforce_configuration[password]" => 'foobar'}
      response = post("#{API::PerforceConfiguration.site}/perforce_configurations.xml", params)
      assert_match /\/api\/#{version}\/projects\/#{@project.identifier}\/perforce_configurations\.xml$/, response.header['location']

      config = API::PerforceConfiguration.find(:all).first
      assert_equal 'bob', config.username
      assert_equal '//depot', config.repository_path
      assert !config.respond_to?(:password)
      assert @project.reload.has_source_repository?
      assert_equal '//depot', @project.repository_configuration.repository_path
    end
  end

  def test_create_configuration_errors
    requires_perforce_available do
      params = {"perforce_configuration[username]" => "", "perforce_configuration[host]" => 'localhost', "perforce_configuration[port]" => '1666', "perforce_configuration[repository_path]" => '//depot', "perforce_configuration[password]" => 'foobar'}
      response = post("#{API::PerforceConfiguration.site}/perforce_configurations.xml", params)
      assert_equal "422", response.code
    end
  end

  def test_update_configuration_by_giving_id_as_param
    requires_perforce_available do
      config = PerforceConfiguration.create!(:project_id => @project.id,
                                             :repository_path => '\\depot',
                                             :username => 'bobo',
                                             :password => "password",
                                             :port => 1666,
                                             :host => 'localhost')

      params = {"perforce_configuration[project_id]" => @project.id.to_s,
                "perforce_configuration[repository_path]" => 'another_depot',
                "perforce_configuration[username]" => "bob",
                "perforce_configuration[password]" => 'foobar',
                "perforce_configuration[port]" => 'o.vallarta',
                "perforce_configuration[host]" => 'leno',
                "perforce_configuration[marked_for_deletion]" => false,
                "id" => config.id}
      response = put("#{API::PerforceConfiguration.site}/perforce_configurations.xml", params)

      config = API::PerforceConfiguration.find(:all).first
      assert_equal 'another_depot', config.repository_path
      assert_equal 'bob', config.username
      assert_equal 'o.vallarta', config.port
      assert_equal 'leno', config.host
      assert_equal false, config.marked_for_deletion
    end
  end

  def test_update_configuration_by_giving_id_in_url
    requires_perforce_available do
      config = PerforceConfiguration.create!(:project_id => @project.id,
                                             :repository_path => '\\depot',
                                             :username => 'bobo',
                                             :password => "password",
                                             :port => 1666,
                                             :host => 'localhost')

      params = {"perforce_configuration[project_id]" => @project.id.to_s,
                "perforce_configuration[repository_path]" => 'another_depot',
                "perforce_configuration[username]" => "bob",
                "perforce_configuration[password]" => 'foobar',
                "perforce_configuration[port]" => 'o.vallarta',
                "perforce_configuration[host]" => 'leno',
                "perforce_configuration[marked_for_deletion]" => false}
      response = put("#{API::PerforceConfiguration.site}/perforce_configurations/#{config.id}.xml", params)

      config = API::PerforceConfiguration.find(:all).first
      assert_equal 'another_depot', config.repository_path
      assert_equal 'bob', config.username
      assert_equal 'o.vallarta', config.port
      assert_equal 'leno', config.host
      assert_equal false, config.marked_for_deletion
    end
  end

  def test_update_errors
    requires_perforce_available do
      config = PerforceConfiguration.create!(:project_id => @project.id,
                                             :repository_path => '\\depot',
                                             :username => 'bobo',
                                             :password => "password",
                                             :port => 1666,
                                             :host => 'localhost')
      bad_depot = 'another_depot(*)'
      params = {"perforce_configuration[project_id]" => @project.id.to_s,
                "perforce_configuration[repository_path]" => bad_depot,
                "perforce_configuration[username]" => "bob",
                "perforce_configuration[password]" => 'foobar',
                "perforce_configuration[port]" => 'o.vallarta',
                "perforce_configuration[host]" => 'leno',
                "perforce_configuration[marked_for_deletion]" => false,
                "id" => config.id}
      response = put("#{API::PerforceConfiguration.site}/perforce_configurations.xml", params)
      assert_equal "422", response.code
    end
  end

  def test_update_non_existent_configuration
    requires_perforce_available do
      params = {"perforce_configuration[project_id]" => @project.id.to_s,
                "perforce_configuration[repository_path]" => 'another_depot',
                "perforce_configuration[username]" => "bob",
                "perforce_configuration[password]" => 'foobar',
                "perforce_configuration[port]" => 'o.vallarta',
                "perforce_configuration[host]" => 'leno',
                "perforce_configuration[marked_for_deletion]" => false,
                "id" => "999"}
      response = put("#{API::PerforceConfiguration.site}/perforce_configurations.xml", params)

      assert_equal "422", response.code
    end
  end

  def test_delete_configuration
    requires_perforce_available do
      config = PerforceConfiguration.create!(:project_id => @project.id,
                                             :repository_path => '\\depot',
                                             :username => 'bobo',
                                             :password => "password",
                                             :port => 1666,
                                             :host => 'localhost')

      params = {"perforce_configuration[project_id]" => @project.id.to_s,
                "perforce_configuration[marked_for_deletion]" => true,
                "id" => config.id}

      response = put("#{API::PerforceConfiguration.site}/perforce_configurations.xml", params)

      RevisionsHeaderCaching.run_once

      response = get("#{API::PerforceConfiguration.site}/perforce_configurations.xml", {})
      assert_equal '404', response.code
    end
  end

  # bug 8515
  def test_should_only_allow_creation_of_one_perforce_configuration_for_a_project
    requires_perforce_available do
      params = {"perforce_configuration[username]" => "bob", "perforce_configuration[host]" => 'localhost', "perforce_configuration[port]" => '1666', "perforce_configuration[repository_path]" => '//depot', "perforce_configuration[password]" => 'foobar'}
      response = post("#{API::PerforceConfiguration.site}/perforce_configurations.xml", params)

      configs = PerforceConfiguration.find(:all)
      assert_equal 1, configs.size

      params = {"perforce_configuration[username]" => "bob", "perforce_configuration[host]" => 'localhost', "perforce_configuration[port]" => '1666', "perforce_configuration[repository_path]" => '//homedepot', "perforce_configuration[password]" => 'foobar'}
      response = post("#{API::PerforceConfiguration.site}/perforce_configurations.xml", params)

      configs = PerforceConfiguration.find(:all)
      assert_equal 1, configs.size

      assert_equal "//depot", configs.first.repository_path
    end
  end

  def test_index_get_should_indicate_that_perforce_is_not_available
    requires_perforce_unavailable do
      params = {:username => "bob", :host => 'localhost', :port => '1666', :repository_path => '//depot', :password => 'foobar', :project => @project}
      p4_config = PerforceConfiguration.new(params)
      p4_config.save!

      response = get("#{API::PerforceConfiguration.site}/perforce_configurations.xml", {})
      assert_equal '422', response.code
      puts response.read_body
      expected_error = "The Perforce client executable (#{P4CmdConfiguration.configured_p4_cmd}) was not found. Please ensure that this is installed, that the complete path has been updated in perforce_config.yml and try again."
      assert_include "perforce_config.yml", get_element_text_by_xpath(response.read_body, "errors/error")
    end
  end
end
