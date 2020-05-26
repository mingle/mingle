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

# Tags: api, cards
class ProjectCurlApiTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  STATUS = 'Status'
  SIZE = 'Size'
  STORY = 'Story'
  DEFECT = 'Defect'
  ITERATION = 'Iteration'
  VALID_VALUES_FOR_DATE_PROPERTY = [['01-05-07', '01 May 2007'], ['07/01/68', '07 Jan 2068'], ['1 august 69', '01 Aug 1969'], ['29 FEB 2004', '29 Feb 2004']]
  DATE_PROPERTY = 'modified on (2.3.1)'
  DATE_TYPE = 'Date'
  URL = 'url'

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'WonderWorld') do |project|
        setup_numeric_property_definition(SIZE, [2, 4])
        setup_property_definitions(STATUS => ['new', 'open'])
        setup_date_property_definition(DATE_PROPERTY)
        setup_card_type(project, STORY, :properties => [STATUS, SIZE, DATE_PROPERTY])
        setup_card_type(project, ITERATION, :properties => [STATUS])
        card_favorite = CardListView.find_or_construct(project, :filters => ["[type][is][card]"])
        card_favorite.name = 'Cards Wall'
        card_favorite.save!
        page = project.pages.create!(:name => 'bonna page1'.uniquify, :content => "Welcome")
        page_favorite = project.favorites.create!(:favorited => page)
        create_cards(project, 3)
      end
    end
  end

  def teardown
    disable_basic_auth
  end

  def test_get_all_projects_should_work_when_projects_have_subversion_repositories
    SubversionConfiguration.create!(:project_id => @project.id, :repository_path => "/a_repos")

    url = projects_list_url
    output = %x[curl #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_equal 1, get_number_of_elements(output, "//projects/project")
    assert_equal project_base_url_for("subversion_configurations.xml", :user => nil), get_attribute_by_xpath(output, "projects/project/subversion_configuration/@url")
  end

  def test_create_project_via_api
    url = projects_list_url
    output = %x[curl -d "project[name]=new project" -d "project[identifier]=new_project" #{url}]
    assert_equal '', output.to_s.strip
    Project.find_by_name(name)
  end

  def test_create_project_via_api_by_read_only_user
    login, password = %w(bonna test!123)
    user = create_user!(:name => login, :login => login, :password => password, :password_confirmation => password)
    @project.add_member(user, :readonly_member)

    url = projects_list_url :user => login, :password => password
    output = %x[curl -i -d "project[name]=new project" -d "project[identifier]=new_project" #{url}]
    assert_response_code(403, output)
    assert_not_include '<html>', output
  end

  def test_to_view_non_existing_project
    url = base_api_url_for "projects", "xoeijwelkjboeijqlkjwewkjsfiejv2ije8e.xml"
    output = %x[curl -i #{url}]
    assert_response_code(404, output)
    assert_not_include '<html>', output
  end

  def test_to_view_all_existing_projects
    url = projects_list_url
    output = %x[curl #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert output =~ /<name>WonderWorld/ && /<keywords>/ && /<time zone/ && /<precision/ && /<identifier>/, "Expected projects are not listed."
  end

  def test_keyword_presentation
    # for all projects
    url = projects_list_url
    output = %x[curl -i #{url}]
    assert output =~ /<keywords>/ && /<keyword>/ && /<value>/ && /\/value/ && /\/keyword/ && /\/keywords/, "Expected keyword representation is not used."

    # for one specific project
    output = %x[curl -i #{project_url}]
    assert output =~ /<keywords>/ && /<keyword>/ && /<value>/ && /\/value/ && /\/keyword/ && /\/keywords/, "Expected keyword representation is not used."
  end
end
