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

# Tags: api_version_2, anonymous
class ApiAnonymousAccessVersion2Test < ActiveSupport::TestCase
  fixtures :users, :login_access
  def setup
    enable_basic_auth
    destroy_all_records(:destroy_users => true, :destroy_projects => true)
    change_license_to_allow_anonymous_access
    user = create_user!(:name => 'black_ops')
    @project = create_project :prefix => "api_anon_access_test", :anonymous_accessible => true
    @project.add_member(user)
    @version = "v2"
  end

  def teardown
    disable_basic_auth
  end

  def test_anonymous_user_can_get_a_list_of_anonymous_accessible_projects
    proj2 = create_project :prefix => "api_anon_acc_proj2"
    API::Project.site = "http://localhost:#{MINGLE_PORT}/api/#{@version}"
    API::Project.prefix = "/api/#{@version}/"
    assert API::Project.find(:all).collect(&:identifier).include? @project.identifier
  end

  def test_anonymous_user_can_get_card_from_anonymous_accessible_project
    by_first_admin_within(@project) { create_card!(:name => 'card1') }
    API::Card.site = "http://localhost:#{MINGLE_PORT}/api/#{@version}/projects/#{@project.identifier}"
    API::Card.prefix = "/api/#{@version}/projects/#{@project.identifier}/"
    API::Project.prefix = "/api/#{@version}/projects/#{@project.identifier}/"
    API::Project.site = "http://localhost:#{MINGLE_PORT}/api/#{@version}/projects/#{@project.identifier}"
    API::CardType.site = "http://localhost:#{MINGLE_PORT}/api/#{@version}/projects/#{@project.identifier}"
    API::CardType.prefix = "/api/#{@version}/projects/#{@project.identifier}/"
    assert_equal ['card1'], API::Card.find(:all).collect(&:name)
    by_first_admin_within(@project) { @project.update_attribute(:anonymous_accessible, false) }
    assert_unauthorized { API::Card.find(:all) }
  end

  def test_anonymous_user_can_not_do_write_operation_on_anonymous_accessible_project
    assert_equal "403", post("http://localhost:#{MINGLE_PORT}/api/#{@version}/projects/#{@project.identifier}/cards/new.xml", {}).code
  end

  def test_anonymous_user_cannot_post_to_github_action
    assert_equal "406", post_json("http://localhost:#{MINGLE_PORT}/api/#{@version}/projects/#{@project.identifier}/github.json", {"commits" => [{"author" => {"name" => "a"}}]}).code
  end
end
