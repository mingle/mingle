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

class LoginAccess < ActiveRecord::Base
  belongs_to :user

  alias_attribute :lost_password_ticket, :lost_password_key

  class << self
    def find_by_lost_password_ticket(ticket)
      find :first, :conditions => ["lost_password_key = ? AND lost_password_reported_at > ?", ticket, (Clock.now - 1.hour)]
    end

    def find_user_by_login_token(token)
      return unless find_by_login_token(token)
      find_by_login_token(token).user
    end
  end

  def assign_lost_password_ticket(ticket, options={})
    options.reverse_merge!(:expires_in => 1.hour)
    reported_at = Clock.now + options[:expires_in] - 1.hour
    update_attributes(:lost_password_key => ticket, :lost_password_reported_at => reported_at)
  end

  def generate_lost_password_ticket!(options={})
    assign_lost_password_ticket(SecureRandomHelper.random_32_char_hex, options)
    lost_password_key
  end

end
