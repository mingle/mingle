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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class MultitenancyTest < ActiveSupport::TestCase

  def self.skip_global_setup
    true
  end

  def setup
    Multitenancy.clear_tenants
    Multitenancy.add_tenant('first', 'database_username' => 'first_schema')
    Multitenancy.add_tenant('second', 'database_username' => 'second_schema')
    ApplicationRecord.connection.create_tenant_schema('first_schema')
    ApplicationRecord.connection.create_tenant_schema('second_schema')
  end

  def teardown
    Multitenancy.clear_tenants
    Multitenancy::CONNECTION_MANAGER.unstub(:current_or_default_connection)
    ApplicationRecord.connection.drop_tenant_schema('first_schema')
    ApplicationRecord.connection.drop_tenant_schema('second_schema')
  end

  def test_activate_tenant_with_correct_connection_pool
    default_connection = ActiveRecord::Base.connection
    new_db_url = 'new db url'
    Multitenancy.add_tenant('tenantx', 'database_username' => 'second_schema', 'db_config' => {:url => new_db_url})
    block_called = false
    Multitenancy::CONNECTION_MANAGER.expects(:with_connection).once.with do |conn_name, db_name|
      assert_equal(new_db_url, conn_name)
      assert_nil(db_name)
    end.yields

    Multitenancy.expects(:switch_schema).with(anything,'SECOND_SCHEMA')
    Multitenancy.activate_tenant('tenantx') do
      block_called = true
    end

    assert(block_called)
    assert_equal new_db_url, Multitenancy::CONNECTION_MANAGER.find_connection_pool(new_db_url).spec.config[:url]

    Multitenancy::CONNECTION_MANAGER.expects(:current_or_default_connection).returns(default_connection)
    ApplicationRecord.connection
  ensure
    Multitenancy::CONNECTION_MANAGER.remove(new_db_url)
  end

  def test_active_none_existing_tenant_should_raise_tenant_not_found_error
    assert_raises(Multitenancy::TenantNotFoundError) do
      Multitenancy.activate_tenant('not-exists') {}
    end
  end


  def test_should_upcase_schema_name
    Multitenancy.activate_tenant('first') do
      assert_equal 'FIRST_SCHEMA', Multitenancy.active_tenant.schema_name
    end
  end

  def test_activate_tenants_should_activate_each_tenant_and_execute_the_block_on_each_tenant
    names = []
    Multitenancy.activate_each { names << MingleConfiguration.app_namespace }
    assert_equal 2, names.size
    assert_equal %w(first second), names.sort
  end

  def test_setup_block_get_called_on_add_tenant_if_called
    call_from_namespace = nil
    Multitenancy.add_tenant('test', 'database_username' => 'first_schema' ) do
      call_from_namespace = MingleConfiguration.app_namespace
    end
    assert_equal 'test', call_from_namespace
    assert Multitenancy.tenant_exists?('test')
  end

  def test_tenant_name_uniqueness_should_be_case_insensitive
    Multitenancy.add_tenant('test', 'database_username' => 'first_schema' )
    assert Multitenancy.tenant_exists?('Test')
  end

  def test_if_setup_failed_tenant_should_not_be_added
    assert_raise(RuntimeError) do
      Multitenancy.add_tenant('test', 'database_username' => 'first_schema' ) do
        raise 'foo'
      end
    end

    assert_false Multitenancy.tenant_exists?('test')
  end

  def test_tenant_exists_should_be_false_for_invalid_name
    invalid = '  '
    assert_false Multitenancy.tenant_exists?(invalid)
  end

  def test_tenant_active_will_switch_app_namespace
    old_app_namespace = 'zeroth'
    MingleConfiguration.with_app_namespace_overridden_to(old_app_namespace) do
      assert_equal 'first', activate_tenant('first') { MingleConfiguration.app_namespace }
      assert_equal old_app_namespace, MingleConfiguration.app_namespace
    end
  end

  def test_tenant_active_should_put_tenant_name_into_mdc_on_jruby
    assert_equal 'first', activate_tenant('first') { org.apache.log4j.MDC.get('tenant') }
    assert_nil org.apache.log4j.MDC.get('tenant')
  end

  def test_tenant_active_should_put_prev_tenant_name_back_mdc_when_deactivate_the_tenant
    activate_tenant('second') do
      activate_tenant('first') { org.apache.log4j.MDC.get('tenant') }
      assert_equal 'second',  org.apache.log4j.MDC.get('tenant')
    end
    assert_nil  org.apache.log4j.MDC.get('tenant')
  end

  def test_switch_urls_on_tenant_activate
    MingleConfiguration.overridden_to(:site_u_r_l => 'https://example.com', :api_u_r_l => 'https://example-api.com', :secure_site_u_r_l => 'https://example-secure.com') do
      assert_equal 'https://first.example.com', activate_tenant('first') { MingleConfiguration.site_url }
      assert_equal 'https://first.example-api.com', activate_tenant('first') { MingleConfiguration.api_url }
      assert_equal 'https://first.example-secure.com', activate_tenant('first') { MingleConfiguration.secure_site_url }
    end
  end

  def test_can_not_find_a_tenant_that_havent_been_setup
    assert !Multitenancy.tenant_exists?('not-exists')
  end

  def test_can_store_and_retrieve_tenant_configs_through_source
    source = Multitenancy::ConfigSource.create
    assert_nil source['foo']
    source['foo'] = {'database_username' => 'schema'}.to_json
    assert_equal({'database_username' => 'schema'}, JSON.parse(source['foo']))
  end

  def test_delete_tenant_in_config_source
    source = Multitenancy::ConfigSource.create
    assert_nil source['foo']
    source['foo'] = {'database_username' => 'schema'}.to_json
    source['first'] = {'database_username' => 'schema'}.to_json
    source['second'] = {'database_username' => 'schema'}.to_json

    source['foo'] # cached it
    assert Cache.get(source.send(:keyname, 'foo'))

    source.delete('foo')
    assert_nil source['foo']
    assert_nil Cache.get(source.send(:keyname, 'foo'))
    assert_equal ['first', 'second'], source.names.sort
  end

  def test_cache_tenant_config
    source = Multitenancy::ConfigSource.create
    assert_nil source['foo']
    config = {'database_username' => 'schema'}
    source['foo'] = config.to_json
    assert source['foo']
    assert_equal config, JSON.parse(Cache.get(source.send(:keyname, 'foo')))
  end

  def test_delete_tenant
    Multitenancy.add_tenant('site1', 'database_username' => 'site1_schema')
    Multitenancy.delete_tenant('site1')
    assert !Multitenancy.tenant_exists?('site1')
    Multitenancy.delete_tenant('site1')
  end

  def test_delete_tenant_should_pass_tenant_to_block_given
    Multitenancy.add_tenant('site1', 'database_username' => 'site1_schema')
    delete_tenant = nil
    Multitenancy.delete_tenant('site1') {|tenant| delete_tenant = tenant }
    assert_equal 'SITE1_SCHEMA', delete_tenant.schema_name
  end

  def test_can_get_currently_active_tenant
    assert_equal('first', activate_tenant('first') { Multitenancy.active_tenant.name })
    assert_nil Multitenancy.active_tenant
  end

  def test_should_not_lost_activated_tenant_when_activate_tenant
    active_tenant = activate_tenant('first') do
      activate_tenant('second') {}
      Multitenancy.active_tenant.name
    end
    assert_equal 'first', active_tenant
  end

  def test_should_not_lose_site_url_when_switch_site_url_on_tenant_activate
    MingleConfiguration.with_site_u_r_l_overridden_to('https://example.com') do
      url = activate_tenant('first') do
        activate_tenant('second') {}
        MingleConfiguration.site_url
      end
      assert_equal 'https://first.example.com', url
    end
  end

  def test_valid_site_name_is_true_when_conforms_to_rfc_1123
    ['a', 'a1', 'ab', 'a-b', 'a1b', 'ab1', 'a--b', '9', '99problems'].each do |site_name|
      assert Multitenancy.valid_name?(site_name)
    end
  end

  def test_valid_site_name_is_false_when_site_name_does_not_conform_to_rfc_1123
    ['a-', 'ab-', '-a', 'a1-', '--'].each do |invalid_site_name|
      assert !Multitenancy.valid_name?(invalid_site_name), "#{invalid_site_name} should not be a valid site name"
    end
  end

  def test_derive_tenant_name_changes_special_characters_to_hyphens
    assert_equal 'h-o-h-a-c', Multitenancy.derive_tenant_name('h_o-h!@#$*%^&()\'`a.c')
  end

  def test_derive_tenant_name_changes_name_to_lowercase
    assert_equal 'rei', Multitenancy.derive_tenant_name('REI')
  end

  def test_derive_tenant_name_with_special_character_at_end_does_not_generate_a_name_with_a_trailing_hyphen
    assert_equal 'almonds-inc', Multitenancy.derive_tenant_name('Almonds Inc.')
  end

  def test_derive_tenant_name_with_multiple_trailing_special_chars_removes_them_all
    assert_equal 'abc', Multitenancy.derive_tenant_name('ABC@@')
  end

  def test_derive_tenant_name_of_all_special_characters_generates_an_empty_name
    assert_equal '', Multitenancy.derive_tenant_name('!@#$%')
  end

  def test_derive_tenant_name_truncate_to_24_characters
    assert_equal 'snow-white-and-the-seven', Multitenancy.derive_tenant_name('Snow White and the Seven Dwarfs')
  end

  def test_derive_tenant_name_appends_number_if_duplicate
    Multitenancy.add_tenant('exists', 'database_username' => 'site1_schema')
    Multitenancy.add_tenant('exists1', 'database_username' => 'site2_schema')
    assert_equal 'exists2', Multitenancy.derive_tenant_name('exists')
  end

  def test_derive_tenant_name_appends_number_if_duplicate_and_truncates
    Multitenancy.add_tenant('snow-white-and-the-seven', 'database_username' => 'site1_schema')
    assert_equal 'snow-white-and-the-seve1', Multitenancy.derive_tenant_name('Snow White and the Seven Dwarfs')
  end

  def test_find_tenant_is_case_insensitive
    Multitenancy.add_tenant('test-Tenant', 'database_username' => 'site1_schema')
    assert Multitenancy.tenant_exists?('test-tenant')
    assert Multitenancy.tenant_exists?('test-TEnant')
    assert_not_nil Multitenancy.find_tenant('test-tenant')
    assert_not_nil Multitenancy.find_tenant('test-tENant')
  end

  def test_add_tenant_should_return_tenant_created_obj
    tenant = Multitenancy.add_tenant('test-Tenant', 'database_username' => 'site1_schema')
    assert tenant
    assert_equal 'test-tenant', tenant.name
  end

  def test_create_tenant_should_fail_if_tenant_name_is_not_valid
    assert_raises Multitenancy::TenantNameInvalidError do
      Multitenancy.add_tenant('test-', 'database_username' => 'site1_schema')
    end
  end

  def test_overwrite_default_mingle_properties
    Multitenancy.add_tenant('hello', 'database_username' => 'first_schema', 'mingle.config.asset_host' => 'http://getmingle.io', 'mingle.config.debug' => 'true')
    activate_tenant('hello') do
      assert_equal 'http://getmingle.io', MingleConfiguration.asset_host
      assert MingleConfiguration.debug?
    end
  end

  def test_should_ignore_wrong_configuration
    Multitenancy.add_tenant('hello', 'database_username' => 'first_schema', 'mingle.config.not_exist' => 'true', 'mingle.config.debug' => 'true')
    activate_tenant('hello') do
      assert MingleConfiguration.debug?
      assert_false MingleConfiguration.respond_to?(:not_exist?)
    end
  end

  def test_cannot_overwrite_app_namespace
    Multitenancy.add_tenant('hello', 'database_username' => 'second_schema', 'mingle.config.app_namespace' => 'something wrong')
    activate_tenant('hello') do
      assert_equal 'hello', MingleConfiguration.app_namespace
    end
  end

  def test_find_tenant_by_invalid_name
    assert_nil Multitenancy.find_tenant('test-')
  end

  def test_merge_tenant_configuration
    Multitenancy.merge_tenant_config('first', 'mingle.config.debug' => 'true')
    activate_tenant('first') do
      assert MingleConfiguration.debug?
    end
    activate_tenant('second') do
      assert !MingleConfiguration.debug?
    end
    Multitenancy.merge_tenant_config('first', 'mingle.config.debug' => 'false')
    activate_tenant('first') do
      assert !MingleConfiguration.debug?
      assert_equal [['debug', 'false']], Multitenancy.active_tenant.mingle_configurations
    end
  end

  def test_merge_tenant_config_should_ignore_tenant_that_does_not_exist
    Multitenancy.merge_tenant_config('not_exist', 'mingle.config.debug' => 'true')
    activate_tenant('first') do
      assert !MingleConfiguration.debug?
    end
  end

  def test_merge_tenant_config_should_ignore_keys_that_do_not_exist
    Multitenancy.merge_tenant_config('first', 'mingle.config.debug' => 'true')
    Multitenancy.merge_tenant_config('first', 'mingle.config.i_do_not_exist' => 'true')
    activate_tenant('first') do |tenant|
      assert MingleConfiguration.debug?
      assert_equal ['database_username', 'mingle.config.debug'], Multitenancy.send(:tenant_config, 'first').keys.sort
    end
  end

  def test_delete_tenant_config
    Multitenancy.merge_tenant_config('first', 'mingle.config.debug' => 'true')
    Multitenancy.merge_tenant_config('second', 'mingle.config.debug' => 'true')
    Multitenancy.delete_tenant_config('first', 'mingle.config.debug')
    activate_tenant('first') do
      assert !MingleConfiguration.debug?
    end
    activate_tenant('second') do
      assert MingleConfiguration.debug?
    end
  end

  def test_delete_tenant_config_should_ignore_keys_do_not_exist
    Multitenancy.delete_tenant_config('first', 'mingle.config.haha')
    Multitenancy.delete_tenant_config('not_exist', 'mingle.config.haha')
  end

  def test_should_honor_global_configs_while_tenant_switching
    Multitenancy.add_tenant('hello', 'database_username' => 'second_schema', 'mingle.config.asset_host' => 'http://getmingle.io', 'mingle.config.debug' => 'true')
    MingleConfiguration.global_config_store['config'] = YAML.dump({ 'mailgun_domain' => 'http://mailgun.com/api/v3/cupcake.minglesaas.com' })
    activate_tenant('hello') do
      assert_equal 'http://mailgun.com/api/v3/cupcake.minglesaas.com', MingleConfiguration.mailgun_domain
      assert_equal 'http://getmingle.io', MingleConfiguration.asset_host
    end
  end

  private

  def activate_tenant(name, &block)
    Multitenancy.activate_tenant(name, &block)
  end

end
