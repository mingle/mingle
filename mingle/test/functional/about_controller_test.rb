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

class AboutControllerTest < ActionController::TestCase

  def setup
    @controller = create_controller(AboutController)
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_member
  end

  def test_index_renders
    get :index
    assert_select 'h1', :text => 'About'
  end

  def test_should_not_show_any_tabs_when_showing_about_page
    get :index
    assert_select 'a#tab_all_link', false
  end

  def test_should_render_third_party_licenses
    get :thirdparty

    assert_select 'h1', :text => 'List of all awesome third party software used by Mingle'
    assert_select 'table.thirdparty th', 4
    assert_select 'table.thirdparty tbody tr', 162
  end

end
