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

LicenseDecrypt

module LicenseDecryptExt
  def do_decrypt(license_key)
    if self.class.license_decryption_enabled
      super(license_key)
    else
      if license_key.blank? || license_key.index('&') == nil
        raise LicenseDecryptException.new('license key is invalid')
      else
        Rack::Utils.parse_nested_query(license_key)
      end
    end
  end
end

module LicenseDecryptTestClassMethods
  def enable_license_decrypt
    self.license_decryption_enabled = true
  end

  def disable_license_decrypt
    self.license_decryption_enabled = false
  end

  def reset_license
    CurrentLicense.register!(license_key, licensed_to)
  end

  def license_key
    {:licensee => licensed_to, :max_active_users => '1000' ,:max_light_users => '1000', :expiration_date => '2020-12-30'}.to_query
  end

  def licensed_to
    'ThoughtWorks Studios Mingle Test'
  end

  private

  mattr_accessor :license_decryption_enabled
end

LicenseDecrypt.class_eval do
  extend LicenseDecryptTestClassMethods
  prepend LicenseDecryptExt
end
