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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/messaging_test_helper')

# Tags: messaging
class TenantsControllerMessagingTest < ActionController::TestCase
  include MessagingTestHelper

  def setup
    @controller = TenantsController.new
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end

  def teardown
    super
    Multitenancy.clear_tenants
  end

  def test_create_should_publish_a_message
    route(:from => TenantCreationProcessor::QUEUE, :to => TEST_QUEUE)
    MingleConfiguration.with_multitenancy_migrator_overridden_to(true) do
      message_params = {:name => "site1"}.merge(:setup_params => valid_site_setup_params)
      post(:create, message_params.dup)
      assert_response :success
      assert_message_in_queue message_params
    end
  end

  private

  def valid_license
    {"key" => <<-KEY, "licensed_to" => "ThoughtWorks Inc."}
NhsCbWb5BLSybiIBpWNM38jbYOchxr+opf53mj7vMlyAunTNZoUyV88CRF3P
VJ+WJ79x17Di7YG22zSXecXNjBNo4A+0vxB5ytUzBiqfj6DSpHS1KOlJyDD1
e7xQpU8OwwzMYXzP7hVdDMk9jMYi/nQfb8WGdfSl6K905tfxKqP+MomUyoE0
FC+jTKr0ncnKilaRv4alOj5bBucTxqLKiJm4HTOOt9+KSpDonTzF+R7oLCgf
6CXLOn594Bfk9ASwEyeTaargIpSyjrI15g0vz5ZgObCdS+ykghfTeiU7bPEr
36m1xd6PXT5kzbIWGVovLcCIeD6VfgEaU1cssATQ4A==
KEY
  end

  def valid_site_setup_params
    {
      "first_admin" => {
        "login" => "admin",
        "name" => "Admin User",
        "email" => "email@example.com"
      },
      "license" => valid_license
    }
  end

  def current_db_tenant_config
    ActiveRecord::Base.configurations['test'].inject({}) do |memo, pair|
      key, value = pair
      memo["database_#{key}"] = value
      memo
    end
  end
end
