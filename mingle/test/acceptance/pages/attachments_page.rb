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

module AttachmentsPage
  
  def assert_remove_attachment_present
    @browser.assert_element_present(css_locator(".dz-remove"))
  end

  def assert_remove_attachment_not_present
    @browser.assert_element_not_present(css_locator(".dz-remove"))
  end
  
  def assert_attachment_present(attachment_name)
    @browser.assert_element_present(css_locator(".dz-preview span:contains(#{attachment_name})"))
  end
  
  def assert_attachment_not_present(attachment_name)
    @browser.assert_element_not_present(css_locator(".dz-preview span:contains(#{attachment_name})"))
  end
end
