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

class CurrentLicense

  LICENSE_STATUS_THREADLOCAL_KEY = "license_status"
  LICENSE_STATUS_MEMCACHE_KEY = "license_status"
  LICENSE_STATUS_CACHE_TIMEOUT = 30.minutes

  class << self
    def registration
      ThreadLocalCache.get(:current_license_registration) do
        if FEATURES.active?('db_licensing')
          create_registration_from_license_key(license_key)
        else
          license_from_profile_server
        end
      end
    end

    def while_the_license_is_in_violation
      "While the license is in violation:<ul><li>No new users or new projects can be created</li><li>All users will be set as light users</li><li>Any anonymous access enabled projects will be inaccessible</li></ul>"
    end

    def please_obtain_a_valid_licence_from_support_page
      "Please contact your Thoughtworks Studios account executive or email <a href='mailto:studios@thoughtworks.com'>studios@thoughtworks.com</a>."
    end

    def refresh_status
      clear_cached_registration!
      registration.validate
    end

    def trial?
      status.trial?
    end

    def status
      ThreadLocalCache.get(LICENSE_STATUS_THREADLOCAL_KEY) do
        Cache.get(LICENSE_STATUS_MEMCACHE_KEY, LICENSE_STATUS_CACHE_TIMEOUT) do
          refresh_status
        end
      end
    end

    def clear_cache
      clear_cached_license_status!
      clear_cached_registration!
    end

    def clear_cached_license_status!
      ThreadLocalCache.clear(LICENSE_STATUS_THREADLOCAL_KEY)
      Cache.delete(LICENSE_STATUS_MEMCACHE_KEY)
    end

    def license_key
      return unless FEATURES.active?('db_licensing')
      License.get.license_key
    end

    def register!(license_key, licensed_to)
      clear_cached_license_status!
      license_key = license_key.strip
      reg = create_registration_from_license_key(license_key)
      status = reg.validate_with_licensee(licensed_to)
      if status.valid?
        License.get.update_attributes(:license_key => license_key)
        sync_license_with_profile_server(reg)
      end
      clear_cached_registration!
      status
    end

    def update!(org)
      if ProfileServer.configured?
        ProfileServer.update_organization(org)
      else
        Rails.logger.error {"No profile server configured, ignore update"}
      end
      clear_cache
    end

    def blank?
      license_key.blank?
    end

    def clear_cached_registration!
      ThreadLocalCache.clear(:current_license_registration)
    end

    def temp_registration
      date = Clock.now + 2.month
      Registration.new('expiration_date' => date.strftime("%F"),
                       'allow_anonymous' => false,
                       'product_edition' => Registration::NON_ENTERPRISE,
                       'max_active_users' => 1000000,
                       'max_light_users' => 1000000,
                       'trial' => false,
                       'paid' => true,
                       'licensee' => nil)
    end

    def downgrade?
      MingleConfiguration.new_buy_process? && status.invalid? && !status.paid?
    end

    def downgrade
      User.transaction do
        update!('subscription_expires_on' => (Clock.now + 10.years).strftime("%F"),
                'max_active_full_users' => 5,
                'product_edition' => Registration::NON_ENTERPRISE)

        users = User.find(:all, :conditions => User.activated_full_users_conditions, :include => [:login_access])
        users = users.sort_by do |u|
          u.login_access.last_login_at || 100.years.ago
        end.reverse

        if users.count > 5
          keep = [User.current]
          users.each do |user|
            next if user == User.current
            if keep.size < 5
              keep << user
            elsif !keep.any?(&:admin?)
              keep[4] = user
            end
          end
          User.update_all({:activated => false}, "id not in (#{keep.map(&:id).join(",")})")
          ProfileServer.deactivate_users(:except => keep.map(&:login))
        end
      end
      clear_cache
    end

    private

    def sync_license_with_profile_server(reg)
      return unless ProfileServer.configured?
      license_data = {
        'allow_anonymous' => reg.allow_anonymous?,
        'subscription_expires_on' => reg.expiration_date,
        'product_edition' => reg.edition,
        'max_active_full_users' => reg.max_active_full_users,
        'max_active_light_users' => reg.max_active_light_users
      }
      ProfileServer.update_organization(license_data)
    end

    def license_from_profile_server
      license_details = ProfileServer.license_details
      Registration.new('expiration_date' => license_details['subscription_expires_on'],
                       'allow_anonymous' => license_details['allow_anonymous'].to_s,
                       'product_edition' => license_details['product_edition'],
                       'max_active_users' => license_details['max_active_full_users'],
                       'max_light_users' => license_details['max_active_light_users'],
                       'licensee' => nil,
                       'trial' => license_details['trial?'],
                       'paid' => license_details['paid?'],
                       'buying' => license_details['buying?'],
                       'company_name' => license_details['lead_company'])
    rescue => e
      Kernel.log_error(e, "fetch license from profile server failed", :force_full_trace => true)
      temp_registration
    end

    def create_registration_from_license_key(key)
      return InvalidRegistration.new("This instance of Mingle is unlicensed. #{while_the_license_is_in_violation}#{please_obtain_a_valid_licence_from_support_page}.") if key.blank?

      Registration.new(LicenseDecrypt.new.do_decrypt(key))
    rescue => e
      Kernel.log_error(e, "create registration failed from license key #{key.inspect}", :force_full_trace => true)
      InvalidRegistration.new("The license data is invalid")
    end


  end
end
