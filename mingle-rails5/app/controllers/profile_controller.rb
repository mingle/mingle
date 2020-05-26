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

class ProfileController < ApplicationController
  privileges UserAccess::PrivilegeLevel::REGISTERED_USER => %w(show edit_profile update_profile api_key update_api_key authenticate_in_slack)
  NON_AUTHORIZE_ACTIONS = %w(login logout recover_password forgot_password)

  def login
    @show_copyright = true
    sign_in
  end
  def forgot_password; end
  def show; end
  def logout; end

  def protect?(action)
    return false if NON_AUTHORIZE_ACTIONS.include?(action)
    # Todo: uncomment while migrating profile controller
    # return false if require_valid_ticket
    super(action)
  end
end
