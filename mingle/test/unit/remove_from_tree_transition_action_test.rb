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

class RemoveFromTreeTransitionActionTest < ActiveSupport::TestCase
  
  def setup
    @project = three_level_tree_project
    @tree = @project.find_tree_configuration('three level tree')
    @project.activate
    login_as_member
  end
  
  def test_should_be_able_to_remove_card_using_transition
    iteration = @project.card_types.find_by_name('iteration')
    transition = create_transition(@project, 'remove from tree', :card_type => iteration, :remove_from_trees => [@tree])
    iteration2 = @project.cards.find_by_name('iteration2')
    assert @tree.include_card?(iteration2)
    transition.execute iteration2
    assert !@tree.include_card?(iteration2)
  end
  
  def test_removing_from_tree_and_setting_new_properties_only_create_one_version
    iteration2 = @project.cards.find_by_name('iteration2')
    status = @project.find_property_definition('status')
    status.update_card(iteration2, 'closed')
    original_number_of_versions = iteration2.versions.count
    
    transition = create_transition(@project, 'remove from tree and open card', :card_type => iteration2.card_type, :remove_from_trees => [@tree], :set_properties => {:status => 'open'})
    assert @tree.include_card?(iteration2)
    transition.execute(iteration2)
    
    assert !@tree.include_card?(iteration2)
    assert_equal 'open', status.value(iteration2)
    assert_equal original_number_of_versions + 1, iteration2.reload.versions.count
  end
  
  def test_should_only_remove_children_from_tree_when_child_value_present
    iteration1 = @project.cards.find_by_name('iteration1')
    status = @project.find_property_definition('status')
    status.update_card(iteration1, 'closed')
    story1 = @project.cards.find_by_name('story1')
    story2 = @project.cards.find_by_name('story2')
    transition = create_transition(@project, 'remove with children', :card_type => iteration1.card_type, :remove_from_trees_with_children => [@tree], :set_properties => {:status => 'open'})
    assert @tree.include_card?(iteration1)
    assert @tree.include_card?(story1)
    assert @tree.include_card?(story2)
    original_number_of_versions = iteration1.versions.count
    transition.execute(iteration1)
    assert !@tree.include_card?(iteration1)
    assert !@tree.include_card?(story1)
    assert !@tree.include_card?(story2)
    assert_equal 'open', status.value(iteration1)
    assert_equal original_number_of_versions + 1, iteration1.reload.versions.count
  end
  
  def test_can_execute_transition_on_cards_not_on_tree
    iteration = @project.card_types.find_by_name('iteration')
    card_not_on_tree = @project.cards.create(:name => 'not on tree', :card_type => iteration)
    transition = create_transition(@project, 'remove', :card_type => iteration, :remove_from_trees => [@tree])
    assert !@tree.include_card?(card_not_on_tree)
    transition.execute(card_not_on_tree)
    assert !@tree.include_card?(card_not_on_tree)
  end
end
