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

class SidebarTest < ActiveSupport::TestCase

  def setup
    @member = User.find_by_login('member')
    UserDisplayPreference.destroy_all
    @member.display_preference.save!
    @member.reload
  end

  def test_always_show_should_delegate_to_controller
    assert Sidebar.new(controller_that_always_shows_sidebar, @member, nil).always_show?
    assert !Sidebar.new(controller_that_does_not_always_show_sidebar, @member, nil).always_show?
  end

  def test_hidden_should_be_based_on_user_preference
    @member.display_preference.update_preference(:sidebar_visible, true)
    sidebar = Sidebar.new(controller_that_does_not_always_show_sidebar, @member, Object.new, nil)
    assert !sidebar.hidden?
    assert sidebar.visible?

    @member.display_preference.update_preference(:sidebar_visible, false)
    sidebar = Sidebar.new(controller_that_does_not_always_show_sidebar, @member, Object.new, nil)
    assert sidebar.hidden?
    assert !sidebar.visible?
  end

  def test_always_show_for_returns_false
    @member.display_preference.update_preference(:sidebar_visible, true)
    sidebar = Sidebar.new(controller_that_does_not_always_show_sidebar, @member, Object.new, false)
    assert !sidebar.always_show?
  end

  def test_exist_obeys_panel_existance
    assert !Sidebar.new(controller_that_does_not_always_show_sidebar, @member, nil, false).exist?
    assert Sidebar.new(controller_that_does_not_always_show_sidebar, @member, Object.new, false).exist?
  end

  def test_exist_obeys_force_exist
    assert !Sidebar.new(controller_that_does_not_always_show_sidebar, @member, nil, false).exist?
    assert Sidebar.new(controller_that_does_not_always_show_sidebar, @member, nil, true).exist?
  end

  private

  def controller(always_show_sidebar)
    OpenStruct.new(:always_show_sidebar? => always_show_sidebar)
  end

  def controller_that_always_shows_sidebar
    controller(true)
  end

  def controller_that_does_not_always_show_sidebar
    controller(false)
  end
end
