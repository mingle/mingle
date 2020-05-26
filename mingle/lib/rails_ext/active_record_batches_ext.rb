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

module ActiveRecord
  module Batches
    module ClassMethods

      # Example:
      #
      #   Person.find_each_with_order(:conditions => "age > 21", :order => 'age') do |person|
      #     person.party_all_night!
      #   end

      def find_each_with_order(options = {})
        find_in_batches_with_order(options) do |records|
          records.each { |record| yield record }
        end

        self
      end

      # Example:
      #
      #   Person.find_in_batches_with_order(:conditions => "age > 21") do |group|
      #     sleep(50) # Make sure it doesn't get too crowded in there!
      #     group.each { |person| person.party_all_night! }
      #   end
      def find_in_batches_with_order(options = {})
        order_by_column = options.delete(:order_by_column)
        order_by = options.delete(:order_by) || 'ASC'
        raise "You can't specify a limit, it's forced to be the batch_size"  if options[:limit]

        start = options.delete(:start) || 0
        batch_size = options.delete(:batch_size) || 1000
        order = order_by_column ? "#{table_name}.#{connection.quote_column_name(order_by_column)} #{order_by}" : batch_order
        proxy = scoped(options.merge(:limit => batch_size))
        condition = "#{table_name}.#{ connection.quote_column_name(order_by_column|| primary_key)} #{ order_by == 'ASC' ? '>=' : '<=' } ?"
        condition = "#{condition} AND #{options[:conditions]}" if options[:conditions]
        records = proxy.find(:all, :order => order, :conditions => [condition, start ])

        while records.any?
          yield records

          break if records.size < batch_size

          last_value = records.last.send((order_by_column || 'id').to_sym)

          raise "You must include the #{ order_by_column || 'primary'} key if you define a select" unless last_value.present?
          condition = "#{table_name}.#{ connection.quote_column_name(order_by_column|| primary_key)} #{ order_by == 'ASC' ? '>' : '<' } ?"
          condition = "#{condition} AND #{options[:conditions]}" if options[:conditions]
          records = proxy.find(:all, :order => order, :conditions => [condition, last_value ])
        end
      end
    end
  end
end
