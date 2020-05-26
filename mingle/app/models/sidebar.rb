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

class Sidebar

  attr_reader :panel

  def initialize(controller, user, panel, force_exist = false)
    @panel = panel
    @force_exist = force_exist
    @controller = controller
    @user = user
  end

  def visible?
    always_show? || user_display_preference.read_preference(:sidebar_visible)
  end

  def hidden?
    !always_show? && !user_display_preference.read_preference(:sidebar_visible)
  end

  def exist?
    !@panel.nil? || @force_exist
  end

  def always_show?
    @controller.always_show_sidebar?
  end

  private

  def user_display_preference
    @user.display_preference(@controller.session)
  end
end
