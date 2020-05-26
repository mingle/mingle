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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

module Aws
  class CredentialsTest < ActiveSupport::TestCase

    def stub_env(new_env, &block)
      original_env = Rails.env
      Rails.instance_variable_set('@_env', ActiveSupport::StringInquirer.new(new_env))
      block.call
    ensure
      Rails.instance_variable_set('@_env', ActiveSupport::StringInquirer.new(original_env))
    end

    def test_should_pick_credentials_from_environment_in_development_and_test_environments
      access_key_id = 'test_access_key_id'
      secret_access_key = 'test_secret_access_key'
      ENV['AWS_ACCESS_KEY_ID'] = access_key_id
      ENV['AWS_SECRET_ACCESS_KEY'] = secret_access_key

      %W(development test). each do |env|
        stub_env(env) do
          creds = Credentials.new

          assert_equal access_key_id, creds.access_key_id
          assert_equal secret_access_key, creds.secret_access_key
          assert_nil creds.session_token
        end
      end
    end
  end
end
