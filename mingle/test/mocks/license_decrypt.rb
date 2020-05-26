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

#make sure load license_decrypt.rb first
LicenseDecrypt
class LicenseDecrypt
  @@do_decrypt_switch_on = false

  def self.enable_license_decrypt
    @@do_decrypt_switch_on = true
  end

  def self.disable_license_decrypt
    @@do_decrypt_switch_on = false
  end

  def self.reset_license
    CurrentLicense.register!(license_key, licensed_to)
  end

  def self.license_key
    {:licensee => licensed_to, :max_active_users => '1000' ,:max_light_users => '1000', :expiration_date => '2020-12-30'}.to_query
  end

  def self.licensed_to
    "ThoughtWorksstudio mingle test"
  end

  def do_decrypt_with_switch(license_key)
    if @@do_decrypt_switch_on
      do_decrypt_without_switch(license_key)
    else
      if(license_key.blank? || license_key.index('&') == nil)
        raise LicenseDecryptException.new('license key is invalid')
      else
        ActionController::Request.parse_query_parameters(license_key)
      end
    end
  end

  safe_alias_method_chain :do_decrypt, :switch
end
