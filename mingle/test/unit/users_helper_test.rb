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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')


class UsersHelperTest < ActionController::TestCase
  include UsersHelper
  
  def setup
    @member = login_as_member
    @project = first_project
    @project.activate
  end
  
  def test_revoke_url_should_point_to_normal_revoke_if_user_is_normal_member
    client1 = Oauth2::Provider::OauthClient.create!(:name => 'some application', :redirect_uri => 'http://app1.com/bar')
    token1 = client1.create_token_for_user_id(@member.id)
    login_as_member
    assert_equal 'revoke', token_revoke_url_options(token1)[:action]
  end
  
  
  def test_revoke_url_should_point_to_admin_revoke_if_user_is_mingle_admin
    client1 = Oauth2::Provider::OauthClient.create!(:name => 'some application', :redirect_uri => 'http://app1.com/bar')
    token1 = client1.create_token_for_user_id(@member.id)
    login_as_admin
    assert_equal 'revoke_by_admin', token_revoke_url_options(token1)[:action]
  end
  
  def test_light_user_has_tooltip
    light = create_user!
    light.update_attribute(:light, true)
    assert /title/.match(add_title_if_is_light_user(light))
    assert_nil add_title_if_is_light_user(@member)
  end
  
  def url_for(*args)
    nil
  end
end
