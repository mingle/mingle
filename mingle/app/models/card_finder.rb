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

module CardFinder
  
  def self.included(base)
    base.extend(ClassMethods)
    class << base
      alias_method_chain :find, :mql
      alias_method_chain :find, :property
      alias_method_chain :calculate, :mql
      alias_method_chain :find, :order_by_number_desc_as_default
    end
  end
  
  module ClassMethods
    
    # find cards that has a property value
    # example: find cards owner are member
    #     property = owner_property_definition.property_value_from_db(member.id)
    #     @project.cards.find(:all, :property => property)
    def find_with_property(*args, &block)
      options = args.last.is_a?(Hash) ? args.last : {}
      if property = options.delete(:property)
        property_condition = SqlHelper.sanitize_sql("#{property.property_definition.quoted_column_name} = ?", property.db_identifier)
        merge_new_conditions(options, property_condition)
      end
      find_without_property(*args, &block)      
    end

    # find cards using mql condition
    # example: find cards owner are member
    #  @project.cards.find(:all, :mql => "owner = member")
    # can also use a card query object :query => query instead of mql to avoid mql parsing overhead
    def find_with_mql(*args, &block)
      options = args.last.is_a?(Hash) ? args.last : {}
      translate_mql(options)
      translate_query(options)
      find_without_mql(*args, &block)
    end

    # calculate using mql condition. we need provid this to make will pagination work with mql condition
    # example: how many cards owner are member
    #  @project.cards.count(:mql => "owner = member")
    def calculate_with_mql(operation, column_name, options = {})
      options[:conditions] = if options[:conditions]
        conditions = Array(options[:conditions])
        SqlHelper.sanitize_sql(conditions.first, *conditions[1..-1])
      else
        nil
      end
      translate_mql(options)
      translate_query(options)
      calculate_without_mql(operation, column_name, options)
    end
    
    def find_with_order_by_number_desc_as_default(*args)
      if args[0] == :all
        options = args.last.is_a?(Hash) ? args.last : {}
        options[:order] = "#{Card.quoted_table_name}.#{connection.quote_column_name('number')} desc" if options[:order].nil?
        find_without_order_by_number_desc_as_default(:all, options)
      else
        find_without_order_by_number_desc_as_default(*args)
      end
    end
    
    private
    def translate_mql(options)
      if mql = options.delete(:mql)
        merge_card_query_to_conditions(CardQuery.parse(mql), options)
      end
    end
    
    def translate_query(options)
      if query = options.delete(:query)
        merge_card_query_to_conditions(query, options)
      end
    end
    
    def merge_card_query_to_conditions(query, options)
      merge_new_conditions(options, "#{connection.quote_column_name('number')} in (#{query.find_card_numbers_sql})")
    end
    
    def merge_new_conditions(options, new_condition)
      if options[:conditions]
        options[:conditions] = "(#{options[:conditions]}) AND (#{new_condition})"
      else
        options[:conditions] = new_condition
      end      
    end
  end
  
end
