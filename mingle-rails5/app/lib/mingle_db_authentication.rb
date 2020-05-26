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

class MingleDBAuthentication
  def authenticate?(params,request_url)
    login = params[:user][:login].strip
    password = params[:user][:password].strip

    unless User.find_by_login(login.downcase)
      u = User.find_by_email(login)
      login = u.login if u.present?
    end
    User.authenticate(login, password)
  end

  def supports_password_recovery?
    true
  end

  def supports_password_change?
    true
  end

  def supports_password_change?
    true
  end

  def supports_login_update?
    true
  end

  def supports_basic_authentication?
    true
  end

  def is_external_authenticator?
    false
  end

  def using_external_authenticator?
    false
  end

  def label
    "mingle"
  end

  def configure(settings)
  end

end

MinglePlugins::Authenticators.register(MingleDBAuthentication.new)
