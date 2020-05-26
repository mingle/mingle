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

require File.expand_path(File.dirname(__FILE__) + '/../../../acceptance/acceptance_test_helper')

# Tags: story, #530, user, navigation
class Story530InitialAdminUserSetupTest < ActiveSupport::TestCase

  def setup
    @browser = selenium_session
    logout
    destroy_all_records(:destroy_users => true, :destroy_projects => true)
  end

  def test_should_show_user_signup_page_when_first_user_on_board
    @browser.open('/')
    @browser.click_and_wait 'next'
    @browser.assert_location '/install/signup'
    complete_new_user_fields 'mr.big@theworld.com', '1 g.nna n.t t3ll y.u'
    @browser.click_and_wait "name=commit"
    @browser.open('/')
    @browser.click_and_wait profile_for_user_name_link('mr.big@theworld.com')
    @browser.assert_text_present 'mr.big@theworld.com is an administrator'

    logout

    @browser.open('/')
    @browser.assert_location '/profile/login'
  end

end
