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

class MqlFiltersTest < ActiveSupport::TestCase

  INVALID_FILTER_MQL = "this is an invalid filter"

  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def test_should_not_allow_anything_other_than_conditions_in_the_mql_condtions
    assert !MqlFilters.new(@project, "status=open").invalid?
    assert MqlFilters.new(@project, "SELECT number").invalid?
  end

  def test_filter_with_empty_mql
    assert !MqlFilters.new(@project, "").invalid?
    assert MqlFilters.new(@project, "").as_card_query_conditions.compact.empty?
  end

  def test_rename_property_updates_mql_filters
    with_new_project do |p|
      setup_property_definitions :feeture => ['cards']
      view = p.card_list_views.create_or_update(:view => {:name => 'view 1'}, :filters => {:mql => 'Feeture = cards'})

      view.rename_property('feeture', 'Feature')
      assert_equal("Feature = cards", view.to_params[:filters][:mql])
    end
  end

  def test_rename_property_updates_mql_filters_with_number_in_clauses
    with_new_project do |p|
      setup_card_relationship_property_definition 'associated bug'
      view = p.card_list_views.create_or_update(:view => {:name => 'view 1'}, :filters => {:mql => "'associated bug' NUMBER IN (8,9)"})

      view.rename_property('associated bug', 'defect')
      assert_equal("defect NUMBER IN (8, 9)", view.to_params[:filters][:mql])
    end
  end

  def test_should_rename_property_value_and_update_mql_filter_correctly
    with_new_project do |p|
      setup_property_definitions :feature => ['cards', 'api']
      view = p.card_list_views.create_or_update(:view => {:name => 'view 1'}, :filters => {:mql => 'feature = cards or feature = Api'})

      view.rename_property_value('feature', 'api', 'application interface')
      assert_equal("((feature = cards) OR (feature = 'application interface'))", view.to_params[:filters][:mql])
    end
  end

  def test_should_rename_plv_usage_when_name_of_plv_changes
    with_new_project do |p|
      setup_property_definitions :feature => ['cards', 'api']
      create_plv!(p, :name => 'tech feature', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'api', :property_definition_ids => [p.find_property_definition('feature').id])

      view = p.card_list_views.create_or_update(:view => {:name => 'tech features'}, :filters => {:mql => 'feature = (tech feature)'})

      view.rename_project_variable('tech feature', 'technical feature')
      assert_equal("feature = (technical feature)", view.reload.to_params[:filters][:mql])
    end
  end

  def test_rename_tree_should_rename_the_tree
    with_three_level_tree_project do |project|
      filters = MqlFilters.new(project, "FROM TREE 'three level tree'")
      filters.rename_tree('three level tree', 'tri-level tree')
      assert_equal({ :mql => "FROM TREE 'tri-level tree'" }, filters.to_params)
    end
  end

  def test_should_tell_whether_using_a_enumeration_value_or_not
    with_new_project do |project|
      setup_property_definitions :status => ['new', 'close', 'fixed']

      filter = project.card_list_views.create_or_update(:view => {:name => 'saved view'},
        :style => 'list', :filters => {:mql => 'type = card and status = new '}).filters
      assert filter.uses_property_value?('status', 'new')
      assert !filter.uses_property_value?('status', 'close')
    end

  end

  def test_should_tell_whether_using_a_card_type
    setup_card_type(@project, 'story', :properties => ['Status', 'Iteration'])
    setup_card_type(@project, 'bug', :properties => ['dev'])
    filter = @project.card_list_views.create_or_update(:view => {:name => 'saved view'},
      :style => 'list', :filters => {:mql => 'type = story and type != card '}).filters

    assert filter.uses_card_type?('story')
    assert filter.uses_card_type?('card')
    assert !filter.uses_card_type?('bug')
  end

  def test_should_rename_card_type_when_card_type_name_changed
    setup_card_type(@project, 'story', :properties => ['Status', 'Iteration'])
    view = @project.card_list_views.create_or_update(:view => {:name => 'saved view'},
      :style => 'list', :filters => {:mql => 'type = story and status = new '})

    view.rename_card_type('story', 'big task')
    assert_equal "Type = 'big task' AND Status = new", view.to_params[:filters][:mql]
  end

  def test_should_show_validate_mql_syntax
    assert_validation_error "Card property '#{'something'.bold}' does not exist!", 'something is not correct'
    assert_validation_error "#{'not correct'.bold} is not a valid value for #{'Type'.bold}, which is restricted to #{'Card'.bold}", "type = 'not correct'"
  end

  def test_should_validate_filter_mql_specified_part
    assert_validation_error "#{'SELECT'.bold} is not required to filter by MQL. Enter MQL conditions only.", 'select name where type = story'
  end

  def test_group_by_properties_should_be_only_mutual_properties_applicable_all_of_types_from_mql_filter
    setup_card_type(@project, 'story', :properties => ['Status', 'Iteration'])
    setup_card_type(@project, 'bug', :properties => ['Status', 'dev'])

    assert_group_by_properties_equals ['Type', 'Status', 'Iteration'], 'type = story'
    assert_group_by_properties_equals ['Type', 'Status', 'dev'], 'type = bug'
    assert_group_by_properties_equals ['Type', 'Status' ], 'type = bug or type = story'
  end

  def test_should_return_global_properties_if_all_card_type_implied
    setup_card_type(@project, 'story', :properties => ['Status', 'Iteration'])
    setup_card_type(@project, 'bug', :properties => ['Status', 'dev'])

    assert_group_by_properties_equals ['Type', 'Status'], 'dev = first'
    assert_group_by_properties_equals ['Type', 'Status'], ''
  end

  def test_group_by_properties_should_be_all_global_properties_if_there_is_no_card_type_implied
    setup_card_type(@project, 'story', :properties => ['Status', 'Iteration'])
    setup_card_type(@project, 'bug', :properties => ['Status', 'dev'])
    assert_group_by_properties_equals ['Type', 'Status'], 'type = bug and type != bug'
  end

  def test_should_return_sorted_filter_string_when_using_mql_filter
    filter = MqlFilters.new(@project, "type = card")
    assert_equal 'mql type = card', filter.sorted_filter_string
  end

  def test_card_type_names_should_be_empty_when_there_mql_is_invalid
    assert_equal [], MqlFilters.new(@project, 'type 123').card_type_names
    assert_equal [], MqlFilters.new(@project, 'type = lalals').card_type_names
  end

  def test_should_not_allow_this_card_to_be_used
    with_card_query_project do |project|
      filter = MqlFilters.new(project, "'related card' = this card")
      assert_equal(1, filter.validation_errors.size)
      assert_match(/#{CardQuery::MQLFilterValidations::THIS_CARD_USED}/, filter.validation_errors.first)
    end
  end

  def test_should_be_able_to_list_project_variables_used
    with_new_project do |p|
      setup_property_definitions :feature => ['cards', 'api']
      tech_feature_plv = create_plv!(p, :name => 'tech feature', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'api', :property_definition_ids => [p.find_property_definition('feature').id])

      view = p.card_list_views.create_or_update(:view => {:name => 'tech features'}, :filters => {:mql => 'feature = (tech feature)'})

      assert_equal([tech_feature_plv], view.project_variables_used)
    end
  end

  def test_project_variables_used_should_be_empty_when_mql_is_invalid
    assert_equal([], MqlFilters.new(@project, INVALID_FILTER_MQL).project_variables_used)
  end

  # Bug 4759
  def test_uses_plv_should_return_false_when_mql_is_invalid
    assert !MqlFilters.new(@project, INVALID_FILTER_MQL).uses_plv?('some plv')
  end

  # Bug 4759
  def test_uses_property_definition_should_return_false_when_mql_is_invalid
    assert !MqlFilters.new(@project, INVALID_FILTER_MQL).uses_property_definition?('some property definition')
  end

  # Bug 4759
  def test_uses_card_type_should_return_false_when_mql_is_invalid
    assert !MqlFilters.new(@project, INVALID_FILTER_MQL).uses_card_type?('some card type')
  end

  # Bug 4759
  def test_uses_property_value_should_return_false_when_mql_is_invalid
    assert !MqlFilters.new(@project, INVALID_FILTER_MQL).uses_property_value?('some property definition', 'some value')
  end

  # Bug 4759
  def test_uses_card_should_return_false_when_mql_is_invalid
    assert !MqlFilters.new(@project, INVALID_FILTER_MQL).uses_card?('some card')
  end

  # Bug 4759
  def test_using_card_as_value_should_return_false_when_mql_is_invalid
    assert !MqlFilters.new(@project, INVALID_FILTER_MQL).using_card_as_value?
  end

  # Bug 4759
  def test_cards_used_sql_condition_should_return_empty_string_when_mql_is_invalid
    assert_equal("", MqlFilters.new(@project, INVALID_FILTER_MQL).cards_used_sql_condition)
  end

  # Bug 4759
  def test_as_card_query_conditions_should_return_empty_array_when_mql_is_invalid
    assert_equal([], MqlFilters.new(@project, INVALID_FILTER_MQL).as_card_query_conditions)
  end

  # Bug 4759
  def test_rename_property_should_not_change_mql_when_original_mql_is_invalid
    assert_equal INVALID_FILTER_MQL, MqlFilters.new(@project, INVALID_FILTER_MQL).rename_property('old', 'new').mql
  end

  # Bug 4759
  def test_rename_property_value_should_not_change_mql_when_original_mql_is_invalid
    assert_equal INVALID_FILTER_MQL, MqlFilters.new(@project, INVALID_FILTER_MQL).rename_property_value('property_name', 'old', 'new').mql
  end

  # Bug 4759
  def test_rename_project_variable_should_not_change_mql_when_original_mql_is_invalid
    assert_equal INVALID_FILTER_MQL, MqlFilters.new(@project, INVALID_FILTER_MQL).rename_project_variable('old', 'new').mql
  end

  # Bug 4759
  def test_rename_card_type_should_not_change_mql_when_original_mql_is_invalid
    assert_equal INVALID_FILTER_MQL, MqlFilters.new(@project, INVALID_FILTER_MQL).rename_card_type('old', 'new').mql
  end

  def test_should_know_if_there_are_no_user_properties_in_unparsable_mql
    with_first_project do |project|
      filters = MqlFilters.new(project, '????')
      counter = 0
      filters.each { counter += 1 }
      assert_equal 0, counter
    end
  end

  def test_should_know_properties
    with_first_project do |project|
      filters = MqlFilters.new(project, 'dev is member')
      filters.each do |filter|
        assert_equal 'dev', filter.property_definition.name
        assert_equal User.find_by_login('member').id.to_s, filter.value
      end
    end
  end

  private

  def mql_help_link
    "&nbsp;<a href='#{ONLINE_HELP_DOC_DOMAIN}/help/filter_list_by_mql.html' target='blank'>Help</a>"
  end

  def assert_validation_error(expected_message, mql)
    view = CardListView.find_or_construct(@project, {:project_id => @project.identifier, :filters => { :mql => mql }} )
    assert_equal expected_message, view.filters.validation_errors.join
    assert_equal 'Filter list by MQL', Thread.current['mingle_cache_help_link']
  end

  def assert_group_by_properties_equals(expected, mql)
    view = @project.card_list_views.create_or_update(:view => {:name => 'saved view'},
      :style => 'grid', :filters => {:mql => mql})
    assert_equal expected.sort,  view.filters.properties_for_group_by.collect(&:name).sort
  end

end
