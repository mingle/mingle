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

module UseArrowKeyOnDropDownWorkflow
  CARD = 'Card'
  TYPE = 'Type'
  STORY = 'story'
  ITERATION = 'Iteration'
  SETS = 'sets'
  REQUIRES = 'requires'
  NO_CHANGE = '(no change)'
  ANY = '(any)'
  ANY_CHANGE = '(any change)'
  SET = '(set)'
  REQUIRE_USER_INPUT = '(user input - required)'
  OPTIONAL_USER_INPUT = '(user input - optional)'

  STATUS = 'status'
  NEW = 'new'
  OPEN = 'open'
  CLOSED = 'closed'
  OWNER = 'owner'
  SIZE = 'Size'
  START_DATE = "start_date"
  RELEASE = "release"
  RIVISION = "revision"
  ESTIMATE = "estimate"
  NOT_SET = '(not set)'
  CURRENT_USER = "(current user)"
  TODAY = "(today)"

  TEXT_PLV_1 = 'text plv 1'
  TEXT_PLV_2 = 'text plv 2'
  TEXT_PLV_3 = 'text plv 3'
  NUMBER_PLV_1 = 'number plv 1'
  NUMBER_PLV_2 = 'number plv 2'
  NUMBER_PLV_3 = 'number plv 3'
  DATE_PLV_1 = 'date plv 1'
  DATE_PLV_2 = 'date plv 2'
  CARD_PLV_1 = 'card plv 1'
  CARD_PLV_2 = 'card plv 2'
  CARD_PLV_3 = 'card plv 3'

  TEXT_PLV_1_VALUE = 'revision 1'
  TEXT_PLV_2_VALUE = 'revision 2'
  TEXT_PLV_3_VALUE = 'revision 3'
  NUMBER_PLV_1_VALUE = '2010'
  NUMBER_PLV_2_VALUE = '2011'
  NUMBER_PLV_3_VALUE = '2012'

  def card_type_is_set_in_the_first_condition(card_type)
    @browser.assert_attribute_equal("card_type_name_drop_link@title", card_type)
  end

  def value_is_set_for_property_in_the_second_filter(property_name,value)
    property=@project.all_property_definitions.find_by_name(property_name)
    @browser.assert_attribute_equal("acquired_#{property.html_id}_drop_link@title", value)
  end

  def open_card_type_involved_value_list
    @browser.click('card_type_name_drop_link')
  end

  def open_value_list_for_property_in_second_condition(property_name)
    ensure_sidebar_open
    property=@project.all_property_definitions.find_by_name(property_name)
    @browser.click("acquired_#{property.html_id}_drop_link")
  end

  def can_use_up_or_down_arrow_key_to_move_highlight_on_value_drop_down_for_property_in_second_condition(property_name,options)
    options[1,options.size-1].each do |option|
      press_down_arrow_key_on_value_drop_down_for_property_in_second_conditon(property_name)
      option_should_be_highlighted_on_property_drop_down_in_the_second_condition(property_name,option)
    end

    options.reverse[1,options.size-1].each do |option|
      press_up_arrow_key_on_value_drop_down_for_property_in_second_condition(property_name)
      option_should_be_highlighted_on_property_drop_down_in_the_second_condition(property_name,option)
    end
  end

  def can_use_up_or_down_arrow_key_to_move_highlight_on_card_type_involved_drop_down(options)
    options[1,options.size-1].each do |option|
      press_down_arrow_key_on_card_type_involved_drop_down_on_history_filter
      card_type_involved_should_be_highlighted_on_history_filter(option)
    end

    options.reverse[1,options.size-1].each do |option|
      press_up_arrow_key_on_card_type_involved_drop_down_on_history_filter
      card_type_involved_should_be_highlighted_on_history_filter(option)
    end
  end

  def card_type_involved_should_be_highlighted_on_history_filter(option)
    @browser.assert_attribute_equal("card_type_name_option_#{option}@class", 'select-option selected')
  end

  def option_should_be_highlighted_on_property_drop_down_in_the_second_condition(property_name,option)
    property=@project.all_property_definitions.find_by_name(property_name)
    @browser.assert_attribute_equal("acquired_#{property.html_id}_option_#{option}@class", 'select-option selected')
  end

  def press_down_arrow_key_on_value_drop_down_for_property_in_second_conditon(property_name)
    property = @project.all_property_definitions.find_by_name(property_name)
    press_key_on_dropdown(Keycode::DOWN, "acquired_#{property.html_id}_drop_down")
  end

  def press_up_arrow_key_on_value_drop_down_for_property_in_second_condition(property_name)
    property=@project.all_property_definitions.find_by_name(property_name)
    press_key_on_dropdown(Keycode::UP, "acquired_#{property.html_id}_drop_down")
  end

  def press_down_arrow_key_on_card_type_involved_drop_down_on_history_filter
    press_key_on_dropdown(Keycode::DOWN, "card_type_name_drop_down")
  end

  def press_up_arrow_key_on_card_type_involved_drop_down_on_history_filter
    press_key_on_dropdown(Keycode::UP, "card_type_name_drop_down")
  end

  def press_enter_on_card_type_involved_drop_down_on_history_filter
    @browser.with_ajax_wait do
      press_key_on_dropdown(Keycode::ENTER, "card_type_name_drop_down")
    end
  end

  def press_enter_on_value_drop_down_for_property_in_second_condition(property_name)
    property=@project.all_property_definitions.find_by_name(property_name)
    @browser.with_ajax_wait do
      press_key_on_dropdown(Keycode::ENTER, "acquired_#{property.html_id}_drop_down")
    end
  end

  def press_down_arrow_key_on_tree_filter_values_drop_down_for_card_type(filter_number,card_type)
    press_key_on_dropdown(Keycode::DOWN, "cardtype_#{card_type.id}-filter-widget_cards_filter_#{filter_number}_values_drop_down")
  end

  def press_up_arrow_key_on_tree_filter_values_drop_down_for_card_type(filter_number,card_type)
    press_key_on_dropdown(Keycode::UP, "cardtype_#{card_type.id}-filter-widget_cards_filter_#{filter_number}_values_drop_down")
  end

  def option_should_be_highlighted_on_tree_filter_values_drop_down(filter_number,card_type,option)
    @browser.assert_attribute_equal("cardtype_#{card_type.id}-filter-widget_cards_filter_#{filter_number}_values_option_#{option}@class", 'select-option selected')
  end

  def can_use_up_or_down_arrow_key_to_move_highlight_on_tree_filter_values_drop_down_for_card_type(filter_number,card_type,options)
    options[1,options.size-1].each do |option|
      press_down_arrow_key_on_tree_filter_values_drop_down_for_card_type(filter_number,card_type)
      option_should_be_highlighted_on_tree_filter_values_drop_down(filter_number,card_type,option)
    end

    options.reverse[1,options.size-1].each do |option|
      press_up_arrow_key_on_tree_filter_values_drop_down_for_card_type(filter_number,card_type)
      option_should_be_highlighted_on_tree_filter_values_drop_down(filter_number,card_type,option)
    end
  end

  def can_use_up_or_down_arrow_key_to_move_highlight_on_tree_filter_operators_drop_down_for_card_type(filter_number,card_type,options)
    options[1,options.size-1].each do |option|
      press_down_arrow_key_on_tree_filter_operators_drop_down_for_card_type(filter_number,card_type)
      option_should_be_highlighted_on_tree_filter_operators_drop_down(filter_number,card_type,option)
    end

    options.reverse[1,options.size-1].each do |option|
      press_up_arrow_key_on_tree_filter_operators_drop_down_for_card_type(filter_number,card_type)
      option_should_be_highlighted_on_tree_filter_operators_drop_down(filter_number,card_type,option)
    end
  end

  def press_down_arrow_key_on_tree_filter_operators_drop_down_for_card_type(filter_number,card_type)
    press_key_on_dropdown(Keycode::DOWN, "cardtype_#{card_type.id}-filter-widget_cards_filter_#{filter_number}_operators_drop_down")
  end

  def press_up_arrow_key_on_tree_filter_operators_drop_down_for_card_type(filter_number,card_type)
    press_key_on_dropdown(Keycode::UP, "cardtype_#{card_type.id}-filter-widget_cards_filter_#{filter_number}_operators_drop_down")
  end

  def there_is_a_ris_tree_with_cards
    there_are_some_card_types(@project)

    @release_1 = create_card!(:name => 'release 1', :card_type => @release_type)
    @planning_tree= setup_tree(@project, 'Planning', :types => [@release_type, @iteration_type, @story_type], :relationship_names => ["planning-release", "planning-iteratoin"])
    add_card_to_tree(@planning_tree, @release_1)
  end

  def option_should_be_highlighted_on_tree_filter_operators_drop_down(filter_number,card_type,option)
    @browser.assert_attribute_equal("cardtype_#{card_type.id}-filter-widget_cards_filter_#{filter_number}_operators_option_#{option}@class", 'select-option selected')
  end

  def can_use_up_or_down_arrow_key_to_move_highlight_on_tree_filter_properties_drop_down_for_card_type(filter_number,card_type,options)
    press_down_arrow_key_on_tree_filter_properties_drop_down_for_card_type(filter_number,card_type) if @browser.get_attribute("cardtype_#{card_type.id}-filter-widget_cards_filter_#{filter_number}_properties_drop_link@title")=="(select...)"
    options[1,options.size-1].each do |option|
      press_down_arrow_key_on_tree_filter_properties_drop_down_for_card_type(filter_number,card_type)
      option_should_be_highlighted_on_tree_filter_properties_drop_down(filter_number,card_type,option)
    end

    options.reverse[1,options.size-1].each do |option|
      press_up_arrow_key_on_tree_filter_properties_drop_down_for_card_type(filter_number,card_type)
      option_should_be_highlighted_on_tree_filter_properties_drop_down(filter_number,card_type,option)
    end
  end

  def press_down_arrow_key_on_tree_filter_properties_drop_down_for_card_type(filter_number,card_type)
    press_key_on_dropdown(Keycode::DOWN, "cardtype_#{card_type.id}-filter-widget_cards_filter_#{filter_number}_properties_drop_down")
  end

  def press_up_arrow_key_on_tree_filter_properties_drop_down_for_card_type(filter_number,card_type)
    press_key_on_dropdown(Keycode::UP, "cardtype_#{card_type.id}-filter-widget_cards_filter_#{filter_number}_properties_drop_down")
  end

  def option_should_be_highlighted_on_tree_filter_properties_drop_down(filter_number,card_type,option)
    @browser.assert_attribute_equal("cardtype_#{card_type.id}-filter-widget_cards_filter_#{filter_number}_properties_option_#{option}@class", 'select-option selected')
  end

  def press_enter_on_cards_filter_properties_drop_down(filter_number)
    press_key_on_dropdown(Keycode::ENTER, "cards_filter_#{filter_number}_properties_drop_down")
  end

  def press_enter_on_cards_filter_operators_drop_down(filter_number)
    press_key_on_dropdown(Keycode::ENTER, "cards_filter_#{filter_number}_operators_drop_down")
  end

  def press_enter_on_cards_filter_values_drop_down(filter_number)
    press_key_on_dropdown(Keycode::ENTER, "cards_filter_#{filter_number}_values_drop_down")
  end

  def can_use_up_or_down_arrow_key_to_move_highlight_on_cards_filter_operators_drop_down(filter_number,options)
    options[1,options.size-1].each do |option|
      press_down_arrow_key_on_cards_filter_operators_drop_down(filter_number)
      option_should_be_highlighted_on_cards_filter_operators_drop_down(filter_number,option)
    end

    options.reverse[1,options.size-1].each do |option|
      press_up_arrow_key_on_cards_filter_operators_drop_down(filter_number)
      option_should_be_highlighted_on_cards_filter_operators_drop_down(filter_number,option)
    end
  end

  def can_use_up_or_down_arrow_key_to_move_highlight_on_cards_filter_values_drop_down(filter_number,options)
    options[1,options.size-1].each do |option|
      press_down_arrow_key_on_cards_filter_values_drop_down(filter_number)
      option_should_be_highlighted_on_cards_filter_values_drop_down(filter_number,option)
    end

    options.reverse[1,options.size-1].each do |option|
      press_up_arrow_key_on_cards_filter_values_drop_down(filter_number)
      option_should_be_highlighted_on_cards_filter_values_drop_down(filter_number,option)
    end

  end

  def can_use_up_or_down_arrow_key_to_move_highlight_on_cards_filter_properties_drop_down(filter_number,options)
    press_down_arrow_key_on_cards_filter_properties_drop_down(filter_number) if @browser.get_attribute("cards_filter_#{filter_number}_properties_drop_link@title")=="(select...)"
    options[1,options.size-1].each do |option|
      press_down_arrow_key_on_cards_filter_properties_drop_down(filter_number)
      option_should_be_highlighted_on_cards_filter_properties_drop_down(filter_number,option)
    end
    options.reverse[1,options.size-1].each do |option|
      press_up_arrow_key_on_cards_filter_properties_drop_down(filter_number)
      option_should_be_highlighted_on_cards_filter_properties_drop_down(filter_number,option)
    end
  end

  def option_should_be_highlighted_on_cards_filter_operators_drop_down(filter_number,option)
    @browser.assert_attribute_equal("cards_filter_#{filter_number}_operators_option_#{option}@class", 'select-option selected')
  end

  def press_down_arrow_key_on_cards_filter_operators_drop_down(filter_number)
    press_key_on_dropdown(Keycode::DOWN, "cards_filter_#{filter_number}_operators_drop_down")
  end

  def press_up_arrow_key_on_cards_filter_operators_drop_down(filter_number)
    press_key_on_dropdown(Keycode::UP, "cards_filter_#{filter_number}_operators_drop_down")
  end

  def option_should_be_highlighted_on_cards_filter_values_drop_down(filter_number,option)
    @browser.assert_attribute_equal("cards_filter_#{filter_number}_values_option_#{option}@class", 'select-option selected')
  end

  def press_down_arrow_key_on_cards_filter_values_drop_down(filter_number)
    press_key_on_dropdown(Keycode::DOWN, "cards_filter_#{filter_number}_values_drop_down")
  end

  def press_up_arrow_key_on_cards_filter_values_drop_down(filter_number)
    press_key_on_dropdown(Keycode::UP, "cards_filter_#{filter_number}_values_drop_down")
  end

  def option_should_be_highlighted_on_cards_filter_properties_drop_down(filter_number,option)
    @browser.assert_attribute_equal("cards_filter_#{filter_number}_properties_option_#{option}@class", 'select-option selected')
  end

  def press_down_arrow_key_on_cards_filter_properties_drop_down(filter_number)
    press_key_on_dropdown(Keycode::DOWN, "cards_filter_#{filter_number}_properties_drop_down")
  end

  def press_up_arrow_key_on_cards_filter_properties_drop_down(filter_number)
    press_key_on_dropdown(Keycode::UP, "cards_filter_#{filter_number}_properties_drop_down")
  end

  def can_use_up_or_down_arrow_key_to_move_highlight_on_property_drop_down_on_transition_edit_page(widget_name,property,options)
    options[1,options.size-1].each do |option|
      press_down_arrow_key_on_property_drop_down_on_transition_edit_page(widget_name,property)
      option_should_be_hightlighted_on_drop_down_on_transiton_edit(widget_name,property,option)
    end

    options.reverse[1,options.size-1].each do |option|
      press_up_arrow_key_on_property_drop_down_on_transition_edit_page(widget_name,property)
      option_should_be_hightlighted_on_drop_down_on_transiton_edit(widget_name,property,option)
    end
  end

  def press_down_arrow_key_on_property_drop_down_on_transition_edit_page(widget_name,property)
    press_key_on_dropdown(Keycode::DOWN, droplist_dropdown_id_on_transition_edit_page(widget_name, property))
  end

  def press_up_arrow_key_on_property_drop_down_on_transition_edit_page(widget_name,property)
    press_key_on_dropdown(Keycode::UP, droplist_dropdown_id_on_transition_edit_page(widget_name, property))
  end

  def option_should_be_hightlighted_on_drop_down_on_transiton_edit(widget_name,property,option)
    option=droplist_option_id_on_transition_edit_page(widget_name,property,option)
    @browser.assert_attribute_equal("#{option}@class", 'select-option selected')
  end

  def can_use_up_or_down_arrow_key_to_move_highlight_on_card_shown_card_type_drop_down(card_types)
    card_types[1,card_types.size-1].each do |card_type|
      press_down_arrow_key_on_card_type_drop_down_on_card_show
      card_type_should_be_hightlighted_on_card_show(card_type)
    end

    card_types.reverse[1,card_types.size-1].each do |card_type|
      press_up_arrow_key_on_card_type_drop_down_on_card_show
      card_type_should_be_hightlighted_on_card_show(card_type)
    end
  end

  def press_up_arrow_key_on_card_type_drop_down_on_card_show
    press_key_on_dropdown(Keycode::UP, "show_card_type_drop_down")
  end

  def press_down_arrow_key_on_card_type_drop_down_on_card_show
    press_key_on_dropdown(Keycode::DOWN, "show_card_type_drop_down")

  end

  def card_type_should_be_hightlighted_on_card_show(card_type)
    @browser.assert_attribute_equal("show_card_type_option_#{card_type}@class", 'select-option selected')
  end

  def click_to_edit_card_type
    @browser.click('show_card_type_drop_link')
  end

  def can_use_up_or_down_arrow_key_to_move_highlight_on_property_drop_down(property,options,context=nil)
    options[1,options.size-1].each do |option|
      press_down_arrow_key_on_property_drop_down(property,context)
      option_should_be_hightlighted_on_drop_down(property,option,context)
    end

    options.reverse[1,options.size-1].each do |option|
      press_up_arrow_key_on_property_drop_down(property,context)
      option_should_be_hightlighted_on_drop_down(property,option,context)
    end
  end

  def can_use_up_or_down_arrow_key_to_move_highlight_on_bulk_edit_card_type_drop_down(card_types)
    card_types[1,card_types.size-1].each do |card_type|
      press_down_arrow_key_on_bulk_edit_card_type_drop_down
      card_type_should_be_hightlighted_on_bulk_edit_panel(card_type)
    end

    card_types.reverse[1,card_types.size-1].each do |card_type|
      press_up_arrow_key_on_bulk_edit_card_type_drop_down
      card_type_should_be_hightlighted_on_bulk_edit_panel(card_type)
    end
  end

  def the_hightlighted_value_should_be_assign_to_estimate_property
    assert_property_set_in_bulk_edit_panel(@project, ESTIMATE, NUMBER_PLV_1_VALUE)
  end

  def press_enter_to_select_the_highlighted_value(property,context=nil)
    @browser.with_ajax_wait do
      press_key_on_dropdown(Keycode::ENTER, droplist_dropdown_id(property,context))
    end
  end

  def highlight_should_be_changed
    card_type_should_be_hightlighted_on_bulk_edit_panel(CARD)
  end

  def press_left_arrow_key_on_bulk_edit_card_type_drop_down
    press_key_on_dropdown(Keycode::LEFT, "bulk_edit_card_type_drop_down")
  end

  def press_right_arrow_key_on_bulk_edit_card_type_drop_down
    press_key_on_dropdown(Keycode::RIGHT, "bulk_edit_card_type_drop_down")
  end

  def press_up_arrow_key_on_bulk_edit_card_type_drop_down
    press_key_on_dropdown(Keycode::UP, "bulk_edit_card_type_drop_down")
  end

  def card_type_should_be_hightlighted_on_bulk_edit_panel(card_type)
    @browser.assert_attribute_equal("bulk_edit_card_type_option_#{card_type}@class", 'select-option selected')
  end

  def there_are_some_card_types(project)
    @story_type = setup_card_type(project, STORY,:properties => [STATUS,SIZE,START_DATE,RELEASE,RIVISION,ESTIMATE,OWNER])
    @iteration_type = setup_card_type(project, ITERATION,:properties => [STATUS,SIZE,START_DATE,RELEASE,RIVISION,ESTIMATE,OWNER])
    @release_type = setup_card_type(project, RELEASE,:properties => [STATUS,SIZE,START_DATE,RELEASE,RIVISION,ESTIMATE,OWNER])
  end

  def there_are_some_number_plv_available_for_any_number_property
    create_number_plv(@project,NUMBER_PLV_1,NUMBER_PLV_1_VALUE,[@estimate])
    create_number_plv(@project,NUMBER_PLV_2,NUMBER_PLV_2_VALUE,[@estimate])
    create_number_plv(@project,NUMBER_PLV_3,NUMBER_PLV_3_VALUE,[@estimate])
  end

  def there_are_some_text_plv_available_for_any_text_property
    create_text_plv(@project,TEXT_PLV_1,TEXT_PLV_1_VALUE,[@revision])
    create_text_plv(@project,TEXT_PLV_2,TEXT_PLV_2_VALUE,[@revision])
    create_text_plv(@project,TEXT_PLV_3,TEXT_PLV_3_VALUE,[@revision])
  end

  def there_are_some_card_plv_available_for_property
    card_type=@project.card_types.find_by_name("Card")
    create_card_plv(@project, CARD_PLV_1,card_type,@card,[@release])
    create_card_plv(@project, CARD_PLV_2,card_type,@card,[@release])
    create_card_plv(@project, CARD_PLV_3,card_type,@card,[@release])
  end

  def there_are_some_date_plv_available_for_property
    create_date_plv(@project, DATE_PLV_1, '2010-01-01', [@start_date])
    create_date_plv(@project, DATE_PLV_2, '2010-01-02', [@start_date])
  end

  def select_cards_to_bulk_edit_card_type
    navigate_to_card_list_for(@project)
    select_all
    open_bulk_edit_properties
    @browser.click("bulk_edit_card_type_drop_link")
  end

  def select_cards_in_card_list_view
    navigate_to_card_list_for(@project)
    select_all
  end

  def bulk_edit_property(property)
    open_bulk_edit_properties
    click_property_on_bulk_edit_panel(property)
  end

  def press_down_arrow_key_on_bulk_edit_card_type_drop_down
    press_key_on_dropdown(Keycode::DOWN, "bulk_edit_card_type_drop_down")
  end

  def press_down_arrow_key_on_property_drop_down(property, context=nil)
    press_key_on_dropdown(Keycode::DOWN, droplist_dropdown_id(property,context))
  end

  def press_up_arrow_key_on_property_drop_down(property, context=nil)
    press_key_on_dropdown(Keycode::UP, droplist_dropdown_id(property,context))
  end

  def option_should_be_hightlighted_on_drop_down(property,value,context=nil)
    option=droplist_option_id(property, value, context)
    @browser.assert_attribute_equal("#{option}@class", 'select-option selected')
  end

  def value_should_be_assign_to_property_on_card_edit(property,value)
    assert_properties_set_on_card_edit(property => value)
  end

  def open_to_edit_a_card_whose_status_is(value)
    @card_1 = create_card!(:name => 'card 1', :card_type => CARD, STATUS => value)
    open_card_for_edit(@project,@card_1)
  end

  def press_key_on_dropdown(keycode, dropdown_id)
    if self.class.selenium_browser == "*firefox"
      search_filter = css_locator("##{dropdown_id} .dropdown-options-filter")
      target = @browser.is_element_present(search_filter) ? search_filter : dropdown_id
      @browser.key_press(target, keycode)
      sleep 0.1
    else
      @browser.key_down(dropdown_id, keycode)
      @browser.key_up(dropdown_id, keycode)
      sleep 0.1
    end
  end

  def press_enter_on_property_dropdown(property_name)
    property = @project.all_property_definitions.find_by_name(property_name)
    @browser.with_ajax_wait do
      press_key_on_dropdown(Keycode::ENTER, "show_enumeratedpropertydefinition_#{property.id}_drop_down")
    end
  end

  def should_still_see_dropdown(property_name)
    property = @project.all_property_definitions.find_by_name(property_name)
    @browser.assert_element_present("show_enumeratedpropertydefinition_#{property.id}_drop_down")
  end
end
