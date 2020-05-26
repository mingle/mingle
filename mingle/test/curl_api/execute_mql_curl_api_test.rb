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

# Tags: api, cards, mql
class ExecuteMqlCurlApiTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  STORY = 'Story'
  ITERATION = 'Iteration'
  STATUS = "STATUS"
  NAME_WITH_SPACES = "property  wit h  spaces"

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:read_only_user)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Comments curl api test', :users => [@project_admin], :users => [@project_admin, @team_member], :read_only_users => [@read_only_user]) do |project|
        setup_card_type(project, STORY)
        setup_card_type(project, ITERATION)
        create_cards(project, 1)
        project.update_attribute :anonymous_accessible, true
        project.save
      end
    end
    change_license_to_allow_anonymous_access
    @url_prefix = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/execute_mql.xml"

  end

  def teardown
    disable_basic_auth
  end

  def test_space_should_be_replaced_with_underscore_in_returned_column_name
    create_allow_any_text_property(NAME_WITH_SPACES)
    url = "#{@url_prefix}?mql=select+%27property+wit+h+spaces%27"
    output = %x[curl #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    column_name=NAME_WITH_SPACES.gsub(/\s+/, "_")
    assert_match(/<#{column_name}/, output)
  end

  def test_returned_column_name_should_be_in_lowcase
    create_allow_any_text_property(STATUS)
    url = "#{@url_prefix}?mql=select+number%2Cname%2Cstatus"
    output = %x[curl #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_match(/<status/, output)
    assert_match(/<name/, output)
    assert_match(/<number/, output)
  end

  # bug 7642
  def test_should_give_warning_message_when_execute_invalid_mql_via_api_v2_format
    url = "#{@url_prefix}?mql=select+name%2C+number+where+type+is+cards"
    output = %x[curl -i #{url}]
    expected_error = '<error>cards is not a valid value for Type, which is restricted to Card, Iteration, and Story</error>'
    assert_response_includes(expected_error, output)
    assert_response_code(422, output)
  end

  def test_no_cards_returned_as_result
    url = "#{@url_prefix}?mql=select+name%2C+number+where+number+%3E+2009"
    output = %x[curl #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_match(/<results type="array">/, output)
  end

  # bug #7924
  def test_error_message_when_no_mql_is_provided
    output = %x[curl #{@url_prefix} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_include('<error>Parameter mql is required</error>', output)
  end

  def test_error_message_when_use_old_api_format
    url = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/projects/#{@project.identifier}/cards/execute_mql.xml?mql=select+name%2C+number"
    output = %x[curl #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_include('<message>The resource URL has changed. Please use the correct URL.</message>', output)
  end
end
