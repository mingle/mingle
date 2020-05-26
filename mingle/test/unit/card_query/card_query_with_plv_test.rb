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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class CardQueryWithPLVTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    @project = card_query_project
    @project.activate
    login_as_member
    @card = @project.cards.find_by_number(1)
  end

  def test_should_parse_plv_in_simple_format
    create_plv!(@project, :name => 'current_release', :value => '1', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definitions => [@project.find_property_definition('release')])
    assert_equal "Release is 1", CardQuery.parse("release = (current_release)").to_s
  end

  def test_should_be_able_to_recreate_plv_mql
    plv = create_plv!(@project, :name => 'current_release', :value => '1', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definitions => [@project.find_property_definition('release')])
    assert_equal "Release = (current_release)", CardQuery::MqlGeneration.new(CardQuery.parse("release = (current_release)")).execute
  end

  def test_should_parse_plv_in_complex_format
    create_plv!(@project, :name => 'current release', :value => '1', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definitions => [@project.find_property_definition('release')])
    assert_equal "Release is 1", CardQuery.parse("release = (current release)").to_s
    assert_equal "Release is 1", CardQuery.parse("release = ( current release )").to_s
  end

  def test_plv_resolving_should_be_case_insensitive
    create_plv!(@project, :name => 'current release', :value => '1', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definitions => [@project.find_property_definition('release')])
    assert_equal "Release is 1", CardQuery.parse("release = ( Current Release )").to_s
  end

  def test_using_string_type_plv_in_in_clause
    create_plv!(@project, :name => 'current iteration', :value => '1', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definitions => [@project.find_property_definition('release')])
    assert_equal "Release IN (1, 2)", CardQuery.parse("release in ((current iteration), 2)").to_s
  end

  def test_should_find_card_by_mql_using_plv
    create_plv!(@project, :name => 'current release', :value => '1', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definitions => [@project.find_property_definition('release')])
    assert_equal [@card.name], CardQuery.parse("select name where release = (current release)").single_values
  end

  def test_plv_should_be_restricted_to_only_associated_properties
    iteration = @project.find_property_definition('iteration')
    create_plv!(@project, :name => 'current release', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => @card.number, :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definitions => [@project.find_property_definition('release')])
    assert_raise(CardQuery::DomainException) { CardQuery.parse("select name where number = (current release)").single_values }
  end

  def test_using_user_type_plv_in_comparison
    create_plv!(@project, :name => 'QA lead', :data_type => ProjectVariable::USER_DATA_TYPE, :value => User.find_by_login('member').id.to_s, :property_definitions => [@project.find_property_definition('owner')])
    @card.cp_owner = User.find_by_login('member')
    @card.save!
    assert_equal [@card.name], CardQuery.parse("select name where owner = (QA lead)").single_values
  end

  def test_using_user_type_plv_in_inclause
    create_plv!(@project, :name => 'QA lead', :data_type => ProjectVariable::USER_DATA_TYPE, :value => User.find_by_login('member').id.to_s, :property_definitions => [@project.find_property_definition('owner')])
    @card.cp_owner = User.find_by_login('member')
    @card.save!
    assert_equal [@card.name], CardQuery.parse("select name where owner in ('admin', (QA lead))").single_values
  end

  def test_using_date_type_plv
    create_plv!(@project, :name => 'mile stone', :data_type => ProjectVariable::DATE_DATA_TYPE, :value => '01/01/2008', :property_definitions => [@project.find_property_definition('date_created')])
    @card.cp_date_created = '01/10/2007'
    @card.save!
    assert_equal [@card.name], CardQuery.parse("select name where date_created < (mile stone)").single_values
  end

  def test_using_card_type_plv
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      iteration1 = project.cards.find_by_name('iteration1')
      create_plv!(project, :name => 'current iteration', :value => iteration1.id, :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definitions => [project.find_property_definition('planning iteration')])
      project.reload
      assert_equal ['story1', 'story2'].sort, CardQuery.parse("select name where 'planning iteration' = (current iteration)").single_values.sort
    end
  end

  def test_should_not_supporting_using_card_type_plv_in_explicit_in_clause
    with_new_project do |project|
      type_release, type_iteration, type_story = init_planning_tree_types
      tree = create_planning_tree_with_duplicate_iteration_names
      r2_iteration1 = tree.find_node_by_name('release2').children.detect{ |node| node.name == 'iteration1' }
      r2_iteration2 = tree.find_node_by_name('release2').children.detect{ |node| node.name == 'iteration2' }
      planning_iteration = project.find_property_definition('planning iteration')

      create_plv!(project, :name => 'current iteration', :value => r2_iteration1.id, :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definitions => [planning_iteration])
      create_plv!(project, :name => 'next iteration', :value => r2_iteration2.id, :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definitions => [planning_iteration])
      project.reload
      assert_parse_error("Project variables are not currently supported by a MQL IN clause when the comparison property is a tree property. Please construct your conditions using different MQL syntax.") do
        CardQuery.parse("'planning iteration' in ((current iteration), (next iteration))")
      end
    end
  end

  def test_should_not_supporting_using_card_type_plv_in_numbers_explicit_in_clause
    with_new_project do |project|
      type_release, type_iteration, type_story = init_planning_tree_types
      tree = create_planning_tree_with_duplicate_iteration_names
      r2_iteration1 = tree.find_node_by_name('release2').children.detect{ |node| node.name == 'iteration1' }
      r2_iteration2 = tree.find_node_by_name('release2').children.detect{ |node| node.name == 'iteration2' }
      planning_iteration = project.find_property_definition('planning iteration')

      create_plv!(project, :name => 'current iteration', :value => r2_iteration1.id, :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definitions => [planning_iteration])
      create_plv!(project, :name => 'next iteration', :value => r2_iteration2.id, :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definitions => [planning_iteration])
      project.reload
      assert_parse_error("Project variables are not currently supported by a MQL IN clause when the comparison property is a tree property. Please construct your conditions using different MQL syntax.") do
        CardQuery.parse("'planning iteration' numbers in ((current iteration), (next iteration))")
      end
    end
  end

  def test_using_card_type_plv_and_duplicate_card_name
    with_new_project do |project|
      type_release, type_iteration, type_story = init_planning_tree_types
      tree = create_planning_tree_with_duplicate_iteration_names
      r2_iteration1 = tree.find_node_by_name('release2').children.detect{ |node| node.name == 'iteration1' }
      planning_iteration = project.find_property_definition('planning iteration')

      create_plv!(project, :name => 'current iteration', :value => r2_iteration1.id, :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definitions => [planning_iteration])
      project.reload
      assert_equal ['story3'], CardQuery.parse("select name where 'planning iteration' = (current iteration)").single_values
    end
  end

  # bug 3506
  def test_can_select_relationship_and_use_it_with_plv_at_same_time
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types

      release1 = project.cards.find_by_name('release1')
      planning_release = project.find_property_definition('planning release')

      create_plv!(project, :name => 'current release', :value => release1.id, :card_type => type_release, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definitions => [planning_release])
      project.reload

      cq = CardQuery.parse("select name, 'planning release' where 'planning release' = (current release)")
      values = cq.values

      assert_equal ['iteration1', 'iteration2', 'story1', 'story2'], values.collect { |value| value['Name'] }.sort
      assert_equal [release1.number_and_name], values.collect { |value| value['Planning release'] }.uniq
    end
  end

  def test_should_show_error_when_comparing_date_type_does_not_match
    create_plv!(@project, :name => 'QA lead', :data_type => ProjectVariable::USER_DATA_TYPE, :value => User.find_by_login('member').id.to_s)
    assert_parse_error("Comparing between property '#{'Iteration'.bold}' and project variable #{'(QA lead)'.bold} is invalid as they are not associated with each other.") { CardQuery.parse("iteration = (QA lead)") }
    create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '10')
    assert_parse_error { CardQuery.parse('accurate_estimate > (current iteration)') }
    create_plv!(@project, :name => 'PI', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '3.1415926')
    assert_parse_error { CardQuery.parse('iteration > (PI)') }
    create_plv!(@project, :name => 'mile stone', :data_type => ProjectVariable::DATE_DATA_TYPE, :value => '01/01/2008')
    assert_parse_error { CardQuery.parse('iteration > (mile stone)') }
  end

  def test_should_show_error_when_data_type_not_match_in_in_clause
    create_plv!(@project, :name => 'PI', :data_type => ProjectVariable::NUMERIC_DATA_TYPE, :value => '3.1415926', :property_definitions => [@project.find_property_definition('numeric_free_text')])
    assert_parse_error("Comparing between property '#{'Iteration'.bold}' and project variable #{'(PI)'.bold} is invalid as they are not associated with each other.") { CardQuery.parse("iteration IN ((PI), '1.0')") }
  end

  def test_should_show_error_when_trying_to_use_a_not_exists_plv
    assert_parse_error("The project variable (#{'current iteration'.bold}) does not exist") { CardQuery.parse("release = (current iteration)") }
  end

  def test_query_with_plv_should_be_able_to_convert_to_card_list_view_with_actual_value
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      iteration1 = project.cards.find_by_name('iteration1')
      create_plv!(project, :name => 'current iteration', :value => iteration1.id, :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definitions => [project.find_property_definition('planning iteration')])
      query = CardQuery.parse("select name where 'planning iteration' = (current iteration)")
      assert_equal "'Planning iteration' = (current iteration)", query.as_card_list_view.to_params[:filters][:mql]
    end
  end

  # bug 3238
  def test_can_parse_plv_beginning_with_word_today
    date_created = @project.find_property_definition('date_created')

    create_plv!(@project, :name => 'today date', :value => '01/01/2008', :data_type => ProjectVariable::DATE_DATA_TYPE, :property_definitions => [date_created])
    assert_equal "date_created is '01 Jan 2008'", CardQuery.parse("date_created = (today date)").to_s

    create_plv!(@project, :name => 'date today', :value => '01/01/2008', :data_type => ProjectVariable::DATE_DATA_TYPE, :property_definitions => [date_created])
    assert_equal "date_created is '01 Jan 2008'", CardQuery.parse("date_created = (date today)").to_s

    create_plv!(@project, :name => 'date today date', :value => '01/01/2008', :data_type => ProjectVariable::DATE_DATA_TYPE, :property_definitions => [date_created])
    assert_equal "date_created is '01 Jan 2008'", CardQuery.parse("date_created = (date today date)").to_s
  end

  class TestFailedException < StandardError; end

  def assert_parse_error(expected_msg = nil, &block)
    begin
      yield
      raise TestFailedException.new;
    rescue TestFailedException
      fail("expected exception has not been thrown")
    rescue CardQuery::DomainException => e
      assert_equal(expected_msg, e.message) if expected_msg
    end
  end

end
