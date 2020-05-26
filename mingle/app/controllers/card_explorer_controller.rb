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

class CardExplorerController < ProjectApplicationController
  helper :js_filter
  skip_before_filter :clear_card_context
  allow :get_access_for => [:search_cards_for_tree, :filter_tree_cards, :show_card_selector, :filter_cards, :search_cards]
  
  def search_cards_for_tree
    tree = @project.tree_configurations.find(params[:tree])
    search = CardExplorer::FullTextSearchExplorer.new(@project, tree, params)                                                             
    cards = search.cards                                                             
    cards_in_tree, card_candidates = cards.partition{|card| tree.include_card?(card)}

    render(:update) do |page|
      page.replace_html 'card_drag_candidates_from_search', 
                        :partial => 'search_results_for_tree', 
                        :locals => {:card_candidates => card_candidates, 
                                    :cards_in_tree => cards_in_tree, 
                                    :search => search, 
                                    :tree => tree, 
                                    :prefix => 'search',
                                    :execute_refresh => "$('card_explorer_search_form').onsubmit()"}
    end
  end
  
  def filter_tree_cards 
     tree = @project.tree_configurations.find(params[:tree])
     @view = CardListView.find_or_construct(@project, params)
     
     search = CardExplorer::FilterExplorer.new(@project, tree, params, @view)
     cards = search.cards
     cards_in_tree, card_candidates = cards.partition{|card| tree.include_card?(card)}
     
     render(:update) do |page|
       page.replace_html 'card_drag_candidates_from_filter', 
                         :partial => 'search_results_for_tree', 
                         :locals => {:card_candidates => card_candidates, 
                                     :cards_in_tree => cards_in_tree, 
                                     :search => search, 
                                     :tree => tree, 
                                     :prefix => 'filter',
                                     :execute_refresh => "$('tree_card_filter').onsubmit()"}
     end
  end
  
  def show_card_selector
    @card_selector = CardSelector.new(@project, params[:card_selector] || {})

    parent_filters = @card_selector.to_filter(params[:parent])
    @cards = @card_selector.filter_by(parent_filters.as_card_query, :page => 1, :per_page => per_page)
    card_selector_html = render_to_string(:partial => 'card_selector')
    card_results_html = render_to_string(:partial => 'card_results')
        
    render(:update) do |page|
      page.inputing_contexts.update card_selector_html
      page << <<-JAVASCRIPT
        var cardTypes = new Array( #{@card_selector.card_types.collect {|card_type| to_js_card_type(card_type)}.join(', ')});

        var cardTypeDefinition = new CardTypeDefinition('Type', [['is', 'is'], ['is not', 'is not']], cardTypes, #{(@card_selector.card_types.size == 1).to_json});
        var filters = new Filters(cardTypeDefinition, 'card_explorer_filter', 'card_explorer_filter_widget', "#{image_path('shared/icons/icon_close_14.png')}", "#{image_path('icon-calendar.png')}");
        filters.addFilters(#{to_js_filters(@card_selector.card_type_filters.to_a +  parent_filters.to_a)});
        InputingContexts.top().card_explorer_filters = filters;
      JAVASCRIPT
      page.inputing_contexts.update 'card_selector_filter_results', card_results_html
    end    
  end
  
  def filter_cards
    @card_selector = CardSelector.new(@project, params[:card_selector])
    view = CardListView.find_or_construct(@project, params)
    @cards = @card_selector.filter_by(view.as_card_query, :page => 1, :per_page => per_page)
    card_results_html = render_to_string(:partial => 'card_results')
    render(:update) do |page|
      page.inputing_contexts.update 'card_selector_filter_results', card_results_html
    end
  end
  
  def search_cards
    @card_selector = CardSelector.new(@project, params[:card_selector])
    @cards = @card_selector.search(params[:q], :page => 1, :per_page => per_page)
    card_results_html = render_to_string(:partial => 'card_results')
    render(:update) do |page|
      page.inputing_contexts.update 'card_selector_search_results', card_results_html
    end
  end
  
  private
  def per_page
    params[:per_page] || 50
  end
end
