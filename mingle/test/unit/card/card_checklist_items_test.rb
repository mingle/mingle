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

class CardChecklistItemsTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    @project.activate
    @first_card = @project.cards.first
    login_as_member
  end

  def teardown
    Clock.reset_fake
  end

  def test_checklist_items_are_ordered_by_updated_at_in_desc_order_when_sortable_toggle_is_off
    @first_card.checklist_items.create(:text => "first item", :project_id => @project.identifier)
    @first_card.checklist_items.create(:text => "second item", :project_id => @project.identifier)
    @first_card.checklist_items.create(:text => "third item", :project_id => @project.identifier)

    assert_equal "third item", @first_card.checklist_items.first.text
    assert_equal "first item", @first_card.checklist_items.last.text
  end

  def test_incomplete_items_should_be_ordered_by_the_position_field_when_sortable_toggle_is_on
    card = @project.cards.first
    item1 = card.checklist_items.create({:text => "Make pancakes", :completed => false, :position => 0})
    item2 = card.checklist_items.create({:text => "Bake cupcakes", :completed => false, :position => 1})
    item3 = card.checklist_items.create({:text => "Bake cupcakes", :completed => false, :position => 2})
    assert_equal item1.id, card.incomplete_checklist_items.first.id
    assert_equal item2.id, card.incomplete_checklist_items[1].id
    assert_equal item3.id, card.incomplete_checklist_items.last.id

    item1.position = 4
    item1.save!
    assert_equal item1.id, card.reload.incomplete_checklist_items.last.id
  end

  def test_returns_only_completed_checklist_items
    @first_card.checklist_items.build(:text => "first completed item", :project_id => @project.identifier, :completed => true).save
    @first_card.checklist_items.build(:text => "second completed item", :project_id => @project.identifier, :completed => true).save
    @first_card.checklist_items.build(:text => "incomplete item", :project_id => @project.identifier).save

    assert_equal 2, @first_card.completed_checklist_items.length

    @first_card.completed_checklist_items.each do |item|
      assert item.completed
    end

    assert_equal "second completed item", @first_card.completed_checklist_items.first.text
    assert_equal "first completed item", @first_card.completed_checklist_items.last.text
  end

  def test_returns_only_incomplete_checklist_items
    @first_card.checklist_items.build(:text => "first incomplete item", :project_id => @project.identifier, :completed => false).save
    @first_card.checklist_items.build(:text => "second incomplete item", :project_id => @project.identifier, :completed => false).save
    @first_card.checklist_items.build(:text => "complete item", :project_id => @project.identifier, :completed => true).save

    assert_equal 2, @first_card.incomplete_checklist_items.length

    @first_card.incomplete_checklist_items.each do |item|
      assert !item.completed
    end

    assert_equal "second incomplete item", @first_card.incomplete_checklist_items.first.text
    assert_equal "first incomplete item", @first_card.incomplete_checklist_items.last.text
  end
end
