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

require File.expand_path(File.dirname(__FILE__) + '/../../../acceptance/acceptance_test_helper')

# Tags: gridview
class Scenario42ColorAndSortByInGridViewTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  RED = "rgb(212, 41, 43)"
  BLUE = "rgb(48, 228, 239)"
  BLACK = "rgb(0, 0, 0)"
  GREY = "rgb(61, 143, 132)"
  RANK = ""
  NOT_SET =""

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_42', :admins => [users(:proj_admin)])
    @project.activate
    @super_card_type = setup_card_type(@project, "Super Card")
    @sub_card_type = setup_card_type(@project, "Sub Card")
    @card_type = @project.card_types.find_by_name('Card')

    @managed_text = setup_property_definitions :status => ['open', 'closed']
    @another_managed_text = setup_property_definitions :priority => ['high', 'medium']
    @any_text = setup_allow_any_text_property_definition 'address'
    @managed_number = setup_numeric_property_definition('size',[1,2,3])
    @any_number = setup_allow_any_number_property_definition 'iteration'
    @any_date = setup_date_property_definition 'started on'
    @formula = setup_formula_property_definition('formula', "'#{@any_date.name}' + 1")
    @any_card = setup_card_relationship_property_definition('dependency')
    @user = setup_user_definition('owner')
    @tree = setup_tree(@project, 'Simple Tree', :types => [@super_card_type, @card_type, @sub_card_type], :relationship_names => ["tree - first", "tree - second"])
    @aggregate = setup_aggregate_property_definition('aggregate', AggregateType::COUNT, nil, @tree.id, @card_type.id, @sub_card_type)
    login_as_proj_admin_user
  end

  def test_should_provide_tooltip_for_property_used_in_lane_actions
    tooltips = {}
    ["status","owner","priority","size"].each do |property_name|
      property = @project.all_property_definitions.find_by_name(property_name)
      property.update_attributes(:description => "This property is used for indicating " + "#{property_name} " + "of each card.")
      tooltips[property_name] = property.name + ": " + property.description
    end

    navigate_to_grid_view_for(@project )
    set_the_filter_value_option(0,'Card')

    group_columns_by('status')
    grid_sort_by('owner')
    color_by("priority")
    change_lane_heading('Average', 'size')

    @browser.assert_element_present("css=div.group_columns_by_actions a[title='#{tooltips["status"]}']")
    @browser.assert_element_present("css=div.sort-by-actions-group a[title='#{tooltips["owner"]}']")
    @browser.assert_element_present("css=div.color-by-actions-group a[title='#{tooltips["priority"]}']")
    @browser.assert_element_present("css=#aggregate_type_column_form a[title='#{tooltips["size"]}']")
  end

  # this is a flaky test... need to figureout we have other tests does same thing...
  # def test_the_drop_list_for_group_by_sort_by_and_color_by
  #   navigate_to_grid_view_for(@project)
  #   set_the_filter_value_option(0,'Card')
  #
  #   assert_properties_present_on_group_columns_by_drop_down_list('Type', 'status','priority', 'size', 'owner', 'tree - first')
  #   assert_properties_not_present_on_group_columns_by_drop_down_list('address', 'iteration','started on', 'dependency', 'formula', 'aggregate')
  #   group_columns_by('status')
  #   assert_properties_not_present_on_sort_by_drop_down_list('address', 'iteration','started on', 'dependency', 'formula', 'aggregate')
  #   assert_properties_present_on_sort_by_drop_down_list('Number', 'Rank', 'Type', 'status', 'priority', 'size', 'owner', 'tree - first')
  #   grid_sort_by('size')
  #   assert_properties_present_on_color_by_drop_down_list('Type','status','priority','size')
  #   assert_properties_not_present_on_color_by_drop_down_list('owner','address','iteration','started on', 'dependency', 'formula','tree - first', 'aggregate')
  # end

  def test_sort_by_and_color_by_work_independently
    create_some_cards_with_different_property_value

    navigate_to_grid_view_for(@project)
    set_the_filter_value_option(0,'Card')
    group_columns_by('status')
    assert_colored_by(NOT_SET)
    assert_grid_sort_by(RANK)
    assert_ordered('card_4','card_5', 'card_6')
    assert_ordered('card_1', 'card_2', 'card_3')
    assert_cards_have_no_color(1,2,3,4,5,6)

    grid_sort_by('size')
    assert_grouped_by('status')
    assert_colored_by(NOT_SET)
    assert_ordered('card_4', 'card_5', 'card_6')
    assert_ordered('card_1', 'card_2', 'card_3')
    assert_cards_have_no_color(1,2,3,4,5,6)


    color_by('priority')
    value_high = @project.find_enumeration_value('priority', 'high', :with_hidden => true)
    value_medium = @project.find_enumeration_value('priority', 'medium', :with_hidden => true)
    change_color(value_high, RED)
    change_color(value_medium, BLUE)
    assert_grouped_by('status')
    assert_grid_sort_by('size')
    assert_ordered('card_4', 'card_5', 'card_6')
    assert_ordered('card_1', 'card_2', 'card_3')
    assert_card_color(RED, 1)
    assert_card_color(RED, 3)
    assert_card_color(RED, 4)
    assert_card_color(RED, 6)
    assert_card_color(BLUE, 2)
    assert_card_color(BLUE, 5)

    ungroup_by_columns_in_grid_view
    assert_colored_by('priority')
    assert_grid_sort_by('size')
    assert_ordered('card_4','card_1', 'card_5','card_2', 'card_6','card_3')
    assert_card_color(RED, 1)
    assert_card_color(RED, 3)
    assert_card_color(RED, 4)
    assert_card_color(RED, 6)
    assert_card_color(BLUE, 2)
    assert_card_color(BLUE, 5)
  end

  def test_card_color_should_be_the_same_with_its_color_by_property_value
    create_some_cards_with_different_property_value
    priority_definition = @project.find_property_definition('priority')
    @browser.open "/projects/#{@project.identifier}/enumeration_values/list?definition_id=#{priority_definition.id}"
    value_high = @project.find_enumeration_value('priority', 'high', :with_hidden => true)
    value_medium = @project.find_enumeration_value('priority', 'medium', :with_hidden => true)
    change_color(value_high, RED)
    change_color(value_medium, BLUE)


    navigate_to_grid_view_for(@project, :"filters[]" => '[Type][is][Card]',:group_by => 'status', :color_by => 'priority')
    assert_card_color(RED, 1)
    assert_card_color(BLUE, 2)
    assert_card_color(RED, 3)
    assert_card_color(RED, 4)
    assert_card_color(BLUE, 5)
    assert_card_color(RED, 6)

    navigate_to_card(@project, 'card3')
    edit_card(:priority => '(not set)')
    click_up_link
    assert_card_has_no_color(3)

    navigate_to_card(@project, 'card3')
    edit_card(:priority => 'medium')
    click_up_link
    assert_card_color(BLUE, 3)

    value_medium = @project.find_enumeration_value('priority', 'medium', :with_hidden => true)
    change_color(value_medium, GREY)
    assert_card_color(RED, 1)
    assert_card_color(GREY, 2)
    assert_card_color(GREY, 3)
    assert_card_color(RED, 4)
    assert_card_color(GREY, 5)
    assert_card_color(RED, 6)
  end

  def test_cards_should_be_order_of_the_enum_values_of_sort_by_property_according_to_the_management_page
    create_some_cards_with_different_property_value
    navigate_to_grid_view_for(@project, :"filters[]" => '[Type][is][Card]',:group_by => 'status', :grid_sort_by => 'priority')
    assert_ordered('card_6', 'card_4', 'card_5')
    assert_ordered('card_3', 'card_1', 'card_2')

    navigate_to_card(@project, 'card1')
    edit_card(:priority => 'medium')
    click_up_link
    assert_ordered('card_3', 'card_2', 'card_1')
  end

  def test_relationship_property_is_supported_in_sort_by
    create_some_cards_and_added_onto_tree
    navigate_to_grid_view_for(@project, :"filters[]" => '[Type][is][Card]',:group_by => 'status')
    assert_ordered('card_1', 'card_2', 'card_3', 'card_4')
    grid_sort_by('tree - first')
    assert_ordered('card_3', 'card_1', 'card_2', 'card_4')
  end

  private
  def create_some_cards_and_added_onto_tree
    card_1 = create_card!(:card_type => @card_type, :name => 'card1')
    card_2 = create_card!(:card_type => @card_type, :name => 'card2')
    card_3 = create_card!(:card_type => @card_type, :name => 'card3')
    card_4 = create_card!(:card_type => @card_type, :name => 'card4')
    card_5 = create_card!(:card_type => @super_card_type, :name => 'z name')
    card_6 = create_card!(:card_type => @super_card_type, :name => 'y name')
    card_7 = create_card!(:card_type => @super_card_type, :name => 'x name')
    add_card_to_tree(@tree,card_5)
    add_card_to_tree(@tree,card_6)
    add_card_to_tree(@tree,card_7)
    add_card_to_tree(@tree, card_3, card_5)
    add_card_to_tree(@tree, card_1, card_5)

    add_card_to_tree(@tree, card_2, card_6)
    add_card_to_tree(@tree, card_4, card_7)
  end
  def create_some_cards_with_different_property_value
    @browser.open "/projects/#{@project.identifier}"
    create_card!(:name => 'card1', :status => 'open', :size => '1', :priority  => 'high')
    create_card!(:name => 'card2', :status => 'open', :size => '2', :priority  => 'medium')
    create_card!(:name => 'card3', :status => 'open', :size => '3', :priority  => 'high')
    create_card!(:name => 'card4', :status => 'closed', :size => '1', :priority  => 'high')
    create_card!(:name => 'card5', :status => 'closed', :size => '2', :priority  => 'medium')
    create_card!(:name => 'card6', :status => 'closed', :size => '3', :priority  => 'high')
  end
end
