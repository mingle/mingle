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

module CardExplorer
  class FilterExplorer
    include ::SqlHelper
    include ActionView::Helpers::TextHelper

    def initialize(project, tree, params = {}, view = nil)
      @project = project
      @tree = tree
      @view = view
      @card_ids = find_card_ids(@tree, build_sql_for_filter)   
    end
    
    def describe_results
      if @card_ids.size > page_size
        "Showing first #{page_size} results of #{@card_ids.size}." << "<p class=\"search-hint\">(Try refining your filter to find your cards)</p>"
      else
        "Showing #{pluralize(@card_ids.size, 'result')}."
      end.html_safe
    end
    
    def no_result_message
      if @project.cards.count > 0
        "Your filter did not match any cards for the current tree."
      else
        "There are no cards in this project."
      end
    end

    def cards
      current_ids =  @card_ids[0..(page_size - 1)]
      @project.cards.find(:all, :conditions => ["#{Card.quoted_table_name}.id IN (?)", current_ids], :order => "#{Card.quoted_table_name}.#{Card.connection.quote_column_name('number')} DESC" )
    end

    private
    
    def build_sql_for_filter
      #must break out of current workspace, so as to find cards that are not in tree
      @view.to_workspace(nil).as_card_query.to_card_id_sql  
    end

    def page_size
      50
    end

    def find_card_ids(tree, sql_search)
      return [] if sql_search.blank?
      sql_cards_in_tree = "SELECT card_id FROM tree_belongings WHERE tree_configuration_id = #{tree.id}"
      card_types = card_types_in_tree(tree)

      sql_cards_not_in_tree_for_search = "SELECT #{Card.quoted_table_name}.id FROM #{Card.quoted_table_name} 
              WHERE #{Card.quoted_table_name}.id IN (#{sql_search}) 
              AND #{Card.quoted_table_name}.card_type_name IN (?) 
              AND #{Card.quoted_table_name}.id NOT IN (#{sql_cards_in_tree}) 
              ORDER BY #{Card.quoted_table_name}.id DESC"

      sql_cards_in_tree_for_search =  "SELECT #{Card.quoted_table_name}.id FROM #{Card.quoted_table_name} 
                WHERE #{Card.quoted_table_name}.id IN (#{sql_search}) 
                AND #{Card.quoted_table_name}.card_type_name IN (?) 
                AND #{Card.quoted_table_name}.id IN (#{sql_cards_in_tree})
                ORDER BY #{Card.quoted_table_name}.id DESC"

      card_ids_not_in_tree = tree.connection.select_values(sanitize_sql(sql_cards_not_in_tree_for_search, card_types))

      card_ids_in_tree = tree.connection.select_values(sanitize_sql(sql_cards_in_tree_for_search, card_types)) 

      card_ids_not_in_tree + card_ids_in_tree
    end

    def card_types_in_tree(tree)
      tree.all_card_types.collect(&:name)
    end
  end
  
end
