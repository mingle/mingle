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

module ProjectHomePage

  def assert_text_in_search_text_box(text)
    @browser.assert_value search_text_box, text
  end


  def assert_all_tab_not_present
    @browser.assert_element_not_present(ProjectHomePageId::ALL_TAB_ID)
  end

  def assert_all_tab_present
    @browser.assert_element_present(ProjectHomePageId::ALL_TAB_ID)
  end

  def assert_search_input_box_and_button_not_present
    @browser.assert_element_not_present(search_text_box)
    @browser.assert_element_not_present(search_button)
  end

  def assert_text_in_search_text_box(text)
    @browser.assert_value(search_text_box, text)
  end

  def assert_quick_add_card_is_invisible
    @browser.assert_element_not_present(ProjectHomePageId::MAGIC_CARD_THUMBNAIL)
  end

  def assert_quick_add_card_is_visible
    @browser.assert_element_present(ProjectHomePageId::MAGIC_CARD_THUMBNAIL)
  end

  def assert_card_is_added_into_current_view(project, card_name)
    card = project.cards.find_by_name(card_name)
    assert_cards_present_in_grid_view(card)
  end

  def assert_quick_add_not_visible
    @browser.assert_element_not_present(ProjectHomePageId::QUICK_CARD_CARD_ID)
  end

  def assert_quick_add_card_name_empty
    @browser.assert_value(ProjectHomePageId::QUICK_ADD_CARD_NAME, "")
  end

  def assert_cannot_quick_add
    assert_disabled(ProjectHomePageId::QUICK_ADD_BUTTON_ID)
  end

  def assert_card_type_set_on_quick_add_card(expected_type)
    @browser.assert_element_text(QuickAddCardPageId::CARD_TYPE_VALUE_SELECTOR, expected_type)
  end

  def assert_tags_present_on_quick_add_card(*tags)
    tags.each_with_index do |tag, index|
      @browser.assert_element_matches("css=.tageditor .tagit-choice-editable:nth-child(#{index+1}) .tagit-label", /#{tag}/)
    end
  end

  def assert_tags_not_present_on_quick_add_card(*tags)
    tags.each do |tag|
      @browser.assert_element_does_not_match('css=.tageditor .tagit-choice-editable .tagit-label', /#{tag}/)
    end
  end

  def assert_properties_set_on_quick_add_card(properties)
    properties.each {|prop_name, prop_value| assert_property_set_on_quick_add_card(prop_name, prop_value) }
  end

  def assert_property_set_on_quick_add_card(prop_name, prop_value)
    @browser.assert_element_matches(property_value_widget(prop_name), /#{prop_value}/)
  end

  def assert_umnanaged_properties_set_on_quick_add_card(property_values)
    property_values.each {|property_name, property_value|assert_umnanaged_property_set_on_quick_add_card(property_name, property_value)}

  end

  def assert_umnanaged_property_set_on_quick_add_card(property_name, property_value)
    @browser.assert_text(property_value_widget(property_name), property_value)
  end

  def assert_properties_not_present_on_quick_add_card(*prop_names)
    actual_property_names = []
    number_of_properties = @browser.get_eval('this.browserbot.getCurrentWindow().$$(".property-name").length').to_i
    number_of_properties.times {|i| actual_property_names[i] = @browser.get_eval("this.browserbot.getCurrentWindow().$$('.property-name')[#{i}].innerHTML").strip}
    prop_names.each {|prop_name| assert_equal actual_property_names.include?(prop_name), false}
  end


  def assert_tab_highlighted(tab)
    tab = tab.name if tab.respond_to? :name
    @browser.assert_attribute_include("#{tab_id(tab)}@class", /current-menu-item/)
  end

  def assert_fav_view_highlighted(style, view)
     @browser.assert_attribute_equal("favorite-#{(view.favorite.id)}@class", "#{style}-favorite selected")
  end

  def assert_team_fav_wiki_highlighted(page)
     @browser.assert_attribute_equal("favorite-#{(page.favorites.of_team.first.id)}@class", "wiki-favorite selected")
  end

  def assert_fav_view_not_highlighted(style, view)
     @browser.assert_attribute_not_equal("favorite-#{(view.favorite.id)}@class", "#{style}-favorite selected")
  end
  def assert_tab_is(tab_name)
    @browser.assert_element_matches css_locator(".current-menu-item"), Regexp.new(tab_name)
  end

  def assert_tab_present(tab_name)
    @browser.assert_element_present(tab_id(tab_name))
  end

  def assert_tab_not_present(tab_name)
    @browser.assert_element_not_present(tab_id(tab_name))
  end

  def assert_tab_is_not_dirty
    @browser.assert_element_not_present(ProjectHomePageId::RESET_TO_DEFAULT_TAB)
  end

  def assert_located_project_overview(project)
    @browser.assert_location("/projects/#{project.identifier}/overview")
  end

  def assert_quick_add_link_present_on_funky_tray
    @browser.assert_element_present(ProjectHomePageId::MAGIC_CARD_ID)
  end

  def assert_quick_add_link_not_present_on_funky_tray
    @browser.assert_element_not_present(ProjectHomePageId::MAGIC_CARD_ID)
  end

  def assert_admin_pill_not_present
    @browser.assert_element_not_present("admin-drop-down")
  end


  def assert_help_link_on_page(target_help_page, element_class_name, element_index=0)
    show_contextual_help if element_class_name == "full-contextual-help-link"
    @browser.assert_element_present("css=.#{element_class_name}[href*='#{target_help_page}']")
  end


  private

  def property_link_id_on_quick_add_card(prop_name)
    property = @project.reload.find_property_definition(prop_name, :with_hidden => true)

    part_name = (property.attributes['type'] == "FormulaPropertyDefinition") ? 'edit_link': 'drop_link'
    property_link_id = droplist_part_id(prop_name, part_name, 'card')
  end

end
