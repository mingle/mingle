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

module RegisterMingleAction

    def navigate_to_register_mingle_page
        @browser.open('/license/show')
    end

    def register_license_that_allows_anonymous_users
        as_admin do
            set_new_license_for_project(SetupHelper.license_key_for_test(:allow_anonymous => true), SetupHelper.licensed_to_for_test)
        end
    end

    def register_expired_license_that_allows_anonymous_users
        as_admin do
            set_new_license_for_project(SetupHelper.license_key_for_test(:expiration_date => '1999-01-01', :allow_anonymous => true), SetupHelper.licensed_to_for_test)
            @browser.assert_visible(RegisterMinglePageId::NOTICE_ID)
            @browser.assert_visible(RegisterMinglePageId::INFO_ID)
        end
    end

    def register_limited_license_that_allows_anonymous_users(max_active_users, max_light_users)
        as_admin do
            set_new_license_for_project(SetupHelper.license_key_for_test(:max_active_users => max_active_users, :max_light_users => max_light_users, :allow_anonymous => true), SetupHelper.licensed_to_for_test)
        end
    end

    def register_default_license
        as_admin do
            set_new_license_for_project(SetupHelper.license_key_for_test, SetupHelper.licensed_to_for_test)
        end
    end

    def license_is_violation
      login_as_admin_user
      @browser.enable_license_decrypt
      set_new_license_for_project(RegisterMinglePageId::EXPIRED_LICENSE_KEY, RegisterMinglePageId::LICENSED_TO)
     ensure
      on_after do
        @browser.disable_license_decrypt
        reset_license
      end
    end

    def enable_anonymous_access_for_project(project)
      register_license_that_allows_anonymous_users
      login_as_admin_user
      navigate_to_project_admin_for(project)
      enable_project_anonymous_accessible_on_project_admin_page
      logout
    end

    def license_is_available
      login_as_admin_user
      @browser.enable_license_decrypt
      set_new_license_for_project(RegisterMinglePageId::VALID_LICENSE_KEY, RegisterMinglePageId::LICENSED_TO)
     ensure
      on_after do
        @browser.disable_license_decrypt
        reset_license
      end
    end

    def set_new_license_for_project(license_key, licensed_to)
        navigate_to_register_mingle_page
        input_license_key(license_key)
        input_licensed_to(licensed_to)
        click_register_button
    end

    def input_license_key(license_key)
        @browser.type(RegisterMinglePageId::LICENSE_KEY_ID, license_key)
    end

    def input_licensed_to(licensed_to)
        @browser.type(RegisterMinglePageId::LICENSED_TO_ID, licensed_to)
    end

    def click_register_button
        @browser.click_and_wait(RegisterMinglePageId::REGISTER_LINK)
    end

    def click_done
        @browser.click_and_wait(RegisterMinglePageId::DONE_LINK_ID)
    end

    def click_on_mingle_logo
        @browser.click_and_wait(RegisterMinglePageId::MINGLE_LOGO_ID)
    end
end
