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

# Tags: multitenancy
class SchemaPoolTest < ActiveSupport::TestCase
  include MessagingTestHelper

  def setup
    Messaging.enable
    @adapter_name = Messaging::Adapters.adapter_name
    Messaging::Adapters.adapter_name = "jms"
    Multitenancy.delete_schemas_with_prefix('min\\_')
    clear_message_queue(SchemaPool::QUEUE)
  end

  def teardown
    Messaging::Adapters.adapter_name = @adapter_name
    Multitenancy.delete_schemas_with_prefix('min\\_')
    Multitenancy.clear_tenants
  end

  def test_add_should_put_schema_into_pool
    pool = SchemaPool.new
    _, generated_schema_name = pool.generate_one
    assert_equal 1, pool.size
    db_url, schema_name = pool.get_schema
    assert_equal generated_schema_name, schema_name
    assert_equal ActiveRecordPartitioning.default_config[:url], db_url
  end

  def test_get_schema_should_ignore_schema_already_used
    pool = SchemaPool.new
    _, schema_name = pool.generate_one
    execute_in_schema(schema_name, <<-SQL)
     INSERT INTO USERS (id, login) values (1000, 'foo')
    SQL
    assert_not_equal schema_name, pool.get_schema.last
  end

  def test_get_schema_from_empty_pool_creates_one
    pool = SchemaPool.new
    assert_equal 0, pool.size
    db_url, schema_name = pool.get_schema
    assert schema_name
    assert_equal ActiveRecordPartitioning.default_config[:url], db_url
  end

  def test_should_replenish_pool_per_configuration
    assert_equal 0, Multitenancy.schemas('min\\_').size
    schema_pool = SchemaPool.new
    with_pool_size(1) do
      SchemaPool.new.replenish_pool
      mingle_schemas = Multitenancy.schemas('min\\_')
      assert_equal 1, mingle_schemas.size
      assert_match /^min_(\w+)_x$/i, mingle_schemas.first
      messages = []
      Messaging::Gateway.instance.receive_message(SchemaPool::QUEUE, :batch_size => 1000) do |m|
        messages << m
      end
      assert_equal 1, messages.size

      Multitenancy.without_tenant do
        connection = ActiveRecord::Base.connection
        migrations_count = connection.select_value("select count(*) from #{mingle_schemas.first}.schema_migrations").to_i
        assert migrations_count > 0, "Schema migrations not run while creating pooled schemas"
      end
    end
  end

  def test_get_schema_consumes_a_schema_from_the_pool
    pool = SchemaPool.new
    with_pool_size(1) do
      pool.replenish_pool
      assert_equal 1, pool.size
      db_url, schema_name = pool.get_schema
      assert_match /^min_(\w+)_x$/i, schema_name
      assert_equal ActiveRecordPartitioning.default_config[:url], db_url
      assert_equal 0, pool.size
    end
  end

  def test_replenish_pool
    pool = SchemaPool.new
    with_pool_size(1) do
      assert pool.replenish_pool
      assert !pool.replenish_pool
    end

    with_pool_size(0) do
      assert !pool.replenish_pool
    end
  end

  private

  def with_pool_size(pool_size, &block)
    MingleConfiguration.with_number_of_pooled_schemas_overridden_to(pool_size.to_s) do
      block.call
    end
  end

  def execute_in_schema(schema_name, sql)
    schema = Multitenancy.schema(MingleConfiguration.new_schema_db_url, schema_name)
    schema.fake_tenant.activate do
      ActiveRecord::Base.connection.execute(sql)
    end
  end

  def valid_site_setup_params
    {
      :first_admin => {
        :login => "admin",
        :name => "Admin User",
        :email => "email@exmaple.com"
      },
      :license => valid_license
    }
  end

end
