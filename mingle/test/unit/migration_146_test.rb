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
require File.expand_path(File.dirname(__FILE__) + '/../../db/migrate/146_rename_plvs_using_user_input_transition_labels.rb')

# these tests should pass if you make RESERVED_IDENTIFIERS empty in project.rb
class Migration146Test < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  
  def test_card_list_views_filtering_by_plv_will_be_changed
    # with_new_project do |project|
    #   setup_property_definitions :status => ['new', 'open', 'closed'], :dessert => ['cake', 'biscuits'], :gasoline => ['regular', 'unleaded']
    #   status = project.find_property_definition('status')
    #   dessert = project.find_property_definition('dessert')
    #   gasoline = project.find_property_definition('gasoline')
    #   
    #   plv1 = create_plv!(project, :name => 'user input - required', :value => 'open', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [status.id])
    #   plv2 = create_plv!(project, :name => 'user input - Optional', :value => 'cake', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [dessert.id])
    #   plv3 = create_plv!(project, :name => 'user input - optional_1', :value => 'regular', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [gasoline.id])
    #   view = CardListView.construct_from_params(project, {:name => 'hey great view', :filters => ['[Type][is][Card]', '[status][is][(user input - required)]', '[dessert][is][(user input - Optional)]', '[gasoline][is][(user input - optional_1)]']})
    #   view.save
    #   
    #   RenamePlvsUsingUserInputTransitionLabels.up
    #   
    #   view = CardListView.find(view.id)
    #   
    #   expected_filters = ["[Type][is][Card]", "[status][is][(user input - required_1)]", "[dessert][is][(user input - Optional_2)]", "[gasoline][is][(user input - optional_1)]"]
    #   assert_equal expected_filters, view.params[:filters]
    #   
    #   assert_equal "filters=[dessert][is][(user input - optional_2)],[gasoline][is][(user input - optional_1)],[status][is][(user input - required_1)],[type][is][card],style=list", view.canonical_string
    #   assert_equal "filters=[dessert][is][(user input - optional_2)],[gasoline][is][(user input - optional_1)],[status][is][(user input - required_1)],[Type][is][Card]", view.canonical_filter_string
    # end
  end
  
  def test_that_a_view_with_no_filters_is_not_affected
    # with_new_project do |project|
    #   setup_property_definitions :status => ['new', 'open', 'closed'], :dessert => ['cake', 'biscuits'], :gasoline => ['regular', 'unleaded']
    #   status = project.find_property_definition('status')
    #   dessert = project.find_property_definition('dessert')
    #   gasoline = project.find_property_definition('gasoline')
    #   
    #   view = CardListView.construct_from_params(project, {:name => 'hey great view', :tagged_with => 'rss'})
    #   view.save
    #   
    #   RenamePlvsUsingUserInputTransitionLabels.up
    #   
    #   view = CardListView.find(view.id)
    #   assert !view.params.keys.include?(:filters)
    # end
  end
  
  def test_tree_filters_case
    # login_as_member
    # create_tree_project(:init_three_level_tree) do |project, tree, configuration|
    #   type_release, type_iteration, type_story = find_planning_tree_types
    #   setup_property_definitions :status => ['new', 'open', 'closed'], :dessert => ['cake', 'biscuits'], :gasoline => ['regular', 'unleaded']
    #   
    #   status = project.find_property_definition('status')
    #   dessert = project.find_property_definition('dessert')
    #   gasoline = project.find_property_definition('gasoline')
    #   
    #   type_iteration.add_property_definition(status)
    #   type_iteration.save!
    #   
    #   plv1 = create_plv!(project, :name => 'user input - required', :value => 'open', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [status.id])
    #   view = CardListView.construct_from_params(project, {:name => 'hey great view', :tree_id => configuration.id, :tf_iteration => ['[status][is][(user input - required)]']})
    #   view.save
    #   
    #   RenamePlvsUsingUserInputTransitionLabels.up
    #   
    #   view = CardListView.find(view.id)
    #   
    #   expected_filters = ["[status][is][(user input - required_1)]"]
    #   assert_equal expected_filters, view.params[:tf_iteration]
    #   assert_equal "style=list,tf_iteration=[status][is][(user input - required_1)],tree_name=planning", view.canonical_string
    #   assert_equal "filters=tf_iteration[]=[status][is][(user input - required_1)]", view.canonical_filter_string
    # end
  end
  
  def test_rename_operates_on_a_per_project_basis
    # project_one = build_plv_project
    # project_two = build_plv_project
    # 
    # RenamePlvsUsingUserInputTransitionLabels.up
    # 
    # project_one.with_active_project do |project|
    #   view = project.card_list_views.first
    #   assert_migrated_view_is_correct(view, project)
    # end
    # 
    # project_two.with_active_project do |project|
    #   view = project.card_list_views.first
    #   assert_migrated_view_is_correct(view, project)
    # end
  end
  
  def build_plv_project
    with_new_project do |project|
      setup_property_definitions :status => ['new', 'open', 'closed'], :dessert => ['cake', 'biscuits'], :gasoline => ['regular', 'unleaded']
      status = project.find_property_definition('status')
      dessert = project.find_property_definition('dessert')
      gasoline = project.find_property_definition('gasoline')
      
      plv1 = create_plv!(project, :name => 'user input - required', :value => 'open', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [status.id])
      plv2 = create_plv!(project, :name => 'user input - Optional', :value => 'cake', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [dessert.id])
      plv3 = create_plv!(project, :name => 'user input - optional_1', :value => 'regular', :data_type => ProjectVariable::STRING_DATA_TYPE, :property_definition_ids => [gasoline.id])
      view = CardListView.construct_from_params(project, {:name => 'hey great view', :filters => ['[Type][is][Card]', '[status][is][(user input - required)]', '[dessert][is][(user input - Optional)]', '[gasoline][is][(user input - optional_1)]']})
      view.save
    end
  end
  
  def assert_migrated_view_is_correct(view, project)
    expected_plv_names = ["user input - required_1", "user input - Optional_2", "user input - optional_1"]
    assert_equal expected_plv_names.sort, project.project_variables.collect(&:name).sort
    
    expected_filters = ["[Type][is][Card]", "[status][is][(user input - required_1)]", "[dessert][is][(user input - Optional_2)]", "[gasoline][is][(user input - optional_1)]"]
    assert_equal expected_filters, view.params[:filters]
    
    assert_equal "filters=[dessert][is][(user input - optional_2)],[gasoline][is][(user input - optional_1)],[status][is][(user input - required_1)],[type][is][card],style=list", view.canonical_string
    assert_equal "filters=[dessert][is][(user input - optional_2)],[gasoline][is][(user input - optional_1)],[status][is][(user input - required_1)],[Type][is][Card]", view.canonical_filter_string
  end
end
