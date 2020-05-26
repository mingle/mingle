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

module RegisterMinglePage

  def assert_licence_registered_details
    @browser.assert_text_present(RegisterMinglePageId::LICENSED_TO)
    @browser.assert_text_present(RegisterMinglePageId::LICENSE_TYPE)
    @browser.assert_text_present('2021-06-02')
    @browser.assert_text_present('10000')
  end

  def assert_successful_registration_message
    assert_notice_message('License was registered successfully')
  end

  def assert_invalid_license_error_message
    assert_error_message('License data is invalid')
  end

  def assert_unlicensed_mingle_error_message
    assert_info_message("This instance of Mingle is unlicensed.", :ignore_space => true)
  end

  def assert_license_expired_message
    thoughtworks_support = "ThoughtWorks Studios"
    assert_info_message("This instance of Mingle is in violation of the registered license. The license for this instance has expired. While the license is in violation:No new users or new projects can be createdAll users will be set as light usersAny anonymous access enabled projects will be inaccessible Please get in touch with us at studios@thoughtworks.com.", :ignore_space => true)
  end

  def assert_license_violations_message_caused_by_too_many_users(max_active, current_active, caused_by_full_user = true)
    thoughtworks_support = "ThoughtWorks Studios"
    if caused_by_full_user == true
      max_active_full_users = max_active
      current_active_full_users = current_active
      assert_info_message("You've reached the maximum number of users for your site. Please get in touch with us for more at studios@thoughtworks.com.", :ignore_space => true)
    else
      max_active_light_users = max_active
      current_active_light_users = current_active
      assert_error_message("You've reached the maximum number of users for your site. Please get in touch with us for more at studios@thoughtworks.com.", :ignore_space => true)
    end
  end


end
