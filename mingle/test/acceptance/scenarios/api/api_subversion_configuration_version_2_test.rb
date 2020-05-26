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

# Tags: api_version_2
class ApiSubversionConfigurationVersion2Test < ActiveSupport::TestCase

  fixtures :users, :login_access
  include TreeFixtures::PlanningTree

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra') { |project| create_cards(project, 3) }
    end
    @version="v2"

    API::Project.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{@version}"
    API::Project.prefix = "/api/#{@version}"
    API::SubversionConfiguration.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{@version}/projects/#{@project.identifier}"

    #reset prefix, 'ActiveResource::Base#prefix=' will reset prefix method and cache it
    API::SubversionConfiguration.prefix = "/api/#{@version}/projects/#{@project.identifier}/"
  end

  def teardown
    disable_basic_auth
  end

  def test_create_configuration
    config = API::SubversionConfiguration.create(:username => "bob", :repository_path => '/opt/svn_repositories/svn_sandbox', :password => 'foobar')
    assert config.errors.empty?

    config = API::SubversionConfiguration.find(:all).first

    assert_equal 'bob', config.username
    assert_equal '/opt/svn_repositories/svn_sandbox', config.repository_path
    assert !config.respond_to?(:password)

    assert @project.reload.has_source_repository?
    assert_equal '/opt/svn_repositories/svn_sandbox', @project.repository_configuration.repository_path
  end

  # bug 8515
  def test_should_only_allow_creation_of_one_configuration_for_a_project
    config = API::SubversionConfiguration.create(:username => "bob", :repository_path => '/opt/svn_repositories/svn_sandbox', :password => 'foobar')
    assert config.errors.empty?
    config = API::SubversionConfiguration.create(:username => "bob1", :repository_path => '/opt/', :password => 'foobar')
    assert_equal ["Could not create the new repository configuration because a repository configuration already exists."], config.errors.full_messages
    configs = SubversionConfiguration.find(:all)
    assert_equal 1, configs.size
    assert_equal '/opt/svn_repositories/svn_sandbox', configs.first.repository_path
  end

  # bug 8515
  def test_create_two_svn_configurations_for_project_whilst_first_is_marked_for_delete_will_allow_creation_of_second
    config = API::SubversionConfiguration.create(:username => "bob", :repository_path => '/opt/svn_repositories/svn_sandbox', :password => 'foobar', :marked_for_deletion => true)
    assert config.errors.empty?
    config = API::SubversionConfiguration.create(:username => "bob1", :repository_path => '/opt/', :password => 'foobar')
    assert config.errors.empty?

    configs = SubversionConfiguration.find(:all)
    assert_equal 2, configs.size

    for_delete, not_for_delete = configs.partition { |c| c.marked_for_deletion? }
    assert_equal "/opt/svn_repositories/svn_sandbox", for_delete.first.repository_path
    assert_equal "/opt/", not_for_delete.first.repository_path
  end

  # bug 8515
  def test_should_allow_creation_of_one_configuration_for_per_project
    config = API::SubversionConfiguration.create(:username => "bob", :repository_path => '/opt/svn_repositories/svn_sandbox', :password => 'foobar')
    assert config.errors.empty?
    login_as_admin
    with_new_project do |project|
      create_three_level_tree
      params = {"subversion_configuration[username]" => "bob", "subversion_configuration[repository_path]" => '/opt/svn_repositories/svn_sandbox', "subversion_configuration[password]" => 'foobar', "subversion_configuration[project_id]" => "#{@project.id + 5}"}
      response = post("http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{@version}/projects/#{project.identifier}/subversion_configurations.xml", params)
      assert_equal "201", response.code
    end

    configs = SubversionConfiguration.find(:all)
    assert_equal 2, configs.size
    configs.each { |c| assert !c.marked_for_deletion? }
  end

  # bug 7950
  def test_update_non_existent_configuration_should_not_delete_exisiting_configuration
    params = {"subversion_configuration[username]" => "bob", "subversion_configuration[repository_path]" => '/opt/svn_repositories/svn_sandbox', "subversion_configuration[password]" => 'foobar', "subversion_configuration[project_id]" => "#{@project.id + 5}"}
    response = post("#{API::SubversionConfiguration.site}/subversion_configurations.xml", params)

    original_id = get_element_text_by_xpath(response.read_body, "/subversion_configuration/id")

    response = put("#{API::SubversionConfiguration.site}/subversion_configurations/99999.xml", params)
    assert_equal '422', response.code

    response = get("#{API::SubversionConfiguration.site}/subversion_configurations.xml", {})
    assert_equal original_id, get_element_text_by_xpath(response.read_body, "subversion_configurations/subversion_configuration/id")
  end

  def test_update_marked_for_deletion_to_true_to_delete_current_configuration
    params = {"subversion_configuration[username]" => "bob", "subversion_configuration[repository_path]" => '/opt/svn_repositories/svn_sandbox', "subversion_configuration[password]" => 'foobar', "subversion_configuration[project_id]" => "#{@project.id}"}
    response = post("#{API::SubversionConfiguration.site}/subversion_configurations.xml", params)
    id = get_element_text_by_xpath(response.read_body, "/subversion_configuration/id")
    project_identifier = get_element_text_by_xpath(response.read_body, "/subversion_configuration/project/identifier")
    assert_equal @project.identifier, project_identifier

    put("#{API::SubversionConfiguration.site}/subversion_configurations.xml", {"subversion_configuration[marked_for_deletion]" => true, "id" => id})

    params = {"subversion_configuration[username]" => "new bob", "subversion_configuration[repository_path]" => '/opt/svn_repositories/svn_sandbox', "subversion_configuration[password]" => 'foobar', "subversion_configuration[project_id]" => "#{@project.id}"}
    post("#{API::SubversionConfiguration.site}/subversion_configurations.xml", params)

    response = get("#{API::SubversionConfiguration.site}/subversion_configurations.xml", {})
    assert_equal 1, get_number_of_elements(response.read_body, "/subversion_configurations")
    assert_equal 'new bob', get_element_text_by_xpath(response.read_body, "/subversion_configurations/subversion_configuration/username")
  end

  def test_project_id_should_be_readonly
    params = {"subversion_configuration[username]" => "bob", "subversion_configuration[repository_path]" => '/opt/svn_repositories/svn_sandbox', "subversion_configuration[password]" => 'foobar', "subversion_configuration[project_id]" => "#{@project.id + 5}"}
    response = post("#{API::SubversionConfiguration.site}/subversion_configurations.xml", params)
    project_identifier = get_element_text_by_xpath(response.read_body, "/subversion_configuration/project/identifier")
    assert_equal @project.identifier, project_identifier

    id = get_element_text_by_xpath(response.read_body, "/subversion_configuration/id")
    params = {"id" => id, "subversion_configuration[project_id]" => "#{@project.id + 6}"}
    response = put("#{API::SubversionConfiguration.site}/subversion_configurations.xml", params)
    project_identifier = get_element_text_by_xpath(response.read_body, "/subversion_configuration/project/identifier")
    assert_equal @project.identifier, project_identifier
  end

  # bug 10760
  def test_get_subversion_configurations_returns_not_found_when_none_exist
    response = get("#{API::SubversionConfiguration.site}/subversion_configurations.xml", {})
    assert_equal '404', response.code
    assert_equal "No repository configuration found in project #{@project.identifier}.", response.body
  end

  # bug 8515
  def test_should_only_allow_creation_of_one_configuration_for_a_project_when_existing_is_of_different_type
    requires_jruby do
      config = API::SubversionConfiguration.create(:username => "bob", :repository_path => '/opt/svn_repositories/svn_sandbox', :password => 'foobar')
      assert config.errors.empty?
      hg_base_url = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{@version}/projects/#{@project.identifier}"
      params = {"hg_configuration[username]" => "bob", "hg_configuration[repository_path]" => '/a_different_repos', "hg_configuration[password]" => 'foobar', "hg_configuration[project_id]" => "#{@project.id}", "hg_configuration[marked_for_deletion]" => false}
      response = post("#{hg_base_url}/hg_configurations.xml", params)

      assert_equal "422", response.code
      assert_include "Could not create the new repository configuration because a repository configuration already exists.", response.read_body

      hg_configs = HgConfiguration.find(:all)
      assert_equal 0, hg_configs.size

      configs = SubversionConfiguration.find(:all)
      assert_equal 1, configs.size
      assert !configs.first.marked_for_deletion?
      assert_equal '/opt/svn_repositories/svn_sandbox', configs.first.repository_path
    end
  end


end
