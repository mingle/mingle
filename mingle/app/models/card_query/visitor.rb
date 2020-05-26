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

class CardQuery  
  class Visitor
    def visit_card_query(query); end
    
    def visit_column(property_definition); end
    
    def visit_id_column; end
    
    def visit_group_by_column(property_definition); end
    
    def visit_order_by_column(property_definition, order, is_default); end
    
    def visit_aggregate_function(function, property_definition); end
    
    def visit_count_all_aggregate; end
    
    def visit_comparison_with_column(column1, operator, column2); end
    
    def visit_comparison_with_plv(column, operator, card_query_plv); end
    
    def visit_comparison_with_value(column, operator, value); end
    
    def visit_comparison_with_number(column, operator, value); end
    
    def visit_today_comparison(column, operator, today); end
    
    def visit_and_condition(*conditions); end
    
    def visit_from_tree_condition(tree_condition, other_conditions); end
    
    def visit_or_condition(*conditions); end
    
    def visit_not_condition(negated_condition); end
    
    def visit_explicit_in_condition(column, values, options = {}); end
    
    def visit_explicit_numbers_in_condition(column, values); end
    
    # This is not officially supported until #5418 is implemented. (Revisit whether a visitor needs to implement this method when that card is played.)
    def visit_implicit_in_condition(column, query); end
    
    def visit_tagged_with_condition(tag); end
    
    def visit_in_plan_condition(plan); end
    
    def visit_is_null_condition(column); end
    
    def visit_is_current_user_condition(column, current_user_login); end
    
    def visit_in_tree_condition(tree); end
    
    def visit_this_card_comparison(column, operator, value); end
    
    def visit_this_card_property_comparison(column, operator, this_card_property); end
  end  
end
