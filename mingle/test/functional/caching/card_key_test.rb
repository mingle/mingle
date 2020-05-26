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

class CardKeyTest < ActionController::TestCase
  include CachingTestHelper
  
  def setup
    @project = first_project
    @project.activate
    login_as_member
    @first_card = @project.cards.find_by_number(1)
    @another_card = @project.cards.find_by_number(4)
  end
  
  def test_different_card_generate_different_key
    assert_equal key(@first_card), key(@first_card)
    assert_not_equal key(@first_card), key(@another_card)
  end
  
  def test_after_update_card_generate_different_key
    assert_key_changed_after(@first_card) do
      @first_card.update_attribute(:name, 'new name')
    end
  end
  
  def test_card_key_changed_when_card_becomes_stale
    assert_key_changed_after(@first_card) do
      request = StalePropertyDefinition.create!(:card => @first_card, :prop_def_id => 123, :project => @project)
    end
  end
  
  def test_card_key_changed_when_card_becomes_unstale
    request = StalePropertyDefinition.create!(:card => @first_card, :prop_def_id => 123, :project => @project)
    assert_key_changed_after(@first_card) do
      request.destroy
    end
  end
    
  def test_tag_card_should_change_card_key
    assert_key_changed_after(@first_card) do
      @first_card.tag_with(['foo', 'bar']).save!
    end
  end
  
  def test_remove_tag_from_card_should_sweep_cache_for_that_card
    assert_key_changed_after(@first_card) do
      @first_card.remove_tag('first_tag')
      @first_card.save!
    end
  end
  
  def test_should_change_key_after_parent_card_changed
    with_filtering_tree_project do |project|
      assert_key_changed_after(f.card('story1')) do
        f.card('iteration1').update_attribute :name, 'iteration_1'
      end
      
      assert_key_not_changed_after(f.card('story1')) do
        f.card('iteration3').update_attribute :name, 'iteration_3'
      end
    end
  end
  
  def test_change_key_after_removed_card_from_tree
    with_three_level_tree_project do |project|
      card = project.cards.find_by_name 'release1'
      configuration = project.tree_configurations.find_by_name 'three level tree'
      assert_key_changed_after(card) do
        configuration.remove_card card
      end
    end
  end
  
  def test_change_key_after_add_new_card_to_tree
    with_three_level_tree_project do |project|
      card = create_card! :name => 'smart people can break GFW', :card_type => project.card_types.find_by_name('release')
      configuration = project.tree_configurations.find_by_name 'three level tree'
      assert_key_changed_after(card) do
        configuration.add_child card
      end
    end
  end
  
  private
  
  def f
    Finder.new(Project.current)
  end  
  
  def key(card)
    KeySegments::Card.new(card).to_s
  end
  
end
