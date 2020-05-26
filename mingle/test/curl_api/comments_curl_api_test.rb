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

# Tags: api, cards, comments
class CommentsCurlApiTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:read_only_user)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'Comments curl api test', :users => [@project_admin], :users => [@project_admin, @team_member], :read_only_users => [@read_only_user]) do |project|
        create_cards(project, 1)
        project.update_attribute :anonymous_accessible, true
        project.save
      end
    end
    change_license_to_allow_anonymous_access
    @url_admin = "http://admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/1/comments.xml"
    @url_proj_admin = "http://proj_admin:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/1/comments.xml"
    @url_team_member = "http://member:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/1/comments.xml"
    @url_read_only_user = "http://read_only_user:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/1/comments.xml"
    @url_anon_user = "http://localhost:#{MINGLE_PORT}/api/v2/projects/#{@project.identifier}/cards/1/comments.xml"
  end

  def teardown
    disable_basic_auth
  end

  def test_newer_comment_should_be_displayed_before_older_comment
    %x[curl -X POST #{@url_team_member} -d comment[content]='the first comment']
    %x[curl -X POST #{@url_team_member} -d comment[content]='the second comment']
    output = %x[curl -i #{@url_team_member}]
    result = output.split("\n").to_s
    first_comment_location = result.index("the first comment")
    second_comment_location = result.index("the second comment")
    assert_equal(true, first_comment_location > second_comment_location)
  end

  def test_should_return_latest_comment_after_comment_card
    %x[curl -X POST #{@url_team_member} -d comment[content]='the first comment']
    output1 = %x[curl -X POST #{@url_team_member} -d comment[content]='the second comment']
    assert_response_includes('<content>the second comment</content>', output1)
    assert_not_include('<content>the first comment</content>', output1)
  end

  def test_view_card_comments_via_v2_api
    %x[curl -X POST #{@url_team_member} -d comment[content]='comment by full user']
    output1 = %x[curl #{@url_admin} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<content>comment by full user</content>', output1)
    assert_response_includes("<name>#{@team_member.name}</name>", output1)
    assert_response_includes("<login>#{@team_member.login}</login>", output1)
    assert_response_includes('<created_at type="datetime"', output1)
    assert_includes_element_named_card_comments output1

    output2 = %x[curl #{@url_proj_admin} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<content>comment by full user</content>', output2)
    assert_response_includes("<name>#{@team_member.name}</name>", output2)
    assert_response_includes("<login>#{@team_member.login}</login>", output2)
    assert_response_includes('<created_at type="datetime"', output2)
    assert_includes_element_named_card_comments output2

    output3 = %x[curl #{@url_team_member} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<content>comment by full user</content>', output3)
    assert_response_includes("<name>#{@team_member.name}</name>", output3)
    assert_response_includes("<login>#{@team_member.login}</login>", output3)
    assert_response_includes('<created_at type="datetime"', output3)
    assert_includes_element_named_card_comments output3

    output4 = %x[curl #{@url_read_only_user} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<content>comment by full user</content>', output4)
    assert_response_includes("<name>#{@team_member.name}</name>", output4)
    assert_response_includes("<login>#{@team_member.login}</login>", output4)
    assert_response_includes('<created_at type="datetime"', output4)
    assert_includes_element_named_card_comments output4

    output5 = %x[curl #{@url_anon_user} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_response_includes('<content>comment by full user</content>', output5)
    assert_response_includes("<name>#{@team_member.name}</name>", output5)
    assert_response_includes("<login>#{@team_member.login}</login>", output5)
    assert_response_includes('<created_at type="datetime"', output5)
    assert_includes_element_named_card_comments output5
  end

  def test_admin_and_full_member_can_comment_card_via_v2_api
    admin_name=User.find_by_login('admin').name

    output1 = %x[curl -X POST #{@url_admin} -d comment[content]='comment by admin via api']
    assert_response_includes('<content>comment by admin via api</content>', output1)
    assert_response_includes("<name>#{admin_name}</name>", output1)
    assert_response_includes("<login>admin</login>", output1)
    assert_response_includes('<created_at type="datetime"', output1)

    output2 = %x[curl -X POST #{@url_proj_admin} -d comment[content]='comment by project admin via api' ]
    assert_response_includes('<content>comment by project admin via api</content>', output2)
    assert_response_includes("<name>#{@project_admin.name}</name>", output2)
    assert_response_includes("<login>#{@project_admin.login}</login>", output2)
    assert_response_includes('<created_at type="datetime"', output2)

    output3 = %x[curl -X POST #{@url_team_member} -d comment[content]='comment by team member via api' ]
    assert_response_includes("<content>comment by team member via api</content>", output3)
    assert_response_includes("<name>#{@team_member.name}</name>", output3)
    assert_response_includes("<login>#{@team_member.login}</login>", output3)
    assert_response_includes('<created_at type="datetime"', output3)
  end

  def test_readonly_and_anon_user_can_not_comment_card_via_v2_api
    output1 = %x[curl -i -X POST #{@url_anon_user} -d comment[content]='comment by anon user']
    assert_response_includes('403 Forbidden', output1)
    assert_response_includes('Either the resource you requested does not exist or you do not have access rights to that resource.', output1)

    output2 = %x[curl -i -X POST #{@url_read_only_user} -d comment[content]='comment by read only user']
    assert_response_includes('403 Forbidden', output2)
    assert_response_includes('Either the resource you requested does not exist or you do not have access rights to that resource.', output2)
    output3 = %x[curl #{@url_admin} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_not_include('<content>comment by anon user</content>', output3)
    assert_not_include('<content>comment by read only user</content>', output3)
  end

  private

  def assert_includes_element_named_card_comments(output)
    assert_response_includes '</card_comments>', output
  end
end
