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

module SQLBulkMethods
  include SecureRandomHelper

  def bulk_update(options)
    # options[:for_ids] (or options[:for_card_ids], etc.) will be a list of ids for mysql, but will be a sql string (in the form IN (23, 24) or IN (SELECT id ...)) for postgresql
    extra_conditions = options[:where] ? options[:where].in_parenthesis : nil

    id_key_name = options.keys.detect { |key| key.to_s =~ /for_(.*)s/ }
    id_condition = id_key_name && options[id_key_name.to_sym] ? get_id_condition(options[id_key_name.to_sym], :id_column_name => $1) : nil

    execute_bulk_update(:table => options[:table], :set => options[:set], :where => [id_condition, extra_conditions].compact.join(' AND '))
  end

  # caution: callers need to take care of quoting column names by themselves
  def insert_into(options)
    options = {:generate_id => true, :insert_columns => [], :select_columns => []}.merge(options)

    conditions = options[:where]
    where = conditions.blank? ? "" : "WHERE"

    options[:insert_columns].unshift('id') if options[:generate_id]
    insert_columns = options[:insert_columns].empty? ? nil : "(#{options[:insert_columns].join(", ")})"

    options[:select_columns].unshift(ActiveRecord::Base.connection.next_id_sql(options[:table])) if options[:generate_id]
    select_columns = options[:select_columns].join(", ")

    distinct = options[:select_distinct] ? "DISTINCT" : ""
    group_by = options[:group_by] ? "GROUP BY #{options[:group_by]}" : ""

    sql = %{
      INSERT INTO #{quote_table_name(options[:table])} #{insert_columns}
        (SELECT #{distinct} #{select_columns}
        FROM #{options[:from]}
        #{where} #{conditions} #{group_by}
        )
    }
    execute(sql)
  end

  def delete_from(options)
    extra_conditions = options[:where] ? options[:where].in_parenthesis : nil

    id_key_name = options.keys.detect { |key| key.to_s =~ /for_(.*)s/ }
    id_name = $1

    id_condition = options[id_key_name.to_sym] ? get_id_condition(options[id_key_name.to_sym], :id_column_name => id_name) : nil
    execute_delete_from(:table => options[:table], :where => [id_condition, extra_conditions].compact.join(' AND '))
  end

  def get_id_condition(for_ids, options = {:id_column_name => 'id'})
    "#{options[:id_column_name]} #{for_ids}"
  end

  private

  def execute_bulk_update(options)
    where = options[:where].blank? ? "" : "WHERE"
    sql = %{
      UPDATE #{quote_table_name(options[:table])}
      SET #{options[:set]}
      #{where} #{options[:where]}
    }
    execute(sql)
  end

  def execute_delete_from(options)
    where = options[:where].blank? ? "" : "WHERE"
    sql = %{
      DELETE FROM #{quote_table_name(options[:table])} #{where} #{options[:where]}
    }
    execute(sql)
  end

end


