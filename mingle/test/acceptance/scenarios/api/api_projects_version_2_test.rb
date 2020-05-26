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

# Tags: api_version_2, project
class ApiProjectsVersion2Test < ActiveSupport::TestCase

  fixtures :users, :login_access

  def version
    'v2'
  end

  def setup
    enable_basic_auth
    API::Project.site = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/"
    API::Project.prefix = "/api/#{version}/"
  end

  def teardown
    disable_basic_auth
  end

  test 'can_create_a_project_and_find_it' do
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    post("#{API::Project.site}projects.xml", {'project[name]' => 'Zebra', 'project[identifier]' => 'zebra'})
    project = Project.find_by_identifier('zebra')
    assert_equal 'zebra', project.identifier
    assert_equal 'Zebra', project.name

    response = get("#{API::Project.site}projects/zebra.xml", {})
    assert_equal 'zebra', get_element_text_by_xpath(response.body, '//project/identifier')
  end

  test 'as_project_admin_i_can_switch_anonymous_accessibilty_of_a_project_by_rest_api' do
    destroy_all_records(:destroy_users => false, :destroy_projects => true)

    post("#{API::Project.site}projects.xml", {'project[name]' => 'Zebra1', 'project[identifier]' => 'zebra1'})
    project_response = get("#{API::Project.site}projects/zebra1.xml", {})
    assert_equal 'false', get_element_text_by_xpath(project_response.body, '//project/anonymous_accessible')
    assert_not Project.find_by_identifier('zebra1').anonymous_accessible?

    post("#{API::Project.site}projects.xml", {'project[name]' => 'Zebra2', 'project[identifier]' => 'zebra2', 'project[anonymous_accessible]' => true})
    project_response = get("#{API::Project.site}projects/zebra2.xml", {})
    assert_equal 'true', get_element_text_by_xpath(project_response.body, '//project/anonymous_accessible')
    assert Project.find_by_identifier('zebra2').anonymous_accessible?
  end

  test 'should_not_be_able_to_get_secret_key_even_mingle_admin' do
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    project = API::Project.create(:name => 'Zebra', :identifier => 'zebra')
    assert !API::Project.find(project.identifier).respond_to?(:secret_key)
    assert_not_nil Project.find_by_identifier('zebra').secret_key
  end

  test 'should_get_error_message_when_create_project_failed' do
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    API::Project.create(:name => 'Zebra', :identifier => 'zebra')
    project = API::Project.create(:name => 'Zebra', :identifier => 'zebra')
    assert !project.valid?
    ['Identifier has already been taken', 'Name has already been taken'].each { |msg| assert_include(msg, project.errors.full_messages) }
  end

  test 'should_not_be_able_to_create_project_by_non_admin' do
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    API::Project.site = "http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/"
    #reset prefix, 'ActiveResource::Base#prefix=' will reset prefix method and cache it
    API::Project.prefix = "/api/#{version}/"
    assert_raise ActiveResource::ForbiddenAccess do
      API::Project.create(:name => 'Zebra', :identifier => 'zebra')
    end
  end

  test 'should_be_able_to_get_project_info_by_team_member' do
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    API::Project.site = "http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/#{version}/"
    #reset prefix, 'ActiveResource::Base#prefix=' will reset prefix method and cache it
    API::Project.prefix = "/api/#{version}/"
    User.find_by_login('admin').with_current do
      @project = create_project
      @project.add_member User.find_by_login('member')
      @project.save!
    end

    assert API::Project.find(@project.identifier)
  end

  test 'should_get_a_list_of_all_projects_for_mingle_admin' do
    User.find_by_login('admin').with_current do
      assert_equal Project.find(:all).reject(&:hidden?).size, API::Project.find(:all).size
    end
  end

  test 'can_create_a_project_with_auto_enroll_user_type_option' do
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    total_users_count = User.count

    project = API::Project.create(:name => 'auto_enroll_user_type', :identifier => 'auto_enroll_user_type', :auto_enroll_user_type => 'readonly')
    assert_equal 'readonly', project.auto_enroll_user_type

    Project.find_by_identifier('auto_enroll_user_type').with_active_project do |project|
      assert_equal total_users_count, project.users.size
      assert project.users.all? { |u| project.readonly_member?(u) }
    end
  end

  test 'should_raise_error_when_auto_enroll_user_type_is_not_full_or_readonly_during_creation' do
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    project = API::Project.create(:name => 'auto_enroll_user_type', :identifier => 'auto_enroll_user_type', :auto_enroll_user_type => 'invalid')
    assert !project.valid?
    assert_equal ["\"invalid\" is not a valid value for \"auto_enroll_user_type\", which is restricted to \"full\", \"readonly\", or nil"], project.errors.full_messages
  end

  test 'xml_structure_should_not_have_value_element_around_keyword_values' do
    new_project = create_project :skip_activation => true
    xml = get("#{API::Project.site}projects/#{new_project.identifier}.xml", {}).body
    assert_equal '#', get_element_text_by_xpath(xml, "//project/keywords/keyword[text()='#']")
  end

  test 'chart_data_json_should_include_date_format_card_types_tags_and_series_colors' do
    new_project = create_project :skip_activation => true
    expected_chart_data = {'name' => new_project.name,
                           'identifier' => new_project.identifier,
                           'dateFormat' => new_project.date_format,
                           'cardTypes' => new_project.card_types.collect do |card_type|
                             {
                                 'id' => card_type.id,
                                 'name' => card_type.name,
                                 'color' => card_type.color,
                                 'position' => card_type.position,
                                 'propertyDefinitions' => []
                             }
                           end,
                           'team' => [],
                           'tags' => [],
                           'colors' => %w(#3D8F84 #19A657 #55EB7D #198FA6 #24C2CC #30E4EF #712468 #EE5AA2 #FFA5D1 #D4292B #EE675A #EB9955 #EBC855 #EAEB55 #000000)}

    json = JSON.parse(get("#{API::Project.site}projects/#{new_project.identifier}/chart_data.json", {}).body)

    assert_equal expected_chart_data, json
  end
end
