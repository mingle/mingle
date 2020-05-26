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

class TransitionOnlyTest < ActiveSupport::TestCase
  def test_card_should_be_invalid_for_updating_transition_only_property
    login_as_member
    with_first_project do |project|
      status = project.find_property_definition('status')
      status.update_attribute(:transition_only, true)
      card = project.cards.first
      status.update_card(card, 'new')
      assert_equal ['Status: is a transition only property.'], card.errors.full_messages
    end
  end
  
  def test_new_card_should_be_valid_for_updating_transition_only_property
    login_as_member
    with_first_project do |project|
      status = project.find_property_definition('status')
      status.update_attribute(:transition_only, true)
      new_card = project.cards.new
      
      status.update_card(new_card, 'new')
      assert_equal 'new', new_card.cp_status
      assert_equal [], new_card.errors.full_messages
    end
  end
  
  def test_without_transition_only_validation_for_card
    login_as_member
    with_first_project do |project|
      status = project.find_property_definition('status')
      status.update_attribute(:transition_only, true)
      card = project.cards.first

      card.without_transition_only_validation do
        status.update_card(card, 'new')
      end
      assert_equal 'new', card.cp_status
      assert_equal [], card.errors.full_messages
    end
  end
  
  def test_card_should_be_valid_for_updating_transition_only_property_with_same_value
    login_as_member
    with_first_project do |project|
      status = project.find_property_definition('status')
      status.update_attribute(:transition_only, true)
      card = project.cards.create! :cp_status => 'new', :name => 'just created card', :card_type_name => 'card'

      status.update_card(card, 'new')
      assert_equal 'new', card.cp_status
      assert_equal [], card.errors.full_messages
    end
  end
  
  def test_project_admin_should_be_able_to_update_transition_only_property_on_card
    login_as_proj_admin
    with_first_project do |project|
      status = project.find_property_definition('status')
      status.update_attribute(:transition_only, true)
      card = project.cards.first

      status.update_card(card, 'new')
      assert_equal 'new', card.cp_status
      assert_equal [], card.errors.full_messages
    end
  end

  def test_mingle_admin_should_be_able_to_update_transition_only_property_on_card
    login_as_admin
    with_first_project do |project|
      status = project.find_property_definition('status')
      status.update_attribute(:transition_only, true)
      card = project.cards.first

      status.update_card(card, 'new')
      assert_equal 'new', card.cp_status
      assert_equal [], card.errors.full_messages
    end
  end
  
  def test_card_type_definition
    with_first_project do |project|
      assert !project.card_type_definition.transition_only?
      assert !project.card_type_definition.transition_only_for_updating_card?
      assert !project.card_type_definition.transition_only_for_updating_card?(nil)
      assert !project.card_type_definition.transition_only_for_updating_card?(project.cards.first)
      assert !project.card_type_definition.transition_only_for_updating_card?(project.cards.new)
    end
  end
  
  def test_tree_belonging_property_definition
    with_first_project do |project|
      assert !TreeBelongingPropertyDefinition.new(nil).transition_only?
      assert !TreeBelongingPropertyDefinition.new(nil).transition_only_for_updating_card?
      assert !TreeBelongingPropertyDefinition.new(nil).transition_only_for_updating_card?(nil)
      assert !TreeBelongingPropertyDefinition.new(nil).transition_only_for_updating_card?(project.cards.first)
      assert !TreeBelongingPropertyDefinition.new(nil).transition_only_for_updating_card?(project.cards.new)
    end
  end
end
