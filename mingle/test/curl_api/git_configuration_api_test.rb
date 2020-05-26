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

require File.expand_path(File.dirname(__FILE__) + '/curl_api_test_helper')

# Tags: api_version_2
class GitConfigurationApiTest < ActiveSupport::TestCase
  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Zebra') { |project| create_cards(project, 3) }
    end
  end

  def teardown
    disable_basic_auth
  end

  def test_get_list_of_git_configurations_via_index_action
    GitConfiguration.create_or_update(@project.id, nil, :repository_path => 'http://somewhere')

    response = make_request(:get, "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/git_configurations.xml")
    assert_equal "200", response.code
    assert get_elements_text_by_xpath(response.body, "//git_configurations/git_configuration/repository_path").include?("http://somewhere")
  end

  def test_get_single_configuration_via_show_action
    configuration = GitConfiguration.create_or_update(@project.id, nil, :repository_path => 'http://somewhere')

    response = make_request(:get, "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/git_configurations/#{configuration.id}.xml")
    assert_equal "200", response.code
    assert get_elements_text_by_xpath(response.body, "/git_configuration/repository_path").include?("http://somewhere")
  end

  def test_get_list_of_configurations_returns_not_found_when_none_exist
    response = make_request(:get, "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/git_configurations.xml")
    assert_equal "404", response.code

    assert response.body =~ /No repository configuration found in project #{@project.identifier}./
  end

  def test_get_list_of_configurations_returns_not_found_when_none_exist_but_another_type_does
    SubversionConfiguration.create_or_update(@project.id, nil, :repository_path => 'http://over.the/rainbow')

    response = make_request(:get, "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/git_configurations.xml")
    assert_equal "404", response.code
    assert response.body =~ /No repository configuration found in project #{@project.identifier}./
  end

  def test_get_single_configuration_returns_not_found_when_none_exist
    id_that_does_not_exist = GitConfiguration.maximum(:id).to_i + 1
    response = make_request(:get, "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/git_configurations/#{id_that_does_not_exist}.xml")
    assert_equal "404", response.code

    assert response.body =~ /No repository configuration found in project #{@project.identifier}./
  end

  def test_get_single_configuration_returns_not_found_when_none_exist_but_another_type_does
    configuration = SubversionConfiguration.create_or_update(@project.id, nil, :repository_path => 'http://over.the/rainbow')

    response = make_request(:get, "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/git_configurations/#{configuration.id}.xml")
    assert_equal "404", response.code
    assert response.body =~ /No repository configuration found in project #{@project.identifier}./
  end

  def test_create_configuration
    ids_before_create = GitConfiguration.find(:all).collect(&:id)
    response = make_request(:post, "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/git_configurations.xml", <<-BODY)
      <git_configuration>
        <repository_path>http://somewhere.over.the/rainbow</repository_path>
      </git_configuration>
    BODY
    assert_equal "201", response.code
    ids_after_create = GitConfiguration.find(:all).collect(&:id)
    id_of_newly_created_configuration = (ids_after_create - ids_before_create).first
    assert_equal "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/git_configurations.xml", response['Location']
  end

  def test_update_configuration
    configuration = GitConfiguration.create_or_update(@project.id, nil, :repository_path => 'http://somewhere')

    response = make_request(:put, "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/git_configurations/#{configuration.id}.xml", <<-BODY)
      <git_configuration>
        <repository_path>http://nowhere</repository_path>
      </git_configuration>
    BODY

    assert_equal "200", response.code
    assert get_elements_text_by_xpath(response.body, "/git_configuration/repository_path").include?("http://nowhere")
  end

  def test_update_errors
    configuration = GitConfiguration.create_or_update(@project.id, nil, :repository_path => 'http://somewhere')

    response = make_request(:put, "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/git_configurations/#{configuration.id}.xml", <<-BODY)
      <git_configuration>
        <repository_path></repository_path>
      </git_configuration>
    BODY
    assert_equal "422", response.code

    assert get_elements_text_by_xpath(response.body, "/errors/error").include?("Repository path can't be blank")
  end

  def test_update_non_existent_configuration_should_fail
    id_that_does_not_exist = GitConfiguration.maximum(:id).to_i + 1

    response = make_request(:put, "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/git_configurations/#{id_that_does_not_exist}.xml", <<-BODY)
      <git_configuration>
        <repository_path>a_location</repository_path>
      </git_configuration>
    BODY
    assert_equal "422", response.code
  end

  private
  def version
    'v2'
  end

  def make_request(request_type, uri, body=nil)
    uri = URI::parse(uri)
    request = Net::HTTP.const_get(request_type.to_s.classify).new(uri.path)
    request.basic_auth 'admin', MINGLE_TEST_DEFAULT_PASSWORD
    content_negotiation_or_content_type_header_name = (request_type == :get ? 'Accepts' : 'Content-Type') #this should also include :delete and :head
    request[content_negotiation_or_content_type_header_name] = "application/xml"
    request.body = body
    Net::HTTP.new(uri.host, uri.port).start { |http| http.request(request) }
  end
end
