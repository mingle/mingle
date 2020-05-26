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

require File.join(File.dirname(__FILE__), 'test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../messaging/messaging_test_helper')

# Tags: multitenancy, install
class TenantsControllerTest < ActionController::TestCase
  include MessagingTestHelper
  def setup
    Multitenancy.delete_schemas_with_prefix('min\\_')
    Multitenancy.clear_tenants
    Clock.fake_now("2012-01-01")
    @controller = TenantsController.new
  end

  def teardown
    Multitenancy.delete_schemas_with_prefix('min\\_')
    Multitenancy.clear_tenants
    Clock.reset_fake
  end

  def test_get_tenants
    ActiveRecord::Base.clear_active_connections!
    get(:index)
    assert_response :ok
    ActiveRecord::Base.clear_active_connections!
  end

  def test_create_tenant_should_create_tenant_tables_in_given_schema
    msg_params = {:name => "site1"}.merge(:setup_params => valid_site_setup_params)
    post(:create, msg_params)

    assert_response :ok

    TenantCreationProcessor.run_once

    assert Multitenancy.tenant_exists?("site1")
    Multitenancy.without_tenant do
      conn = ActiveRecord::Base.connection
      value = conn.select_value("SELECT COUNT(*) FROM #{schema_name('site1')}.schema_migrations")
      assert value.to_i > 0

      if conn.database_vendor == :oracle
        # connection user is different with schema name
        # should not create anything in connection user schema
        username = Multitenancy.connection_username
        value = conn.select_value("SELECT COUNT(*) FROM all_tables WHERE owner = '#{username}'")
        assert_equal 0, value.to_i, "For Oracle, should not create tables owned by the schema's owner"
      end
    end
  end

  def test_destroy_tenant_should_only_destroy_tenant_tables_in_given_schema
    msg_params = {:name => "site1"}.merge(:setup_params => valid_site_setup_params)
    post(:create, msg_params)

    assert_response :ok

    TenantCreationProcessor.run_once
    assert Multitenancy.tenant_exists?("site1")

    msg_params = {:name => "site1"}
    post(:destroy, msg_params)

    assert_response :ok

    TenantDestructionProcessor.run_once
    assert !Multitenancy.tenant_exists?("site1")
  end

  def test_should_create_tenant_when_recreate_a_tenant_that_failed_once_before
    params = valid_site_setup_params.dup
    params[:license] = {:key => 'foo', :licensed_to => 'bar'}
    post(:create, {:name => "site1"}.merge(:setup_params => params))

    TenantCreationProcessor.run_once

    assert !Multitenancy.tenant_exists?("site1")

    post(:create, {:name => "site1"}.merge(:setup_params => valid_site_setup_params))

    TenantCreationProcessor.run_once

    assert Multitenancy.tenant_exists?('site1')
    assert Multitenancy.schema(nil, schema_name('site1')).exists?
  end

  def test_should_raise_error_if_license_key_is_invalid
    params = valid_site_setup_params
    params[:license] = {:key => 'foo', :licensed_to => 'bar'}
    create_tenant("site123", params) do |schema|
      # assert @response.body =~ /license is invalid/
      assert !Multitenancy.tenant_exists?("site123")
      assert !Multitenancy.schema(nil, 'site123').exists?
    end
  end

  def test_should_raise_error_if_first_admin_setup_is_invalid
    params = valid_site_setup_params
    params[:first_admin][:email] = "email@"
    create_tenant("site123", params) do |schema|
      # assert @response.body =~ /Email is invalid/
      assert !Multitenancy.tenant_exists?("site123")
      assert !Multitenancy.schema(nil, 'site123').exists?
    end
  end

  def test_create_tenant_with_setup_params_will_setup_every_thing_for_tenant
    create_tenant("site123", valid_site_setup_params) do |schema|

      Multitenancy.activate_tenant("site123") do
        assert !Database.need_migration?
        assert License.eula_accepted?
        assert_not_nil CurrentLicense.license_key
        assert_equal 'email', User.first_admin.login
        assert_equal 'Admin User', User.first_admin.name
      end

      assert Multitenancy.tenant_exists?("site123")
    end
  end


  def test_upgrade_a_tenant_after_create_it
    create_tenant("site123", valid_site_setup_params) do |schema|
      assert_response :ok
      post :upgrade, :name => "site123", :force => 'true'
      assert_response :ok
    end
  end

  def test_destroy_tenant
    post(:create, :name => 'site1', :setup_params => valid_site_setup_params)
    TenantCreationProcessor.run_once
    tenant_schema = schema_name('site1')
    assert Multitenancy.schema(nil, tenant_schema).exists?

    post(:destroy, :name => 'site1')
    TenantDestructionProcessor.run_once

    assert_response :ok
    assert !Multitenancy.tenant_exists?('site1')
    assert !Multitenancy.schema(nil, tenant_schema).exists?
  end

  def test_should_response_with_conflict_if_create_a_tenant_already_exists
    create_tenant("site1", valid_site_setup_params) do |schema|
      post(:create, :name => 'site1',
           :setup_params => valid_site_setup_params)
      assert_response :conflict
      assert Multitenancy.tenant_exists?('site1')
      assert Multitenancy.schema(nil, schema_name('site1')).exists?
    end
  end

  def test_should_generate_login_from_email
    email = %Q(#{"Admin'User" * 4}not_included_in_login@example.com)
    setup_params = valid_site_setup_params
    setup_params[:first_admin][:email] = email
    create_tenant("site123", setup_params) do |schema_name|
      Multitenancy.activate_tenant("site123") do
        assert_equal 'admin_user' * 4, User.first_admin.login
        assert_equal email, User.first_admin.email
      end
    end
  end

  def test_should_store_lost_password_token_when_creating_admin_if_specified
    setup_params = valid_site_setup_params
    setup_params[:first_admin][:lost_password_ticket] = 'xyz123'
    create_tenant("site123", setup_params) do |schema_name|
      Multitenancy.activate_tenant("site123") do
        assert_equal User.first_admin, LoginAccess.find_by_lost_password_ticket('xyz123').user
        assert User.authenticate('email', 'xyz123' + TenantInstallation::FIRST_ADMIN_SPECIAL_PASSWORD_SUFFIX)
      end
    end
  end

  def test_create_admin_with_password
    setup_params = valid_site_setup_params
    setup_params[:first_admin][:password] = 'xyz123'
    create_tenant("site123", setup_params) do |schema_name|
      Multitenancy.activate_tenant("site123") do
        assert_nil LoginAccess.find_by_lost_password_ticket('xyz123')
        assert User.authenticate('email', 'xyz123')
      end
    end
  end

  def test_create_your_first_project_by_given_spec_name
    setup_params = valid_site_setup_params
    setup_params[:first_project_spec_name] = 'simple_project_for_post.yml'
    create_tenant("site123", setup_params) do |schema_name|
      Multitenancy.activate_tenant("site123") do
        proj = Project.all.first
        proj.with_active_project do |proj|
          assert_equal 'Card', proj.card_types.first.name
        end
      end
    end
  end

  def test_create_tenants_by_a_new_valid_db_connection_pool
    swap_current_db_as_new_partition do
      create_tenant("site123", valid_site_setup_params) do |schema_name|
        Multitenancy.activate_tenant("site123") do
          assert !Database.need_migration?
          assert License.eula_accepted?
          assert_not_nil CurrentLicense.license_key
          assert_equal 'email', User.first_admin.login
          assert_equal 'Admin User', User.first_admin.name
        end

        assert Multitenancy.tenant_exists?("site123")
      end
    end

  end

  def valid_site_setup_params
    {
      :first_admin => {
        :name => "Admin User",
        :email => "email@exmaple.com"
      },
      :license => valid_license
    }
  end

  private

  def schema_name(tenant_name)
    tenant = Multitenancy.find_tenant(tenant_name)
    tenant.schema_name unless tenant.nil?
  end

  def create_tenant(tenant_name, setup_params, &block)
    schema_name = tenant_name
    post(:create, :name => tenant_name,
         :setup_params => setup_params)

    assert_response :success

    TenantCreationProcessor.run_once
    tenant_schema = schema_name(tenant_name)
    yield(tenant_schema)
  ensure
    post(:destroy, :name => tenant_name)
  end

end
