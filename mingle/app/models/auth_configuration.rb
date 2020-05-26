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

class AuthConfiguration

  LdapSettings = Configuration::Default::new_section("ldap_settings", "ldapserver", "ldapport", "ldapbinduser", "ldapbindpasswd", "ldapbasedn", "ldapfilter", "ldapobjectclass", "ldap_map_fullname", "ldap_map_mail", "ldapgroupobjectclass", "ldapgroupdn", "ldapgroupattribute")
  CasSettings = Configuration::Default::new_section("cas_settings", "cas_port", "cas_host", "cas_uri")
  PasswordSettings = Configuration::Default::new_section("password_format")
  BasicAuthEnabledSettings = Configuration::Default::new_section("basic_authentication_enabled")
  BasicAuthSettings = Configuration::Default::new_section("basic_authentication")
  AuthSettings = Configuration::Default::new_section("authentication")

  class << self
    def create(params, file_name=AUTH_CONFIG_YML)
      FileUtils.mkpath(File.dirname(file_name))
      File.open(file_name, "w+") do |io|
        [PasswordSettings, BasicAuthEnabledSettings, BasicAuthSettings, AuthSettings, LdapSettings, CasSettings].each do |section|
          section.merge_params(params).write_as_yaml_on(io)#can't emit comments - hence using regular file writing.
        end
      end
      load(file_name)
    end

    def settings_for(plugin_label)
      if File.exists?(AUTH_CONFIG_YML)
        if settings = YAML.render_file_and_load(AUTH_CONFIG_YML, binding)
          settings["#{plugin_label}_settings"] || {}
        end
      end
    end

    def load(file_name=AUTH_CONFIG_YML)
      initialized = false
      if File.exists?(file_name)
        settings = YAML.render_file_and_load(file_name, binding)
        ActiveRecord::Base.logger.debug("AuthConfiguration loaded from file #{file_name}")
        if settings
          Authenticator.password_format = settings['password_format']
          Authenticator.authentication = load_authentication(settings['authentication'])
          enable_basic_authentication(settings)
          initialized = true
        end
      else
        ActiveRecord::Base.logger.debug("AuthConfiguration could not load. File #{file_name} does not exist. This could be OK during initial application install.")
      end
      initialized
    end

    def enable_basic_authentication(settings)
      settings = settings.stringify_keys
      if $basic_auth_enabled = (settings['basic_authentication_enabled'] || settings['basic_auth_enabled']).to_s.downcase == 'true'
        BasicAuthenticator.authentication = load_authentication(settings['basic_authentication'])
      end
    end

    private

    def load_authentication(plugin_label)
      unless plugin_label.blank?
        MinglePlugins::Authenticators[plugin_label]
      else
        MingleDBAuthentication.new
      end
    end

  end
end
