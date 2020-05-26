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

#Tags: transitions
class Scenario145UseSetAsTransitionPrerequisiteTest < ActiveSupport::TestCase
  fixtures :users, :login_access
  
  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)  
    @browser = selenium_session
    @project_admin = users(:admin)
    @team_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_134', :users => [@team_member], :admins => [@project_admin])
    login_as_admin_user   
  end
  
  def test_use_set_in_prerequisite_of_transtion_for_all_types_of_property
    value_card_1 = create_card!(:name => 'card for property value')
    value_card_2 = create_card!(:name => 'card for property value')
  
    properties = [
      {:type  => 'Managed text list', :name => 'priority', :value => ['high', 'low']},
      {:type  => 'Allow any text', :name => 'iteration', :value => ['iteration 1', 'iteration 2']},
      {:type => 'Managed number list', :name => 'size', :value => [1,2]},
      {:type => 'Allow any number', :name => 'revision', :value => [100, 101]},
      {:type => 'team', :name => 'owner', :value => [@project_admin.name, @team_member.name]},
      {:type => 'date', :name => 'start_on', :value => ['2009/09/09', '2009/09/07']},
      {:type => 'card', :name => 'dependency', :value => [value_card_1, value_card_2]}
      ]

      
    properties.each do |property|
      create_property_for_card(property[:type], property[:name])
      transition = create_transition_for(@project, "#{property[:name]} from set to not set", :required_properties => {:"#{property[:name]}" => '(set)'}, :set_properties => {:"#{property[:name]}" => '(not set)'})
      testing_card = create_card!(:name => 'card for testing')

      open_card(@project, testing_card)
      assert_transition_not_present_on_card(transition)
      set_property_value_on_card_show(@project, "#{property[:name]}", property[:value][0])
      assert_transition_present_on_card(transition)
      click_transition_link_on_card(transition)
      assert_properties_set_on_card_show("#{property[:name]}" => "(not set)")
      assert_transition_not_present_on_card(transition)
      set_property_value_on_card_show(@project,"#{property[:name]}", property[:value][0])
      assert_transition_present_on_card(transition)
      click_transition_link_on_card(transition)
      assert_properties_set_on_card_show("#{property[:name]}" => "(not set)")
    end    
  end
  
end
