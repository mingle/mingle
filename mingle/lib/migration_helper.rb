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

module MigrationHelper
  def safe_limit(proposed_limit)
    min_limit = [ActiveRecord::Base.connection.string_limit, proposed_limit].min
    ActiveRecord::Base.connection.limit(min_limit)
  end

  def sanitize_sql(sql, *values)
    SqlHelper.sanitize_sql(sql, *values)
  end

  def quote_column_name(name)
    ActiveRecord::Base.connection.quote_column_name(name)
  end

  def quote_table_name(name)
    ActiveRecord::Base.connection.quote_table_name(name)
  end

  def supports_sequences?
    ActiveRecord::Base.connection.supports_sequences?
  end

  def select_value(*args)
    ActiveRecord::Base.connection.select_value(*args)
  end

  def select_values(*args)
    ActiveRecord::Base.connection.select_values(*args)
  end

  def select_all(*args)
    ActiveRecord::Base.connection.select_all(*args)
  end

  def execute(*args)
    ActiveRecord::Base.connection.execute(*args)
  end

  def database_vendor
    ActiveRecord::Base.connection.database_vendor
  end

  def safe_table_name(*args)
    ActiveRecord::Base.connection.safe_table_name(*args)
  end
  module_function :safe_table_name

  def prefetch_primary_key?(*args)
    ActiveRecord::Base.connection.prefetch_primary_key?(*args)
  end

  def next_id_sql(*args)
    ActiveRecord::Base.connection.next_id_sql(*args)
  end

  def create_not_null_constraint(*args)
    ActiveRecord::Base.connection.create_not_null_constraint(*args)
  end

  def drop_not_null_constraint(*args)
    ActiveRecord::Base.connection.drop_not_null_constraint(*args)
  end

  def postgresql?
    configs = ActiveRecord::Base.configurations[Rails.env]
    configs['adapter'] =~ /postgresql/ || (configs['adapter'] =~ /jruby|jdbc/ && configs['driver'] =~ /postgresql/)
  end

  def each_project(project_ids = [], &block)
    return unless block_given?
    project_ids ||= []
    query = %Q{
      select #{c("id")}, #{c("identifier")}, #{c("cards_table")}, #{c("card_versions_table")}
        from #{t("deliverables")}
       where #{c("type")} = 'Project'
    }
    query += %Q{ and #{c("id")} in (#{project_ids.join(",")}) } unless project_ids.empty?

    result = execute(query)
    result.each do |entry|
      cards_table = no_prefix(entry["cards_table"])
      card_versions_table = no_prefix(entry["card_versions_table"])
      block.call(entry["id"], entry["identifier"], cards_table, card_versions_table)
    end
  end

  def no_prefix(table)
    table.gsub(/^mi_\d{6}_/, "")
  end
end

ActiveRecord::Migration.send(:extend, MigrationHelper)
