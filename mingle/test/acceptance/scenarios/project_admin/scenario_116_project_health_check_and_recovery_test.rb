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

# Tags: cards, card-list, sort, scenario, card-selector
class Scenario116ProjectHealthCheckAndRecoveryTest < ActiveSupport::TestCase
  fixtures :users, :login_access
  
  ANY_TEXT_PROPERTY = 'allow_any_text'
  ANY_NUMBER_PROPERTY = 'allow_any_number'
  DATE_PROPERTY = 'date1'
  FORMULA_PROPERTY = 'double_size'
  CARD_RELATIONSHIP_PROPERTY = 'other_card'
  TEAM_PROPERTY = 'owner'
  
  STATUS = 'status'
  SIZE = 'size'
  OPEN = 'open'
  CLOSED = 'closed'
  
  STORY = 'story'
  ITERATION = 'iteration'
  RELEASE = 'release'
  PLANNING_TREE = 'planning tree'
  
  TREE_RELATIONSHIP_PROPERTY_1 = 'tree_relationship_property_1'
  TREE_RELATIONSHIP_PROPERTY_2 = 'tree_relationship_property_2'
  
  AGGREGATE_PROPERTY_1 = 'aggregate_property_1'
  
  SUM = 'Sum'
  COUNT = 'Count'
  ALL_DESCENANTS = 'All descendants'
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin = users(:proj_admin)
    @team_member = users(:project_member)
    @read_only_user = users(:read_only_user)
    register_license_that_allows_anonymous_users
    @project = create_project(:prefix => 'scenario_116', :read_only_users => [@read_only_user], :users => [@team_member], :admins => [@project_admin], :anonymous_accessible => true)
    @project.activate
    #all types of property
    @any_number_property = setup_numeric_text_property_definition(ANY_NUMBER_PROPERTY)
    @any_text_property = setup_text_property_definition(ANY_TEXT_PROPERTY)
    @managed_number_property = setup_numeric_property_definition(SIZE, [1, 2, 4])
    @managed_text_property = setup_property_definitions(STATUS => [OPEN, CLOSED])
    @date_property = setup_date_property_definition(DATE_PROPERTY)
    @formula_property = setup_formula_property_definition(FORMULA_PROPERTY, "#{SIZE} * 2")
    @card_relationship_property = setup_card_relationship_property_definition(CARD_RELATIONSHIP_PROPERTY)
    @team_property = setup_user_definition(TEAM_PROPERTY)
    #create some new card types
    @type_story = setup_card_type(@project, STORY, :properties => [SIZE, STATUS])
    @type_iteration = setup_card_type(@project, ITERATION)
    @type_release = setup_card_type(@project, RELEASE)
    #create a tree and define one aggregate property
    @planning_tree = setup_tree(@project, PLANNING_TREE, :types => [@type_release, @type_iteration, @type_story], :relationship_names => [TREE_RELATIONSHIP_PROPERTY_1, TREE_RELATIONSHIP_PROPERTY_2])
    #@aggregate_property = setup_aggregate_property_definition(AGGREGATE_PROPERTY_1, AggregateType::COUNT, nil, @planning_tree.id, @type_release.id, AggregateScope::ALL_DESCENDANTS)
    login_as_proj_admin_user
  end
  
  def test_admin_user_can_get_corrupt_properties_by_checking_project_health_state
    remove_normal_property_from_project_cards_table(DATE_PROPERTY)
    remove_relationship_property_from_project_cards_table(TREE_RELATIONSHIP_PROPERTY_1)
    navigate_to_advanced_project_administration_page_for(@project)
    assert_normal_property_corruption_info_for_admin_not_present(DATE_PROPERTY)
    assert_tree_relationship_property_corruption_info_for_admin_not_present(TREE_RELATIONSHIP_PROPERTY_1)
    check_project_health_state
    assert_normal_property_corruption_info_for_admin_present(DATE_PROPERTY)
    assert_tree_relationship_property_corruption_info_for_admin_present(TREE_RELATIONSHIP_PROPERTY_1)
    click_link(DATE_PROPERTY)
    assert_location_url("/projects/#{@project.identifier}/property_definitions")
  end
  
  def test_should_provide_successful_message_when_the_project_health_check_is_run_and_there_are_no_problems
    navigate_to_advanced_project_administration_page_for(@project)
    check_project_health_state
    assert_health_check_successful_message_present
  end
  
end
