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

class PermissionsDropdown
  READ_ONLY      = "Read only team member"
  FULL           = "Team member"
  PROJECT_ADMIN  = "Project administrator"
  
  def initialize(user, browser)
    @user = user
    @browser = browser
  end

  def readonly?
    value = READ_ONLY
  end

  def full_member?
    value =FULL
  end

  def project_admin?
    value =PROJECT_ADMIN
  end

  def modifications_enabled?
    @browser.is_element_present(droplink)
  end

  def set_project_admin
    select_option(PROJECT_ADMIN)
  end

  def set_full_member
    select_option(FULL)
  end

  def set_read_only_member
    select_option(READ_ONLY)
  end

  private
  def value
    modifications_enabled? ? @browser.get_text(droplink) : @browser.eval_javascript("$('permission-container-for-#{@user.html_id}').innerHTML").strip
  end

  def select_option(permission)
    raise 'Unknown option' unless permission == READ_ONLY || permission == FULL || permission == PROJECT_ADMIN
    @browser.with_ajax_wait do
      @browser.click(droplink)
      @browser.wait_for_element_visible(dropdown)
      @browser.click_and_wait(option(permission))
    end
  end

  def droplink
    "#{prefix}_drop_link"
  end
  
  def dropdown
    "#{prefix}_drop_down"
  end
  
  def option(name)
    "#{prefix}_option_#{name}"
  end
  
  def prefix
    "select_permission_#{@user.html_id}"
  end
end
