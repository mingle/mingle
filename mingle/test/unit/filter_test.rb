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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class FilterTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def test_uses_property_value
    filters = Filters.new(@project, ["[status][is][open]"])
    assert filters.uses_property_value?("status", 'open')
    assert !filters.uses_property_value?("status", 'new')
  end

  def test_should_not_filter_out_cards_when_empty
    filters = Filters.new(@project, [])
    assert_equal [], filters.as_card_query_conditions
    assert_equal "", filters.to_s
  end

  def test_should_parse_valid_filter_string
    filter = Filters::Filter.new(@project, "[status][is][open]")
    assert_equal "Status is open", filter.as_card_query_conditions.to_s
  end

  def test_should_be_able_to_parse_a_user_property_condition
    filter = Filters::Filter.new(@project, "[dev][is][#{bob.login}]")
    assert_equal "dev is bob", filter.as_card_query_conditions.to_s
    assert_equal "[dev][is][#{bob.login}]", filter.to_params
  end

  def test_should_handle_is_not_operator
    filter = Filters::Filter.new(@project, "[status][is not][open]")
    assert_equal "Status is not open", filter.as_card_query_conditions.to_s
  end

  def test_should_understand_ignored_values
    ignored_filter = Filters::Filter.new(@project, "[status][is][#{PropertyValue::IGNORED_IDENTIFIER}]")
    assert_equal(PropertyValue::IGNORED_IDENTIFIER, ignored_filter.value)
    assert ignored_filter.ignored?
    assert !Filters::Filter.new(@project, "[status][is][]").ignored?
    assert !Filters::Filter.new(@project, "[status][is][open]").ignored?
  end

  def test_should_detect_if_property_is_card_type
    assert Filters::Filter.new(@project, "[type][is][open]").card_type_filter?
    assert !Filters::Filter.new(@project, "[status][is][open]").card_type_filter?
  end

  def test_empty_filter_value_should_be_set_to_ignore
    assert_equal "[][][#{PropertyValue::IGNORED_IDENTIFIER}]", Filters::Filter.empty(@project).to_params
  end

  def test_ignored_type_filter_has_no_value
    assert_nil Filters::Filter::type_filter(@project).value
  end

  def test_filters_to_params
    filter_strings = ["[Status][is][open]"]
    assert_equal(filter_strings, Filters.new(@project, filter_strings).to_params)
  end

  #bug #7527 Mingle throws exception when save project settings
  def test_filters_update_date_format_should_saftely_return_if_value_is_plv
    filters = Filters.new(@project, ["[start date][is][(date_plv)]"])
    assert_nothing_raised { filters.update_date_format('%d %b %Y', '%d %b %Y') }
  end

  def test_filters_update_date_format_should_saftely_return_if_value_is_today
    filters = Filters.new(@project, ["[start date][is][(today)]"])
    assert_nothing_raised { filters.update_date_format('%d %b %Y', '%d %b %Y') }
  end

  def test_filters_are_empty_if_they_contain_only_ignored_values
    assert Filters.new(@project, ["[TypE][iS][#{PropertyValue::IGNORED_IDENTIFIER}]"]).empty?
    assert Filters.new(@project, ["[TypE][iS][#{PropertyValue::IGNORED_IDENTIFIER}]", "[material][is not][#{PropertyValue::IGNORED_IDENTIFIER}]"]).empty?
    assert !Filters.new(@project, ["[TypE][iS][Card]", "[materIal][is not][golD]"]).empty?
    assert !Filters.new(@project, ["[TypE][iS][#{PropertyValue::IGNORED_IDENTIFIER}]", "[materIal][is not][golD]"]).empty?
    assert !Filters.new(@project, ["[TypE][iS][Card]", "[materIal][is not][#{PropertyValue::IGNORED_IDENTIFIER}]"]).empty?
  end

  def test_should_handle_enum_values_containing_brackets
    assert_equal "][", Filters::Filter.new(@project, "[status][is][][]").value
  end

  def test_should_throw_exception_if_filter_parameter_not_a_string
    [
     Filters.new(@project, ["random array"]),
     Filters.new(@project, "[malformed][parameter][")
    ].each do |filters|
      assert_equal 1, filters.errors.size
    end
  end

  def test_filter_equality_should_be_case_insensitive
    type_is_big_card = Filters.new(@project, ['[Type][is][Card]'])
    type_is_card = Filters.new(@project, ['[Type][is][card]'])
    assert type_is_big_card == type_is_card
  end

  def test_sql_should_group_property_definitions_and_apply_or_clause
    expected_sql = "(Status is open OR Status is closed) AND Type is card"
    assert_equal expected_sql, Filters.new(@project, ["[status][is][open]", "[Type][is][card]", "[status][is][closed]"]).as_card_query_conditions.collect(&:to_s).join(" AND ")
  end

  def test_should_show_default_columns_even_if_no_card_type_is_selected
    with_new_project do |project|
      assert_equal ["Type", "Created by", "Modified by"], Filters.new(project, []).valid_properties
    end
  end

  def test_should_allow_more_than_one_card_type_to_determine_valid_properties
    with_new_project do |project|
      project.card_types.destroy_all
      story = project.card_types.create!(:name => 'story')
      bug = project.card_types.create!(:name => 'bug')
      project.create_text_list_definition!(:name => 'story status').update_attributes(:card_types => [story])
      project.create_text_list_definition!(:name => 'common').update_attributes(:card_types => [story, bug])
      project.create_text_list_definition!(:name => 'bug status').update_attributes(:card_types => [bug])
      project.reload

      assert_equal ["Type", "common", "Created by", "Modified by"], Filters.new(project, ["[Type][is][story]", "[Type][is][bug]"]).valid_properties
    end
  end

  def test_should_allow_is_not_card_type_filters_to_determine_valid_properties
    with_new_project do |project|
      project.card_types.destroy_all
      story = project.card_types.create!(:name => 'story')
      bug = project.card_types.create!(:name => 'bug')
      risk = project.card_types.create!(:name => 'risk')

      project.create_text_list_definition!(:name => 'all prop').update_attributes(:card_types => [story, bug, risk])
      project.create_text_list_definition!(:name => 'story-bug prop').update_attributes(:card_types => [story, bug])
      project.create_text_list_definition!(:name => 'bug-risk prop').update_attributes(:card_types => [bug, risk])
      project.create_text_list_definition!(:name => 'story-risk prop').update_attributes(:card_types => [story, risk])
      project.create_text_list_definition!(:name => 'bug prop').update_attributes(:card_types => [bug])
      project.create_text_list_definition!(:name => 'story prop').update_attributes(:card_types => [story])
      project.create_text_list_definition!(:name => 'risk prop').update_attributes(:card_types => [risk])
      project.reload

      assert_equal ["Type", "all prop", "bug-risk prop", "Created by", "Modified by"], Filters.new(project, ["[Type][is not][story]"]).valid_properties
      assert_equal ["Type", "all prop", "bug-risk prop", "risk prop", "story-risk prop", "Created by", "Modified by"], Filters.new(project, ["[Type][is not][story]", "[Type][is not][bug]"]).valid_properties
    end
  end

  def test_should_allow_both_is_and_is_not_card_type_filters_to_determine_valid_properties
    with_new_project do |project|
      project.card_types.destroy_all
      story = project.card_types.create!(:name => 'story')
      bug = project.card_types.create!(:name => 'bug')
      risk = project.card_types.create!(:name => 'risk')

      project.create_text_list_definition!(:name => 'all prop').update_attributes(:card_types => [story, bug, risk])
      project.create_text_list_definition!(:name => 'story-bug prop').update_attributes(:card_types => [story, bug])
      project.create_text_list_definition!(:name => 'bug-risk prop').update_attributes(:card_types => [bug, risk])
      project.create_text_list_definition!(:name => 'story-risk prop').update_attributes(:card_types => [story, risk])
      project.create_text_list_definition!(:name => 'bug prop').update_attributes(:card_types => [bug])
      project.create_text_list_definition!(:name => 'story prop').update_attributes(:card_types => [story])
      project.create_text_list_definition!(:name => 'risk prop').update_attributes(:card_types => [risk])
      project.reload

      assert_equal ["Type", "all prop", "story-risk prop", "Created by", "Modified by"], Filters.new(project, ["[Type][is][story]", "[Type][is not][bug]"]).valid_properties
      assert_equal ["Type", "all prop", "story prop", "story-bug prop", "story-risk prop", "Created by", "Modified by"], Filters.new(project, ["[Type][is][story]", "[Type][is not][bug]", "[Type][is not][risk]"]).valid_properties
      assert_equal ["Type", "all prop", "story prop", "story-bug prop", "story-risk prop", "Created by", "Modified by"], Filters.new(project, ["[Type][is][story]", "[Type][is not][bug]", "[Type][is not][risk]", "[Type][is][risk]"]).valid_properties
    end
  end


  def test_should_produce_filter_hash_with_the_right_name_for_operator_and_value
    assert_to_hash({:property => 'Type', :operator => 'is', :value => PropertyValue::IGNORED_IDENTIFIER}, '[Type][IS][]')
    assert_to_hash({:property => 'Status', :operator => 'is not', :value => ''}, '[Status][IS Not][]')
    assert_to_hash({:property => 'start date', :operator => 'is before', :value => '12 Aug 2008'}, '[StArt daTe][IS less thAN][12 Aug 2008]')
    assert_to_hash({:property => 'start date', :operator => 'is after', :value => '12 Aug 2008'}, '[StArt daTe][IS greater THAN][12 Aug 2008]')
    assert_to_hash({:property => 'Status', :operator => 'is less than', :value => ''}, '[Status][IS Less Than][]')
    assert_to_hash({:property => 'Status', :operator => 'is greater than', :value => 'low'}, '[Status][Is After][low]')
  end

  def test_filter_built_with_type_specific_properties_with_crazy_casing_is_still_valid
    filters = Filters.new(@project, ["[TYPe][is][Card]", "[STATUs][is][open]"])
    assert !filters.invalid?
  end

  def test_filter_is_not_valid_when_unknown_enumeration_value_is_used
    assert Filters.new(@project, ['[Status][is][Timmy]']).invalid?
  end

  def test_filter_is_valid_when_enumeration_value_is_empty
    assert !Filters.new(@project, ['[Status][is][]']).invalid?
  end

  def test_filter_is_valid_when_enumeration_value_is_ignored
    assert !Filters.new(@project, ["[Status][is][#{PropertyValue::IGNORED_IDENTIFIER}]"]).invalid?
  end

  def test_should_drive_properties_for_group_by_and_color_by_from_current_filter_types
    with_new_project do |project|
      story = project.card_types.create!(:name => 'story')
      bug = project.card_types.create!(:name => 'bug')
      story_status = project.create_text_list_definition!(:name => 'story status')
      story_status.update_attributes(:card_types => [story])

      owner = project.create_user_definition!(:name => 'owner')
      owner.update_attributes(:card_types => [story, bug])

      bug_status = project.create_text_list_definition!(:name => 'bug status')
      bug_status.update_attributes(:card_types => [bug])
      project.reload

      assert_equal ["Type", "owner", 'story status'], Filters.new(project, ["[Type][is][story]"]).properties_for_group_by.collect(&:name)
      assert_equal ["Number", "Type", "owner", 'story status'], Filters.new(project, ["[Type][is][story]"]).properties_for_grid_sort_by.collect(&:name)
      assert_equal ["Type", 'story status'], Filters.new(project, ["[Type][is][story]"]).properties_for_colour_by.collect(&:name)
      assert_equal ["Type", "owner"], Filters.new(project, ["[Type][is][story]", "[Type][is][bug]"]).properties_for_group_by.collect(&:name)
      assert_equal ["Number", "Type", "owner"], Filters.new(project, ["[Type][is][story]", "[Type][is][bug]"]).properties_for_grid_sort_by.collect(&:name)
      assert_equal ["Type"], Filters.new(project, ["[Type][is][story]", "[Type][is][bug]"]).properties_for_colour_by.collect(&:name)
    end
  end

  def test_should_drive_properties_for_aggregate_by_from_current_filter_types
    with_new_project do |project|
      story_size = setup_numeric_property_definition('story size', [1, 2, 4, 8, 16])
      bug_priority = setup_numeric_property_definition('bug priority', [1, 2, 3])
      non_numeric = setup_text_property_definition('not numeric')

      story = project.card_types.create!(:name => 'story')
      story.property_definitions = [story_size, non_numeric]
      bug = project.card_types.create!(:name => 'bug')
      bug.property_definitions = [bug_priority, non_numeric]

      assert_equal ["story size"], Filters.new(project, ["[Type][is][story]"]).properties_for_aggregate_by.collect(&:name)
      assert_equal ["bug priority"], Filters.new(project, ["[Type][is][bug]"]).properties_for_aggregate_by.collect(&:name)
      assert_equal ["story size", "bug priority"].sort, Filters.new(project, ["[Type][is][story]", "[Type][is][bug]"]).properties_for_aggregate_by.collect(&:name).sort
      assert_equal ["story size", "bug priority"].sort, Filters.new(project, []).properties_for_aggregate_by.collect(&:name).sort
    end
  end

  # bug 4505
  def test_properties_for_aggregate_by_should_include_formulas_and_free_numerics_and_aggregates
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types

      numeric_text = setup_numeric_text_property_definition('numeric text')
      formula = setup_formula_property_definition('formula', '5 + 3')
      numeric_enum = setup_numeric_property_definition('numeric', [1, 2, 3])
      aggregate = setup_aggregate_property_definition('agg', AggregateType::SUM, numeric_enum, configuration.id, type_iteration.id, AggregateScope::ALL_DESCENDANTS)

      type_iteration.add_property_definition(numeric_text)
      type_iteration.add_property_definition(formula)
      type_iteration.add_property_definition(numeric_enum)

      assert_equal ["numeric text", "formula", "numeric", "agg"].sort, Filters.new(project, ["[Type][is][iteration]"]).properties_for_aggregate_by.collect(&:name).sort
    end
  end

  def test_should_drive_column_properties_from_current_filter_types
    with_new_project do |project|
      story = project.card_types.create!(:name => 'story')
      bug = project.card_types.create!(:name => 'bug')
      other = project.card_types.create!(:name => 'other')

      story_status = project.create_text_list_definition!(:name => 'story status')
      story_status.update_attributes(:card_types => [story])

      owner = project.create_user_definition!(:name => 'owner')
      owner.update_attributes(:card_types => [story, bug])

      bug_status = project.create_text_list_definition!(:name => 'bug status')
      bug_status.update_attributes(:card_types => [bug])

      other_status = project.create_text_list_definition!(:name => 'other status')
      other_status.update_attributes(:card_types => [other])
      project.reload

      assert_equal ["Type", "bug status", "other status", "owner", "story status", "Created by", "Modified by"], Filters.new(project, []).column_properties.collect(&:name)
      assert_equal ["Type", "owner", "story status", "Created by", "Modified by"], Filters.new(project, ["[Type][is][story]"]).column_properties.collect(&:name)
      assert_equal ["Type", "bug status", "owner", "Created by", "Modified by"], Filters.new(project, ["[Type][is][bug]"]).column_properties.collect(&:name)
      assert_equal ["Type", "bug status", "owner", "story status", "Created by", "Modified by"], Filters.new(project, ["[Type][is][story]", "[Type][is][bug]"]).column_properties.collect(&:name)
    end
  end

  def test_has_same_or_fewer_property_definitions_as
    all_things = Filters.new(@project, ["[Type][is][(any)]"])
    open_things = Filters.new(@project, ["[Type][is][(any)]", "[Status][is][open]"])
    not_closed_things = Filters.new(@project, ["[Type][is][(any)]", "[STATus][is not][closed]"])
    open_and_closed_things = Filters.new(@project, ["[Type][is][(any)]", "[Status][is][closed]", "[StaTus][is][open]"])

    assert all_things.has_same_or_fewer_property_definitions_as?(all_things)
    assert all_things.has_same_or_fewer_property_definitions_as?(open_things)
    assert all_things.has_same_or_fewer_property_definitions_as?(not_closed_things)
    assert all_things.has_same_or_fewer_property_definitions_as?(open_and_closed_things)
    assert !open_things.has_same_or_fewer_property_definitions_as?(all_things)
    assert !open_and_closed_things.has_same_or_fewer_property_definitions_as?(all_things)
    assert open_and_closed_things.has_same_or_fewer_property_definitions_as?(open_things)
    assert open_and_closed_things.has_same_or_fewer_property_definitions_as?(not_closed_things)
    assert open_and_closed_things.has_same_or_fewer_property_definitions_as?(open_and_closed_things)
  end

  def test_filter_by_current_user
    @project.cards.find_by_name('first card').update_attribute(:cp_dev_user_id, bob.id)
    @project.cards.find_by_name('another card').update_attribute(:cp_dev_user_id, proj_admin.id)

    login bob.email
    filter = Filters::Filter.new(@project, "[dev][is][#{PropertyType::UserType:: CURRENT_USER.downcase}]")
    assert_equal "dev IS CURRENT USER", filter.as_card_query_conditions.to_s
    assert_equal ['first card'], find_cards(filter)
  end

  def test_filter_by_not_current_user
    @project.cards.find_by_name('first card').update_attribute(:cp_dev_user_id, bob.id)
    @project.cards.find_by_name('another card').update_attribute(:cp_dev_user_id, proj_admin.id)

    login bob.email

    filter = Filters::Filter.new(@project, "[dev][is not][#{PropertyType::UserType:: CURRENT_USER}]")
    assert_equal "dev is not bob", filter.as_card_query_conditions.to_s
    assert_equal ['another card'], find_cards(filter)
  end

  def test_filter_by_today
    Clock.now_is(:year => 2007, :month => 7, :day => 6, :hour => 12, :minute => 34) do
      filter = Filters::Filter.new(@project, "[start date][is][#{PropertyType::DateType::TODAY}]")
      assert_equal "'start date' is TODAY", filter.as_card_query_conditions.to_s
    end
  end

  def test_date_filter_by_is_after
    filter = Filters::Filter.new(@project, "[start date][is after][02 Oct 2003]")
    assert_equal "'start date' is greater than '02 Oct 2003'", filter.as_card_query_conditions.to_s
  end

  def test_date_filter_by_is_before
    filter = Filters::Filter.new(@project, "[start date][is before][02 Oct 2003]")
    assert_equal "'start date' is less than '02 Oct 2003'", filter.as_card_query_conditions.to_s
  end

  def test_should_convert_to_card_query_with_greater_than_operator
    filters = Filters.new(@project, ["[iTerAtion][is GreAter tHan][1]"])
    iteration_1_position = position_of_property_value(@project, 'iteration', '1')

    assert_equal 1, filters.as_card_query_conditions.length
    assert_equal 'Iteration is greater than 1', filters.as_card_query_conditions.join
  end

  def test_should_convert_to_card_query_with_less_than_operator
    filters = Filters.new(@project, ["[iTerAtion][is lEsS tHan][2]"])
    iteration_1_position = position_of_property_value(@project, 'iteration', '2')

    assert_equal 1, filters.as_card_query_conditions.length
    assert_equal 'Iteration is less than 2', filters.as_card_query_conditions.join
  end

  def test_should_convert_to_card_query_with_correct_operator
    filters = Filters.new(@project, ["[Type][is][CarD]", "[STaTUS][is NOT][open]"])
    card_type_position = @project.card_types.detect {|ct| ct.name == 'Card'}.position
    status_open_position = @project.find_property_definition('status').enumeration_values.detect {|p| p.value == 'open' }.position

    assert_equal 2, filters.as_card_query_conditions.length
    assert_equal 'Status is not open', filters.as_card_query_conditions[0].to_s
    assert_equal 'Type is CarD', filters.as_card_query_conditions[1].to_s
  end

  def test_to_sql_should_and_together_multiple_is_not_filters
    filters = Filters.new(@project, ["[staTus][is nOt][fiXed]", "[sTatus][iS not][nEw]"])
    status_fixed_position = position_of_property_value(@project, 'status', 'fixed')
    status_new_position = position_of_property_value(@project, 'status', 'new')

    expected_sql = "(Status is not fiXed AND Status is not nEw)"
    assert_equal expected_sql, filters.as_card_query_conditions.join
  end

  def test_to_sql_should_or_together_is_and_is_not_filters
    filters = Filters.new(@project, ["[staTus][is][fiXed]", "[sTatus][iS not][nEw]"])
    status_fixed_position = position_of_property_value(@project, 'status', 'fixed')
    status_new_position = position_of_property_value(@project, 'status', 'new')

    expected_sql = "(Status is fiXed OR Status is not nEw)"
    assert_equal expected_sql, filters.as_card_query_conditions.join
  end

  def test_valid_properties_should_be_empty_when_all_types_explicitly_excluded
    # this is required so that card_list_view#valid_columns doesn't blow up.
    filters = Filters.new(@project, ["[type][is not][Card]"])

    assert_equal [], filters.valid_properties
  end

  def test_equality
    assert_equal Filters.new(@project, ["[Type][is][story]", "[Status][is][open]"]),
          Filters.new(@project, ["[Type][is][story]", "[Status][is][open]"])

    assert_equal Filters.new(@project, ["[Type][is][story]", "[Status][is][open]"]),
          Filters.new(@project, ["[Status][is][open]", "[Type][is][story]"])

    assert_not_equal Filters.new(@project, ["[Status][is][open]", "[Type][is][story]"]),
          Filters.new(@project, ["[Status][is][open]", "[Type][is][card]"])
  end

  def test_description_should_show_not_set_instead_of_blank
    filters = Filters.new(@project, ["[Type][is][]", "[Status][is][]", "[dev][is][]", "[start date][is][]"])
    assert_equal "dev is #{'(not set)'.bold} and start date is #{'(not set)'.bold} and Status is #{'(not set)'.bold} and Type is #{'(not set)'.bold}", filters.description_without_header
  end

  def test_description_should_show_is_not_operator
    filters = Filters.new(@project, ["[Type][is not][story]"])
    assert_equal "Type is not #{'story'.bold}", filters.description_without_header
  end

  def test_description_should_group_is_and_is_not_together
    filters = Filters.new(@project, ["[Type][is][story]", "[status][is][new]", "[status][is not][fixed]", "[status][is][open]", "[status][is not][closed]"])
    description = filters.description
    # have to assert the description piece-meal because of sorting differences between MRI and JRuby.
    assert description.include?("Status is #{'new'.bold} or #{'open'.bold}")
    assert description.include?("and Status is not #{'closed'.bold}")
    assert description.include?("and Status is not #{'fixed'.bold}")
    assert description.include?("and Type is #{'story'.bold}")
  end

  def test_description_should_show_less_than_and_greater_than_for_enumerated_properties
    filters = Filters.new(@project, ["[iteration][is less than][2]", "[iteration][is greater than][1]"])
    assert_equal "Iteration is less than #{'2'.bold} and Iteration is greater than #{'1'.bold}", filters.description_without_header
  end

  def test_description_should_show_before_and_after_for_date_properties
    filters = Filters.new(@project, ["[start date][is after][02 Oct 2003]", "[start date][is before][05 Oct 2003]"])
    assert_equal "start date is after #{'02 Oct 2003'.bold} and start date is before #{'05 Oct 2003'.bold}", filters.description_without_header
  end

  def test_should_set_the_type_to_the_first_card_type_when_no_card_type_is_specified_in_the_filter_when_finding_first_available_card_type
    @project.with_active_project do |project|
      project.card_types.create!(:name => 'bug')
      project.card_types.create!(:name => 'risk')

      filters = Filters.new(project, ["[Type][is][(any)]"])
      first_card_type = project.card_types.first
      assert_equal first_card_type, filters.find_first_available_card_type
    end
  end

  def test_should_set_the_type_to_the_second_card_type_when_first_card_type_is_explicitly_excluded_when_finding_first_available_card_type
    @project.with_active_project do |project|
      project.card_types.create!(:name => 'bug')
      project.card_types.create!(:name => 'risk')

      filters = Filters.new(project, ["[Type][is not][#{project.card_types.first.name}]"])
      second_card_type = project.card_types[1]
      assert_equal second_card_type, filters.find_first_available_card_type
    end
  end

  def test_should_find_first_card_type_if_all_card_types_are_explicitly_excluded
    @project.with_active_project do |project|
      project.card_types.create!(:name => 'bug')
      project.card_types.create!(:name => 'risk')

      exclude_all_card_types_filter = project.card_types.collect {|card_type| "[Type][is not][#{card_type.name}]"}
      filters = Filters.new(project, exclude_all_card_types_filter)
      assert_equal project.card_types.first, filters.find_first_available_card_type
    end
  end

  def test_should_perform_dirty_checks_only_against_complete_filters
    stories = Filters.new(@project, ["[Type][is][story]"])
    iteration_undecided_stories = Filters.new(@project, ["[Type][is][story]", "[Iteration][is][#{PropertyValue::IGNORED_IDENTIFIER}]"])
    iteration_1_stories = Filters.new(@project, ["[Type][is][story]", "[Iteration][is][1]"])

    assert !stories.dirty_compared_to?(iteration_undecided_stories)
    assert stories.dirty_compared_to?(iteration_1_stories)
    assert iteration_1_stories.dirty_compared_to?(iteration_undecided_stories)
  end

  def test_should_be_invalid_when_bad_date_given_for_filter
    filter = Filters.new(@project, ["[Material][is][gold]", "[start date][is][44 Oct 2007]"])
    assert filter.invalid?
    assert_equal ["Property #{'start date'.bold} #{'44 Oct 2007'.bold} is an invalid date. Enter dates in #{'dd mmm yyyy'.bold} format or enter existing project variable which is available for this property."], filter.validation_errors
  end

  def test_prop_value_is_invalid_plv
    filter = Filters.new(@project, ["[Iteration][is][(not exist plv)]"])
    assert filter.invalid?
    assert_equal 1, filter.validation_errors.size
    prop = @project.find_property_definition('Iteration')
    assert_equal [prop.to_card_query('(not exist plv)', 'is').to_s], filter.as_card_query_conditions.map(&:to_s)
  end

  def test_contains_filter_for_property_definition_name_should_be_case_insensitive
    filter = Filters.new(@project, ['[MatErIAL][iS][GoLd]'])
    assert filter.contains_filter_for_property_definition_name('MaTERial')
  end

  def test_should_return_the_card_type_that_is_in_the_filter
    @project.with_active_project do |project|
      project.card_types.create!(:name => 'bug')
      project.card_types.create!(:name => 'risk')
      filter = Filters.new(@project, ['[tYpE][iS][rIsk]'])
      expected_card_type = @project.card_types.find_by_name('risk')
      assert_equal expected_card_type, filter.card_type
    end
  end

  def test_should_return_the_first_card_type_when_no_card_type_is_specified_in_the_filter
    @project.with_active_project do |project|
      project.card_types.create!(:name => 'bug')
      project.card_types.create!(:name => 'risk')
      filter = Filters.new(@project, ['[material][iS][gold]'])
      expected_card_type = @project.card_types.first
      assert_equal expected_card_type, filter.card_type
    end
  end

  def test_uses_property_definition_should_look_for_property_definition_in_filters
    filters = Filters.new(@project, ['[Type][is][card]', '[Material][is not][gold]'])
    assert filters.uses_property_definition?(@project.find_property_definition('Material'))
    assert !filters.uses_property_definition?(@project.find_property_definition('Iteration'))
  end

  def test_filter_with_normal_plv
    iteration = @project.find_property_definition('iteration')
    current_iteration_plv = create_plv!(@project, :name => 'current iteration', :value => '15', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [iteration.id])
    filters = Filters.new(@project, ['[Type][is][card]', '[Iteration][is][(current iteration)]'])
    assert_equal [], filters.validation_errors
    card1 = create_card!(:name => 'iteration1 story', :iteration => '15')
    card2 = create_card!(:name => 'iteration1 story', :iteration => '16')
    assert_filter_results [card1.name], filters
    assert_equal([current_iteration_plv], filters.project_variables_used)
  end

  def test_filter_with_card_type_plv
    create_tree_project(:init_three_level_tree) do |project, n, config|
      iteration = project.find_property_definition('planning iteration')
      iteration_type = project.card_types.find_by_name('iteration')
      create_plv!(project, :name => 'current iteration', :value => n['iteration1'].id, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => iteration_type, :property_definition_ids => [iteration.id])
      filters = Filters.new(project, ['[Type][is][story]', '[Planning Iteration][is][(current iteration)]'])
      assert_filter_results ['story1', 'story2'], filters
    end
  end

  # bug 3503
  def test_filter_with_card_type_plv_does_not_throw_exception_when_asked_for_description
    create_tree_project(:init_three_level_tree) do |project, tree, config|
      iteration = project.find_property_definition('planning iteration')
      iteration_type = project.card_types.find_by_name('iteration')
      create_plv!(project, :name => 'current iteration', :value => tree['iteration1'].id, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => iteration_type, :property_definition_ids => [iteration.id])
      project.reload
      filters = Filters.new(project, ['[Type][is][story]', '[Planning Iteration][is][(current iteration)]'])
      assert_equal "Planning iteration is #{'(current iteration)'.bold} and Type is #{'story'.bold}", filters.description_without_header
    end
  end

  def test_filter_with_date_plv
    start_date = @project.find_property_definition('start date')
    create_plv!(@project, :name => 'milestone', :value => '01/01/2008', :data_type => ProjectVariable::DATE_DATA_TYPE, :property_definition_ids => [start_date.id])
    filters = Filters.new(@project, ['[Type][is][Card]', '[start date][is before][(milestone)]'])
    assert_equal [], filters.validation_errors
    card1 = create_card!(:name => 'new story', 'start date' => '01/02/2008')
    card2 = create_card!(:name => 'old story', 'start date' => '01/01/2007')

    assert_filter_results [card2.name], filters
  end

  def test_filter_with_tree_prop_def
    create_tree_project(:init_three_level_tree) do |project, n, config|
      iteration1 = project.cards.find_by_name("iteration1")
      iteration = project.find_property_definition('planning iteration')
      iteration_type = project.card_types.find_by_name('iteration')
      filters = Filters.new(project, ["[Planning Iteration][is][#{iteration1.number}]"])
      assert_equal ["#2 iteration1", "2"], filters[0].value_value
    end
  end

  def test_should_figure_out_undefined_plv
    filters = Filters.new(@project, ['[Type][is][card]', '[Iteration][is][(current iteration)]'])
    assert_equal ["Project variable #{'(current iteration)'.bold} is undefined."], filters.validation_errors
  end

  def assert_filter_results(expected_card_names, filters)
    query = CardQuery.new(:conditions => CardQuery::And.new(filters.as_card_query_conditions))
    assert_equal expected_card_names.sort, query.find_cards.collect(&:name).sort
  end

  # bug 2695.
  def test_card_type_warning_should_be_case_insensitive
    with_new_project do |project|
      login_as_member
      card_type = project.card_types.find_by_name('Card')
      defect_type = project.card_types.create(:name => 'dEfect')
      story_type = project.card_types.create(:name => 'story')
      setup_property_definitions :status => ['open', 'close']
      status = project.find_property_definition('status')
      status.card_types = [defect_type, story_type]
      status.save!
      project.reload
      filter = Filters.new(project, ["[Type][is not][card]", "[status][is][open]"])
      assert_equal [], filter.validation_errors
    end
  end

  def test_description_should_use_correct_case_regardless_of_what_case_is_passed
    assert_equal "Type is #{'Card'.bold}", Filters.new(@project, ['[TyPe][iS][CaRd]']).description_without_header
    assert_equal "Material is #{'gold'.bold} and Type is #{'Card'.bold}", Filters.new(@project, ['[TyPe][iS][CaRd]', '[MaTerIal][Is][gOlD]']).description_without_header
  end

  def test_value_value_for_users
    with_first_project do |project|
      dev_filter = Filters::Filter.new(project, '[dev][is][(current user)]')
      assert_equal UserPropertyDefinition.current, dev_filter.value_value
      dev_filter = Filters::Filter.new(project, "[dev][is][#{bob.login}]")
      assert_equal [bob.name, bob.login], dev_filter.value_value
    end
  end

  def test_value_value_for_dates
    with_first_project do |project|
      start_date_filter = Filters::Filter.new(project, '[start date][is][(today)]')
      assert_equal DatePropertyDefinition.current, start_date_filter.value_value
      date = '13 Mar 2008'
      start_date_filter = Filters::Filter.new(project, "[start date][is][#{date}]")
      assert_equal [date, date], start_date_filter.value_value
    end
  end

  def test_value_value_for_tree_relationship
    create_tree_project(:init_three_level_tree) do |project, tree, relationship|
      type_release, type_iteration, type_story = find_planning_tree_types
      iteration1 = project.cards.find_by_name('iteration1')
      iteration1_filter = Filters::Filter.new(project, "[planning iteration][is][#{iteration1.number}]")
      assert_equal ["##{iteration1.number} iteration1", "#{iteration1.number}"], iteration1_filter.value_value

      current_iteration = create_plv!(project, :name => 'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_iteration)
      current_iteration_filter = Filters::Filter.new(project, "[planning iteration][is][(current iteration)]")
      assert_equal ['(current iteration)', '(current iteration)'], current_iteration_filter.value_value
    end
  end

  # Bug 3487
  def test_should_display_plv_name_with_description_for_user_properties
    dev_property_definition = @project.find_property_definition('dev')
    create_plv!(@project, :name => 'build cop', :data_type => ProjectVariable::USER_DATA_TYPE, :value => bob.id, :property_definition_ids => [dev_property_definition.id])
    @project.reload
    filters = Filters.new(@project, ['[Type][is][card]', '[dev][is][(build cop)]'])
    assert_equal "dev is #{'(build cop)'.bold} and Type is #{'Card'.bold}", filters.description_without_header
  end

  # Bug 3507
  def test_should_display_current_user_for_description_but_not_login
    dev_property_definition = @project.find_property_definition('dev')
    filters = Filters.new(@project, ['[Type][is][card]', '[dev][is][(current user)]'])
    assert_equal "dev is #{'(current user)'.bold} and Type is #{'Card'.bold}", filters.description_without_header
  end

  # Bug 3431
  def test_should_give_error_message_on_type_mismatch_of_property_definition_and_plv
    dev_property_definition = @project.find_property_definition('dev')
    create_plv!(@project, :name => 'dude', :data_type => ProjectVariable::USER_DATA_TYPE, :value => bob.id, :property_definition_ids => [dev_property_definition.id])

    release_property_definition = @project.find_property_definition('release')
    create_plv!(@project, :name => "dude's number", :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => 1, :property_definition_ids => [release_property_definition.id])

    filters = Filters.new(@project, ['[Type][is][card]', "[dev][is][(dude's number)]"])
    assert filters.invalid?
    assert_equal ["Project variable #{"(dude's number)".bold} is not valid for the property #{'dev'.bold}."], filters.validation_errors
  end

  def test_should_allow_for_card_relationship_properties_in_filters
    with_new_project do |project|
      iteration_type = project.card_types.create!(:name => 'iteration')
      card_type = project.card_types.find_by_name('Card')

      analysis_iteration = setup_card_relationship_property_definition('analysis iteration')
      development_iteration = setup_card_relationship_property_definition('development iteration')
      card_type.property_definitions = [analysis_iteration, development_iteration]
      card_type.save!

      iteration_one = project.cards.create!(:name => 'I1', :card_type => iteration_type)
      iteration_two = project.cards.create!(:name => 'I2', :card_type => iteration_type)

      card_one = project.cards.create!(:name => 'Card One', :card_type => card_type, :cp_analysis_iteration => iteration_one, :cp_development_iteration => iteration_one)
      card_two = project.cards.create!(:name => 'Card Two', :card_type => card_type, :cp_analysis_iteration => iteration_two, :cp_development_iteration => iteration_two)
      card_three = project.cards.create!(:name => 'Card Three', :card_type => card_type, :cp_analysis_iteration => iteration_one, :cp_development_iteration => iteration_two)

      assert_equal [card_three.name, card_one.name], filtered_cards(project, '[Type][is][Card]', "[analysis iteration][is][#{iteration_one.number}]")
      assert_equal [card_three.name, card_two.name], filtered_cards(project, '[Type][is][Card]', "[development iteration][is][#{iteration_two.number}]")
      assert_equal [card_three.name], filtered_cards(project, '[Type][is][Card]', "[development iteration][is][#{iteration_two.number}]", "[analysis iteration][is][#{iteration_one.number}]")
    end
  end

  def test_should_be_able_to_detect_if_filter_uses_a_card_relationship_property
    with_card_query_project do |project|
      card = project.cards.first
      assert Filters.new(project, ["[related card][is][#{card.number}]"]).uses_card?(card)
      assert !Filters.new(project, ["[related card][is][#{card.number+1}]"]).uses_card?(card)
    end
  end

  def test_should_be_invalid_when_unknown_user_used
    filters = Filters.new(@project, ['[dev][is][an_invalid_login]'])
    assert filters.invalid?
    assert_equal ["#{'an_invalid_login'.bold} is an unknown user."], filters.validation_errors
  end

  def test_not_set_is_a_valid_user
    filters = Filters.new(@project, ['[dev][is][]'])
    assert !filters.invalid?
    assert_equal [], filters.validation_errors
  end

  def test_should_be_invalid_when_tree_relationship_deleted_card_is_used
    with_three_level_tree_project do |project|
      filters = Filters.new(project, ['[type][is][story]', '[planning iteration][is][an_invalid_iteration]'])
      assert filters.invalid?
      assert_equal ["#{'an_invalid_iteration'.bold} is an unknown card."], filters.validation_errors
    end
  end

  def test_not_set_is_a_valid_tree_relationship_card
    with_three_level_tree_project do |project|
      filters = Filters.new(project, ['[type][is][story]', '[planning iteration][is][]'])
      assert !filters.invalid?
      assert_equal [], filters.validation_errors
    end
  end

  def test_should_be_invalid_when_card_relationship_deleted_card_is_used
    with_card_query_project do |project|
      filters = Filters.new(project, ['[type][is][card]', '[related card][is][an_invalid_iteration]'])
      assert filters.invalid?
      assert_equal ["#{'an_invalid_iteration'.bold} is an unknown card."], filters.validation_errors
    end
  end

  def test_not_set_is_a_valid_card_relationship_card
    with_card_query_project do |project|
      filters = Filters.new(project, ['[type][is][card]', '[related card][is][]'])
      assert !filters.invalid?
      assert_equal [], filters.validation_errors
    end
  end

  private

  def filtered_cards(project, *filter_strings)
    CardListView.find_or_construct(project.reload, :filters => filter_strings).cards.collect(&:name)
  end

  def assert_to_hash(expected_hash, filter_string)
    assert_equal expected_hash, Filters::Filter.new(@project, filter_string).to_hash
  end

  def find_cards(filter)
    CardQuery.new(:conditions => filter.as_card_query_conditions).find_cards.collect(&:name)
  end

  def bob
    User.find_by_login('bob')
  end

  def proj_admin
    User.find_by_login('proj_admin')
  end
end
