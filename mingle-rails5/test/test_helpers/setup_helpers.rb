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

module SetupHelper
  def clear_license
    License.get.update_attribute(:license_key, nil)
    CurrentLicense.clear_cached_license_status!
    CurrentLicense.clear_cached_registration!
  end

  def register_license(options={})
    CurrentLicense.register!(license_key_for_test(options), licensed_to_for_test(options[:licensee]))
  rescue => e
    Rails.logger.error("Problem setting license for test: #{e.inspect}")
    Rails.logger.error(e.backtrace)
  end
  alias :reset_license :register_license

  def license_key_for_test(options={})
    {:max_active_users => '1000' ,:max_light_users => '1000', :expiration_date => '2020-12-30', :allow_anonymous => false, :product_edition => Registration::ENTERPRISE, :licensee => licensed_to_for_test(options[:licensee]) }.merge(options).to_query
  end

  def licensed_to_for_test(licensee=nil)
    licensee || 'ThoughtWorks Studios Mingle Test'
  end

  extend self
end
