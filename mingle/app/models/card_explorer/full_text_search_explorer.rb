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
  class FullTextSearchExplorer
    include ActionView::Helpers::TextHelper

    def initialize(project, tree, params = {})
      @project = project
      @tree = tree
      @full_text_search = params[:q]
    end
  
    def describe_results
      if matched_cards.total_entries > page_size
        "Showing first #{page_size} results of #{matched_cards.total_entries}." << "<p class=\"search-hint\">You may need to refine search terms to find your cards.</p>"
      else
        "Showing #{pluralize(matched_cards.size, 'result')}."
      end.html_safe
    end
  
    def no_result_message
      if @project.cards.count > 0
        "Your search #{@full_text_search.bold} did not match any cards for the current tree."
      else
        "There are no cards in this project."
      end
    end

    def cards
      matched_cards[0..(page_size - 1)]
    end
    memoize :cards

    private
    def matched_cards
      not_on_tree_cards = search("-tree_configuration_ids:#{@tree.id}")
      on_tree_cards     = search("+tree_configuration_ids:#{@tree.id}")
      result = Result::ResultSet.new(page_size, not_on_tree_cards.total_entries.to_f + on_tree_cards.total_entries.to_f)
      result.concat(sort(not_on_tree_cards)).concat(sort(on_tree_cards))
    end
    memoize :matched_cards

    def card_types_condition
      card_types = @tree.all_card_types.map{|ct| "card_type_id:#{ct.id}"}.join(' OR ')
      "(#{card_types})"
    end
    memoize :card_types_condition

    def sort(cards)
      cards.sort_by(&:number).reverse
    end

    def search(context)
      CardSelector.new(@project, :search_context => "#{card_types_condition} AND #{context}").search(@full_text_search)
    end

    def page_size
      50
    end
  end                                

end
