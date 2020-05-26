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

class SystemUser

  def self.ensure_exists
    if MingleConfiguration.system_user.present? && User.find_by_login(MingleConfiguration.system_user).nil?
      Rails.logger.info "Creating system user: #{MingleConfiguration.system_user}"
      User.create_or_update_system_user(MingleConfiguration.system_user_attributes)
    end
  end

end
