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

class CardChecklistsTest < ActiveSupport::TestCase

  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def test_creates_checklist_items_on_a_card
    card = @project.cards.first

    card.checklist_items.create({:text => "Make pancakes", :completed => true})
    card.checklist_items.create({:text => "Bake cupcakes", :completed => false})
    assert_equal 2, card.checklist_items.count
  end

  def test_deleting_a_card_deletes_associated_checklists
    card = @project.cards.first
    checklist_item = card.checklist_items.create({:text => "Make pancakes", :completed => false})
    card.destroy
    assert_nil CardChecklistItem.find_by_id(checklist_item.id)
  end

  def test_mark_complete_updates_position_when_add_to_bottom_set
    with_new_project do |project|
        card = project.cards.create(:name => 'card with checklists', :card_type_name => 'card')
        checklist_item1 = card.checklist_items.create({:text => "first", :completed => false, :position => 0})
        checklist_item2 = card.checklist_items.create({:text => "second", :completed => false, :position => 1})
        checklist_item3 = card.checklist_items.create({:text => "third", :completed => false, :position => 2})

        checklist_item1.mark_complete
        assert checklist_item1.completed
        assert_equal 0, checklist_item1.position

        checklist_item3.mark_complete
        assert checklist_item3.completed
        assert_equal 1, checklist_item3.position
    end
  end

  def test_mark_incomplete_updates_position_when_add_to_bottom_set
    with_new_project do |project|
        card = project.cards.create(:name => 'card with checklists', :card_type_name => 'card')
        checklist_item1 = card.checklist_items.create({:text => "first", :completed => true, :position => 0})
        checklist_item2 = card.checklist_items.create({:text => "second", :completed => true, :position => 1})
        checklist_item3 = card.checklist_items.create({:text => "third", :completed => true, :position => 2})
        checklist_item4 = card.checklist_items.create({:text => "fourth", :completed => false, :position => 0})
        checklist_item5 = card.checklist_items.create({:text => "fifth", :completed => false, :position => 1})

        checklist_item1.mark_incomplete
        assert_false checklist_item1.completed
        assert_equal 2, checklist_item1.position

        checklist_item3.mark_incomplete
        assert_false checklist_item3.completed
        assert_equal 3, checklist_item3.position

        assert_equal 4, card.incomplete_checklist_items.size
    end
  end

end
