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

class CardContext

  LAST_TAB = 'last_tab'
  LAST_TAB_FILTER_DESCRIPTION = 'last_tab_filter_description'
  LAST_TAB_NAME = 'last_tab_name'
  CURRENT_LIST_NAVIGATION_CARD_NUMBERS = 'current_list_navigation_card_numbers'
  NO_TREE = 'None'
  LAST_TREE = 'last_tree_name'

  TAB_KEY_PATTERN = /^(.*)_tab$/

  attr_accessor :options, :project

  def initialize(project, params)
    @options = params
    @project = project
  end

  def setup(card_list_view, current_tab, favorite_id)
    current_tree = card_list_view && !card_list_view.tree_name.blank? ? card_list_view.tree_name : NO_TREE

    store_tab_state(card_list_view, current_tab, current_tree, favorite_id)
    self.current_list_navigation_card_numbers = card_list_view.card_numbers
    [card_list_view.cards, card_list_view.page_title]
  end

  def store_tab_state(view, current_tab, current_tree, favorite_id = nil)
    options[view_state_string_key(current_tab)] = view.send(:build_canonical_string)
    tab_params = view.to_tab_params
    tab_params.merge!(:favorite_id => favorite_id) if favorite_id
    unless view.invalid?
      options[LAST_TAB_FILTER_DESCRIPTION] = view.describe_current_filters
    end
    store_tab_params(tab_params, current_tab, current_tree)
  end

  def store_tab_params(params, current_tab, current_tree)
    tab_key = tab_key(current_tab)
    options[tab_key] ||= {}
    options[tab_key][current_tree] = params.dup
    options[tab_key][LAST_TREE] = current_tree
    options[LAST_TAB] = params.dup
    options[LAST_TAB_NAME] = current_tab
  end

  def clear_last_tab_params_on_tab_change(current_tab_name)
    changed_tabs = current_tab_name != last_tab_name
    clear_last_tab_info_if { changed_tabs && last_controller_was_not_cards }
  end

  def clear_last_tab_params_on_context_lost(currently_viewed_card)
    last_controller_was_cards = !last_controller_was_not_cards
    switched_to_a_card_outside_current_context = !(current_list_navigation_card_numbers || []).include?(currently_viewed_card)
    clear_last_tab_info_if { last_controller_was_cards && switched_to_a_card_outside_current_context }
  end

  def tab_for(name, card)
    all_tab = DisplayTabs::AllTab.new(@project, self)
    return all_tab unless name || card
    return all_tab if name == all_tab.name
    if name
      tab = @project.user_defined_tab_favorites.collect(&:favorited).detect { |view| view.name.downcase == name.downcase }
      tab ? {:name => tab.name, :type => CardListView.name} : all_tab
    else
      if (current_list_navigation_card_numbers || []).include?(card.number) && !last_tab_name.blank?
        {:name => last_tab_name, :type => CardListView.name}
      else
        all_tab
      end
    end
  end

  def view_params_for(tab_name, tree_name)
    params = if tab_tree_options_exist?(tab_name, LAST_TREE) && tab_tree_options_exist?(tab_name, last_tree_name = options[tab_key(tab_name)][LAST_TREE])
      options[tab_key(tab_name)][last_tree_name]
    elsif tab_tree_options_exist?(tab_name, tree_name)
      options[tab_key(tab_name)][tree_name]
    else
      project.default_view_for_tab(tab_name).link_params
    end
    (params || {}).merge(:controller => 'cards')
  end

  def parameters_for(tab_name, tree_name)
    tab_tree_options_exist?(tab_name, tree_name) ? options[tab_key(tab_name)][tree_name] : {}
  end

  def canonical_tab_string_for(tab_name)
    if options && options[view_state_string_key(tab_name)]
      options[view_state_string_key(tab_name)]
    else
      project.default_view_for_tab(tab_name).canonical_string
    end
  end

  def last_tab
    params = if options && options[LAST_TAB]
      last_tab_options
    else
      {:tab=>DisplayTabs::AllTab.new(@project, self).name, :action=>"list", :style=>"list"}
    end
  end

  def empty?
    options.empty?
  end

  def current_list_navigation_card_numbers
    options[CURRENT_LIST_NAVIGATION_CARD_NUMBERS]
  end

  def current_list_navigation_card_numbers=(value)
    options[CURRENT_LIST_NAVIGATION_CARD_NUMBERS] = value
  end

  def clear_current_list_navigation_card_numbers
    options.delete(CURRENT_LIST_NAVIGATION_CARD_NUMBERS)
  end

  def add_to_current_list_navigation_card_numbers(numbers)
    options[CURRENT_LIST_NAVIGATION_CARD_NUMBERS] = ((current_list_navigation_card_numbers || []) + numbers).uniq
  end

  def remove_from_current_list_navigation_card_numbers(numbers)
    options[CURRENT_LIST_NAVIGATION_CARD_NUMBERS] = ((current_list_navigation_card_numbers || []) - numbers).uniq
  end

  class SessionUpdater < Struct.new(:project, :old_value, :new_value)
    def update_last_tab(last_tab_options, option_holder)
      option_holder[LAST_TAB] = new_view(last_tab_options).to_tab_params
    end

    def build_canonical_string(tab_options)
      new_view(tab_options).send(:build_canonical_string)
    end
  end


  class TreeConfigNameChangeUpdater < SessionUpdater
    def update_tree_grouped_tab(tab_name, tree_name, tab_options, tab_options_holder)
      if tab_options_holder[LAST_TREE].ignore_case_equal?(old_value)
        tab_options_holder[LAST_TREE] = new_value
      end

      if old_value.ignore_case_equal?(tree_name)
        tab_options_holder.delete(tree_name)
        tab_options_holder[new_value] = new_view(tab_options).to_tab_params
      end
    end

    def new_view(tab_options)
      view = CardListView.construct_from_params(project, tab_options, false)
      if view.tree_name.ignore_case_equal?(old_value)
        view.tree_name = new_value
        view.clear_cached_results_for :to_params
      end
      view
    end
  end

  def change_tree_config_name(old_name, new_name)
    update_tab_options(TreeConfigNameChangeUpdater.new(project, old_name, new_name))
  end


  class VariableNameChangeSessionUpdater < SessionUpdater
    def update_tree_grouped_tab(tab_name, tree_name, tab_options, tab_options_holder)
      view = new_view(tab_options)
      tab_options_holder[tree_name] = view.to_tab_params
    end

    def new_view(tab_options)
      view = CardListView.construct_from_params(project, tab_options, false)
      view.filters.rename_project_variable(old_value, new_value)
      view
    end
  end

  def on_project_variable_name_changed(old_value, new_value)
    update_tab_options(VariableNameChangeSessionUpdater.new(project, old_value, new_value))
  end

  def last_tab_filter_description
    options[LAST_TAB_FILTER_DESCRIPTION] || ''
  end

  private

  def clear_last_tab_info_if
    if yield
      options.delete(LAST_TAB)
      options.delete(LAST_TAB_NAME)
      options.delete(LAST_TAB_FILTER_DESCRIPTION)
    end
  end

  def tab_tree_options_exist?(tab_name, tree_name)
    options && options[tab_name_key = tab_key(tab_name)] && options[tab_name_key][tree_name]
  end

  def update_tab_options(updater)
    options.each do |key, value|
      if key == LAST_TAB
        updater.update_last_tab(options[key], options)
      elsif key =~ TAB_KEY_PATTERN
        tab_name = $1

        # make a shallow copy because JRuby 1.6+ will not allow us to add
        # keys to the iterated hash within an iteration, for good reason.
        read_only_opts = options[key].clone
        read_only_opts.each do |tree_name, tab_tree_special_options|
          next if tree_name == LAST_TREE
          updater.update_tree_grouped_tab(tab_name, tree_name, tab_tree_special_options, options[key])
          options[view_state_string_key(tab_name)] =  updater.build_canonical_string(tab_tree_special_options)  if options[view_state_string_key(tab_name)]
        end
      end
    end
  end

  def last_tab_name
    options[LAST_TAB_NAME]
  end

  def last_tab_options
    options[LAST_TAB] || {}
  end

  def tab_key(tab)
    "#{tab}_tab"
  end

  def last_controller_was_not_cards
    last_controller = last_tab.stringify_keys["controller"]
    !last_controller.blank? && last_controller != CardsController.controller_name
  end

  def view_state_string_key(view_name)
    "#{view_name}_state_canonical_string"
  end

  def reset_view_state_of(tabs)
    tabs.each { |tab| options[tab_key(tab.name)] = {} }
  end

end
