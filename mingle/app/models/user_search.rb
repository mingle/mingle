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

module UserSearch
  def self.included(base)
    base.extend(ClassMethods)
  end

  module ClassMethods

    protected

    def users_search(search_query, page, options={})
      join_tables = [:login_access]
      perform_search(search_query, page, join_tables, options)
    end

    def users_search_count(search_query, options={})
      join_tables = [:login_access]
      self.count(:conditions => query_to_conditions(search_query, options),
                 :include => join_tables)
    end


    def memberships_search(search_query, page, options={})
      join_tables = { :user => :login_access }
      perform_search(search_query, page, join_tables, options)
    end

    private

    def query_to_conditions(search_query, options)
      where_clauses = []
      where_clauses << where_clause_for_search(search_query) if search_query.present?
      where_clauses << {:condition => 'activated = ?', :params => [true] } if options[:exclude_deactivated_users]
      where_clauses_to_conditions(where_clauses)
    end

    def perform_search(search_query, page, join_tables, options)
      conditions = query_to_conditions(search_query, options)
      paginator = Paginator.create_with_current_page(self.count(:conditions => conditions, :include => join_tables), :page => page, :items_per_page => options[:per_page])
      paginate(:conditions => conditions, :include => join_tables, :order => order_by_clause_for_search(options[:order_by], options[:direction]),
          :total_entries => paginator.item_count, :per_page => paginator.items_per_page, :page => paginator.current_page)
    end

    def where_clauses_to_conditions(where_clauses)
      sql = where_clauses.collect { |clause| clause[:condition] }.join(" AND ")
      conditions = [sql]
      where_clauses.each do |clause|
        clause[:params].each do |param|
          conditions << param
        end
      end
      conditions
    end

    def where_clause_for_search(search_query)
      search_query.strip!
      search_conditions = ['users.login', 'users.name', 'users.email', 'users.version_control_user_name'].collect { |column| "LOWER(#{column}) LIKE LOWER(?)" }
      { :condition => "(" + search_conditions.join(' OR ') + ")", :params => search_conditions.collect { "%#{search_query}%" } }
    end

    def order_by_clause_for_search(column, direction)
      order_bys = []
      direction = (direction && [:asc, :desc, 'asc', 'desc'].include?(direction.downcase)) ? direction.downcase : 'asc'
      if column == 'last_login_at'
        now = ActiveRecord::Base.connection.datetime_insert_sql(Clock.now.to_formatted_s(:db))
        order_bys << "(#{now} - #{LoginAccess.quoted_table_name}.#{column}) #{direction}"
      elsif column.present?
        order_bys << (User.columns_hash[column].text? ? "LOWER(#{column}) #{direction}" : "#{column} #{direction}")
      end
      order_bys << "LOWER(#{User.quoted_table_name}.name)"
      order_bys.join(", ")
    end
  end
end
