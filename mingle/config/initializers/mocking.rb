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

# this need to be an intializer because on acceptance tests model hacking should be loaded
# both on the server runtime and test runtime
# This should not be packaged with the installer

if Rails.env.test? || java.lang.System.getenv('TEST_DUAL_APP')
  require  File.join(Rails.root, 'test', 'mocks', "license_decrypt")
  require  File.join(Rails.root, 'test', 'mocks', "project")
  require  File.join(Rails.root, 'test', 'mocks', "clock")
  require  File.join(Rails.root, 'test', 'mocks', "constant_resetter")
  require  File.join(Rails.root, 'test', 'mocks', 'test', "plugin_schema_info")
  require  File.join(Rails.root, 'test', 'test_helpers', 'setup_helper')

  MingleConfiguration
  class MingleConfiguration

    def self.override(params)
      params.symbolize_keys!
      property = params[:name]
      value = params[:value]

      MingleConfiguration.send(:"#{property}=", value)
      "SUCCESS: MingleConfiguration.#{property} = #{self.send(property.to_sym).inspect}"
    end

  end

  module Constant

    def self.set(options)
      options.symbolize_keys!
      host = options[:host] || Object
      host = host.constantize if host.is_a? String

      const = options[:const]
      value = options[:value]

      silence_warnings { host.const_set(const, value) }
    end
  end

  Constant.set('const' => "AUTH_CONFIG_YML", 'value' => File.join(Rails.root, "test", 'data', 'test_config', 'test_auth_config.yml'))
  Constant.set('const' => "ELASTIC_SEARCH_CONFIG_YML", 'value' => File.join(Rails.root, "test", 'data', 'test_config', 'test_elastic_search_config.yml'))
  Constant.set('const' => "SMTP_CONFIG_YML", 'value' => File.join(Rails.root, 'test', 'data', 'test_config', 'test_smtp_config.yml'))
  Constant.set('const' => "SITE_URL_CONFIG_FILE", 'value' => File.join(Rails.root, 'test', 'data', 'test_config', 'test_mingle.properties'))

  Rails.env.class_eval do
    def acceptance_test?
      if RUBY_PLATFORM =~ /java/
        java.lang.System.get_property('MINGLE') == 'acceptance_test'
      else
        ENV['MINGLE'] == 'acceptance_test'
      end
    end
  end

  if Rails.env.acceptance_test?
    module ActionMailer
      class Base
        def perform_delivery_file(mail)
          FileUtils.mkdir_p('tmp/mails')
          File.open("tmp/mails/last", 'w+') do |f|
            f << mail.encoded
          end
        end
      end
    end

    ActionMailer::Base.delivery_method = :file
  end

  if Rails.env.acceptance_test?
    UserDisplayPreference::DEFAULT_VALUES.merge!(:sidebar_visible => true, :grid_settings => true)
  end

end
