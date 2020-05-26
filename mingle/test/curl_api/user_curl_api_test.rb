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
class UserCurlApiTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:read_only_user)
    User.find_by_login('admin').with_current do
      @project = with_new_project(:name => 'WonderWorld', :users => [@project_admin, @team_member], :read_only_users => [@read_only_user]) do |project|
      end
    end
  end

  def teardown
    disable_basic_auth
  end

  def test_get_all_users_from_project
    url = base_api_url_for "users.xml"
    output = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert output =~ /<name>admin<\/name>/ || /<name>test/
  end

  def test_invite_user_for_project
    email = 'memberx@team.com'
    url = base_api_url_for "projects/#{@project.identifier}/team/invite_user.json"
    output = %x[curl -X POST -d"email=#{email}" #{url}]
    @project.reload.with_active_project do |proj|
      assert proj.users.find_by_email(email)
    end
  end

  def test_last_login_is_updated_on_api_access
    admin = User.find_by_login('admin')
    admin.login_access.update_attribute :last_login_at, nil

    url = base_api_url_for "users", "#{admin.id}.xml"

    output1 = %x[curl -X GET #{url} | xmllint --format -].tap { raise "xml malformed!" unless $?.success? }
    assert_match(/<last_login_at type="datetime">/, output1)
  end

  pending "currently when this request is given we make the user as a light user. but we should provide a proper error."

  def test_can_not_set_admin_and_light_user_both_as_true_when_create_user
    url = base_api_url_for "users.xml"
    output = %x[curl -i -X POST -d"user[name]=xiayan&user[login]=xiayan&user[password]=123&user[password_confirmation]=123&user[admin]=true&user[light]=true" #{url}]
    assert_response_code(409, output) # code 409 indicates that the request could not be processed because of conflict in the request
  end

  # story 10148
  def test_project_admin_should_be_able_to_view_users_show_api
    proj_admin = User.find_by_login('proj_admin')
    proj_admin.projects.first.add_member(proj_admin, :project_admin)
    output = %x[curl -i -X GET http://#{proj_admin.login}:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/users/#{proj_admin.id}.xml]
    assert_response_code 200, output
  end

  def test_any_project_admin_should_be_able_to_view_users_list_api
    proj_admin = User.find_by_login('proj_admin')
    proj_admin.projects.first.add_member(proj_admin, :project_admin)
    output = %x[curl -i -X GET http://#{proj_admin.login}:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/users.xml]
    assert_response_code 200, output
    assert_no_match(/<last_login_at type="datetime">/, output)
  end

  def test_project_admin_cannot_create_or_udpate_user
    proj_admin = User.find_by_login('proj_admin')
    proj_admin.projects.first.add_member(proj_admin, :project_admin)

    output = %x[curl -i -X POST -d"user[name]=foo_user&user[login]=foo_user&user[password]=123&user[password_confirmation]=123" http://#{proj_admin.login}:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/users.xml]
    assert_response_code(403, output)

    output2 = %x[curl -i -X PUT -d "user[name]=bar_user" http://#{proj_admin.login}:#{MINGLE_TEST_DEFAULT_PASSWORD}@localhost:#{MINGLE_PORT}/api/v2/users/#{@team_member.id}.xml]
    assert_response_code(403, output2)
  end

end
