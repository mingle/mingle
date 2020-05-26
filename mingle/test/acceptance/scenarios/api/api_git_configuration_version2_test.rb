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
class ApiGitConfigurationVersion2Test < ActiveSupport::TestCase
  fixtures :users, :login_access

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra') { |project| create_cards(project, 3) }
    end

    API::Project.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}"
    API::Project.prefix = "/api/#{version}"
    API::GitConfiguration.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}"

    #reset prefix, 'ActiveResource::Base#prefix=' will reset prefix method and cache it
    API::GitConfiguration.prefix = "/api/#{version}/projects/#{@project.identifier}/"
  end

  def teardown
    disable_basic_auth
  end

  def test_get_list_of_git_configuration_via_index_action
    config = GitConfiguration.create!(:project_id => @project.id, :repository_path => "/a_repos", :username => 'bobo', :password => "password")
    xml = get("#{API::GitConfiguration.site}/git_configurations.xml", {}).body
    assert_equal config.id.to_s, get_element_text_by_xpath(xml, '/git_configurations/git_configuration/id')
    assert_equal '/a_repos', get_element_text_by_xpath(xml, '/git_configurations/git_configuration/repository_path')
    assert_equal 'bobo', get_element_text_by_xpath(xml, '/git_configurations/git_configuration/username')
    assert_equal 0, get_number_of_elements(xml, '/git_configurations/git_configuration/password')
  end

  def test_get_single_configuration_via_show_action
    config = GitConfiguration.create!(:project_id => @project.id, :repository_path => "/a_repos", :username => 'bobo', :password => "password")
    xml = get("#{API::GitConfiguration.site}/git_configurations/#{config.id}.xml", {}).body

    assert_equal config.id.to_s, get_element_text_by_xpath(xml, '/git_configuration/id')
    assert_equal '/a_repos', get_element_text_by_xpath(xml, '/git_configuration/repository_path')
    assert_equal 'bobo', get_element_text_by_xpath(xml, '/git_configuration/username')
    assert_equal 0, get_number_of_elements(xml, '/git_configuration/password')
  end

  # bug 10760
  def test_get_list_of_configurations_returns_not_found_when_none_exist
    response = get("#{API::GitConfiguration.site}/git_configurations.xml", {})
    assert_equal '404', response.code
  end

  def test_get_list_of_configurations_returns_not_found_when_none_exist_but_another_type_does
    SubversionConfiguration.create!(:project => @project, :password => 'open sesame', :username => "bob", :repository_path => "/opt/svn_repositories/svn_sandbox")
    response = get("#{API::GitConfiguration.site}/git_configurations.xml", {})
    assert_equal '404', response.code
  end

  def test_get_single_configuration_returns_not_found_when_none_exist
    response = get("#{API::GitConfiguration.site}/git_configurations/1.xml", {})
    assert_equal '404', response.code
  end

  def test_get_single_configuration_returns_not_found_when_none_exist_but_another_type_does
    SubversionConfiguration.create!(:project => @project, :password => 'open sesame', :username => "bob", :repository_path => "/opt/svn_repositories/svn_sandbox")
    response = get("#{API::GitConfiguration.site}/git_configurations/1.xml", {})
    assert_equal '404', response.code
  end

  def test_create_configuration
    config = API::GitConfiguration.create(:username => "bob", :repository_path => '/opt/svn_repositories/svn_sandbox', :password => 'foobar')
    assert config.errors.empty?

    config = API::GitConfiguration.find(:all).first
    assert_equal 'bob', config.username
    assert_equal '/opt/svn_repositories/svn_sandbox', config.repository_path
    assert !config.respond_to?(:password)
    assert @project.reload.has_source_repository?
    assert_equal '/opt/svn_repositories/svn_sandbox', @project.repository_configuration.repository_path
  end

  def test_update_configuration
    config = GitConfiguration.create!(:project_id => @project.id, :repository_path => "/a_repos", :username => 'bobo', :password => "password")
    @project.reload

    params = {"git_configuration[username]" => "bob", "git_configuration[repository_path]" => '/a_different_repos', "git_configuration[password]" => 'foobar', "git_configuration[project_id]" => "#{@project.id}", "git_configuration[marked_for_deletion]" => false, "id" => config.id}
    response = put("#{API::GitConfiguration.site}/git_configurations.xml", params)

    config = API::GitConfiguration.find(:all).first
    assert_equal 'bob', config.username
    assert_equal '/a_different_repos', config.repository_path
  end

  def test_update_configuration_should_fail_with_unprocessable_entity_for_invalid_config_type
    config = GitConfiguration.create!(:project_id => @project.id, :repository_path => "/a_repos", :username => 'bobo', :password => "password")
    @project.reload

    params = {"cvs_configuration[username]" => "bob", "cvs_configuration[repository_path]" => '/a_different_repos', "cvs_configuration[password]" => 'foobar', "cvs_configuration[project_id]" => "#{@project.id}", "cvs_configuration[marked_for_deletion]" => false, "id" => config.id}
    response = put("#{API::GitConfiguration.site}/git_configurations.xml", params)

    assert_equal "422", response.code
  end

  def test_delete_configuration
    config = GitConfiguration.create!(:project_id => @project.id, :repository_path => "/a_repos", :username => 'bobo', :password => "password")
    @project.reload

    params = {"git_configuration[username]" => "bob", "git_configuration[repository_path]" => '/a_different_repos', "git_configuration[password]" => 'foobar', "git_configuration[project_id]" => "#{@project.id}", "git_configuration[marked_for_deletion]" => true, "id" => config.id}
    put("#{API::GitConfiguration.site}/git_configurations.xml", params)

    RevisionsHeaderCaching.run_once

    response = get("#{API::GitConfiguration.site}/git_configurations.xml", {})
    assert_equal '404', response.code
  end

  # bug 8515
  def test_should_only_allow_creation_of_one_configuration_for_a_project
    config = API::GitConfiguration.create(:username => "bob", :repository_path => '/a_repos', :password => 'foobar')
    assert config.errors.empty?
    config = API::GitConfiguration.create(:username => "bob1", :repository_path => '/another_repos', :password => 'foobar')
    assert_equal ["Could not create the new repository configuration because a repository configuration already exists."], config.errors.full_messages

    RevisionsHeaderCaching.run_once

    config = API::GitConfiguration.find(:all).first
    assert_equal 'bob', config.username
    assert_equal '/a_repos', config.repository_path
  end

  def test_update_errors
    config = GitConfiguration.create!(:project_id => @project.id, :repository_path => '/a_repos', :username => 'bob', :password => "password")
    bad_repository = 'this is not a good repository'
    params = {"git_configuration[project_id]" => @project.id.to_s,
              "git_configuration[repository_path]" => bad_repository,
              "id" => config.id}
    response = put("#{API::GitConfiguration.site}/git_configurations.xml", params)
    assert_equal "422", response.code
  end

  def test_update_non_existent_configuration_should_fail
    params = {"git_configuration[username]" => "bob", "git_configuration[repository_path]" => '/a_repos', "git_configuration[password]" => 'foobar', "git_configuration[project_id]" => "#{@project.id}", "id" => "99999"}
    response = put("#{API::GitConfiguration.site}/git_configurations.xml", params)
    assert_equal '422', response.code
  end

  protected

  def version
    'v2'
  end
end
