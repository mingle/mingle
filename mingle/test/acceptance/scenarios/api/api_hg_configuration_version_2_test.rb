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
class ApiHgConfigurationVersion2Test < ActiveSupport::TestCase
  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra') { |project| create_cards(project, 3) }
    end

    API::Project.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}"
    API::Project.prefix = "/api/#{version}"
    API::HgConfiguration.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/projects/#{@project.identifier}"

    #reset prefix, 'ActiveResource::Base#prefix=' will reset prefix method and cache it
    API::HgConfiguration.prefix = "/api/#{version}/projects/#{@project.identifier}/"
  end

  def teardown
    disable_basic_auth
  end

  def test_get_list_of_hg_configurations_via_index_action
    requires_jruby do
      config = HgConfiguration.create!(:project_id => @project.id, :repository_path => "/a_repos", :username => 'bobo', :password => "password")
      xml = get("#{API::HgConfiguration.site}/hg_configurations.xml", {}).body

      assert_equal config.id.to_s, get_element_text_by_xpath(xml, '/hg_configurations/hg_configuration/id')
      assert_equal '/a_repos', get_element_text_by_xpath(xml, '/hg_configurations/hg_configuration/repository_path')
      assert_equal 'bobo', get_element_text_by_xpath(xml, '/hg_configurations/hg_configuration/username')
      assert_equal 0, get_number_of_elements(xml, '/hg_configurations/hg_configuration/password')
    end
  end

  def test_get_single_configuration_via_show_action
    requires_jruby do
      config = HgConfiguration.create!(:project_id => @project.id, :repository_path => "/a_repos", :username => 'bobo', :password => "password")
      xml = get("#{API::HgConfiguration.site}/hg_configurations/#{config.id}.xml", {}).body

      assert_equal config.id.to_s, get_element_text_by_xpath(xml, '/hg_configuration/id')
      assert_equal '/a_repos', get_element_text_by_xpath(xml, '/hg_configuration/repository_path')
      assert_equal 'bobo', get_element_text_by_xpath(xml, '/hg_configuration/username')
      assert_equal 0, get_number_of_elements(xml, '/hg_configuration/password')
    end
  end

  # bug 10760
  def test_get_list_of_configurations_returns_not_found_when_none_exist
    requires_jruby do
      response = get("#{API::HgConfiguration.site}/hg_configurations.xml", {})
      assert_equal '404', response.code
    end
  end

  def test_get_list_of_configurations_returns_not_found_when_none_exist_but_another_type_does
    requires_jruby do
      SubversionConfiguration.create!(:project => @project, :password => 'open sesame', :username => "bob", :repository_path => "/opt/svn_repositories/svn_sandbox")
      response = get("#{API::HgConfiguration.site}/hg_configurations.xml", {})
      assert_equal '404', response.code
    end
  end

  def test_get_single_configuration_returns_not_found_when_none_exist
    requires_jruby do
      response = get("#{API::HgConfiguration.site}/hg_configurations/1.xml", {})
      assert_equal '404', response.code
    end
  end

  def test_get_single_configuration_returns_not_found_when_none_exist_but_another_type_does
    requires_jruby do
      SubversionConfiguration.create!(:project => @project, :password => 'open sesame', :username => "bob", :repository_path => "/opt/svn_repositories/svn_sandbox")
      response = get("#{API::HgConfiguration.site}/hg_configurations/1.xml", {})
      assert_equal '404', response.code
    end
  end

  def test_create_configuration
    requires_jruby do
      config = API::HgConfiguration.create(:username => "bob", :repository_path => '/opt/svn_repositories/svn_sandbox', :password => 'foobar')
      assert config.errors.empty?

      config = API::HgConfiguration.find(:all).first
      assert_equal 'bob', config.username
      assert_equal '/opt/svn_repositories/svn_sandbox', config.repository_path
      assert !config.respond_to?(:password)
      assert @project.reload.has_source_repository?
      assert_equal '/opt/svn_repositories/svn_sandbox', @project.repository_configuration.repository_path
    end
  end

  def test_create_configuration_should_return_location_of_created_resource_in_respose_header_namaed_location
    requires_jruby do
      ids_before_create = HgConfiguration.find(:all).collect(&:id)

      uri = URI::parse("http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/hg_configurations.xml")
      request = Net::HTTP::Post.new(uri.path)
      request.basic_auth 'admin', MINGLE_TEST_DEFAULT_PASSWORD
      request['Content-Type'] = "application/xml"
      request.body = <<-BODY
        <hg_configuration>
          <repository_path>http://somewhere.over.the/rainbow</repository_path>
        </hg_configuration>
      BODY
      response = Net::HTTP.new(uri.host, uri.port).start { |http| http.request(request) }

      assert_equal "201", response.code
      ids_after_create = HgConfiguration.find(:all).collect(&:id)
      id_of_newly_created_configuration = (ids_after_create - ids_before_create).first
      assert_equal "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/hg_configurations.xml", response['Location']
    end
  end


  def test_update_configuration
    requires_jruby do
      config = HgConfiguration.create!(:project_id => @project.id, :repository_path => "/a_repos", :username => 'bobo', :password => "password")
      @project.reload

      params = {"hg_configuration[username]" => "bob", "hg_configuration[repository_path]" => '/a_different_repos', "hg_configuration[password]" => 'foobar', "hg_configuration[project_id]" => "#{@project.id}", "hg_configuration[marked_for_deletion]" => false, "id" => config.id}
      response = put("#{API::HgConfiguration.site}/hg_configurations.xml", params)

      config = API::HgConfiguration.find(:all).first
      assert_equal 'bob', config.username
      assert_equal '/a_different_repos', config.repository_path
    end
  end

  def test_delete_configuration
    requires_jruby do
      config = HgConfiguration.create!(:project_id => @project.id, :repository_path => "/a_repos", :username => 'bobo', :password => "password")
      @project.reload

      params = {"hg_configuration[username]" => "bob", "hg_configuration[repository_path]" => '/a_different_repos', "hg_configuration[password]" => 'foobar', "hg_configuration[project_id]" => "#{@project.id}", "hg_configuration[marked_for_deletion]" => true, "id" => config.id}
      put("#{API::HgConfiguration.site}/hg_configurations.xml", params)

      RevisionsHeaderCaching.run_once

      response = get("#{API::HgConfiguration.site}/hg_configurations.xml", {})
      assert_equal '404', response.code
    end
  end

  # bug 8515
  def test_should_only_allow_creation_of_one_configuration_for_a_project
    requires_jruby do
      config = API::HgConfiguration.create(:username => "bob", :repository_path => '/a_repos', :password => 'foobar')
      assert config.errors.empty?
      config = API::HgConfiguration.create(:username => "bob1", :repository_path => '/another_repos', :password => 'foobar')
      assert_equal ["Could not create the new repository configuration because a repository configuration already exists."], config.errors.full_messages

      RevisionsHeaderCaching.run_once

      config = API::HgConfiguration.find(:all).first
      assert_equal 'bob', config.username
      assert_equal '/a_repos', config.repository_path
    end
  end

  def test_update_errors
    requires_jruby do
      config = HgConfiguration.create!(:project_id => @project.id, :repository_path => '/a_repos', :username => 'bob', :password => "password")
      bad_repository = 'this is not a good repository'
      params = {"hg_configuration[project_id]" => @project.id.to_s,
                "hg_configuration[repository_path]" => bad_repository,
                "id" => config.id}
      response = put("#{API::HgConfiguration.site}/hg_configurations.xml", params)
      assert_equal "422", response.code
    end
  end

  def test_update_non_existent_configuration_should_fail
    requires_jruby do
      params = {"hg_configuration[username]" => "bob", "hg_configuration[repository_path]" => '/a_repos', "hg_configuration[password]" => 'foobar', "hg_configuration[project_id]" => "#{@project.id}", "id" => "99999"}
      response = put("#{API::HgConfiguration.site}/hg_configurations.xml", params)
      assert_equal '422', response.code
    end
  end

  protected

  def version
    'v2'
  end
end
