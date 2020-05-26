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

require 'structure_dump'

class SchemaPool
  QUEUE = "mingle.schema_pool"

  include Messaging::Base

  def get_schema
    if schema = retrieve_schema_name_from_queue
      clean_schema?(*schema) ? schema : get_schema
    else
      create_schema
    end
  end

  def size
    Messaging::Gateway.instance.queue_size(QUEUE)
  end

  def generate_one
    retryable(:tries => 3, :sleep => 0.01) { add }
  end

  def replenish_pool
    if replenish_pool?
      Rails.logger.info "Need to replenish [size: #{self.size}, expected: #{expected_pool_size}]. Creating 1 during this run."
      generate_one
      true
    end
  end

  def refresh_messages(number_of_messages=5)
    number_of_messages.times do
      if msg = retrieve_schema_name_from_queue
        send_schema_message(*msg)
      end
    end
  end

  private

  def expected_pool_size
    MingleConfiguration.number_of_pooled_schemas.to_i
  end

  def add
    create_schema.tap {|schema| send_schema_message(*schema) }
  end

  def create_schema
    schema_name = "min_#{SecureRandomHelper.random_32_char_hex[0..23]}_x"
    schema = Multitenancy.schema(MingleConfiguration.new_schema_db_url, schema_name)
    schema.create

    schema.fake_tenant.activate do
      StructureDump.new(ActiveRecord::Base.connection.database_vendor).load
    end
    [schema.db_url, schema.name]
  end

  def send_schema_message(db_url, schema_name)
    send_message(QUEUE, [Messaging::SendingMessage.new({:db_url => db_url, :schema_name => schema_name})])
  end

  def replenish_pool?
    current_size = self.size
    rep_size = expected_pool_size - current_size
    Rails.logger.info "Schema pool current_size: #{current_size}, rep_size: #{rep_size}"
    if rep_size > self.size / 2
      Rails.logger.info "Schema pool size: #{current_size}, need replenish pool"
    end
    rep_size > 0
  end

  def retrieve_schema_name_from_queue
    result = nil
    Messaging::Gateway.instance.receive_message(QUEUE, :batch_size => 1) do |message|
      result = [message[:db_url], message[:schema_name]]
    end
    result
  end

  def clean_schema?(db_url, schema_name)
    schema = Multitenancy.schema(db_url, schema_name)
    schema.fake_tenant.activate do
      ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM users") == '0'
    end
  end
end
