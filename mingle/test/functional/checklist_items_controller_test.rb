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

class ChecklistItemsControllerTest < ActionController::TestCase

  def setup
    @controller = create_controller(ChecklistItemsController)
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_member
  end

  def test_creates_a_checklist_item
    MingleConfiguration.with_metrics_api_key_overridden_to('key') do
      with_first_project do |project|
        card = project.cards.first
        post :create, :project_id => project.identifier, :card_number => card.number, :item => 'first item'
        assert_response :created
        assert @controller.events_tracker.sent_event?('created_checklist_item')
        card.reload
        assert_equal 1, card.checklist_items.count
        item = card.checklist_items.first
        assert_equal project, item.project
        assert_equal 'first item', item.text
        assert_equal false, item.completed
      end
    end
  end

  def test_creates_a_checklist_item_in_descending_order
      with_new_project do |project|
        login_as_admin
        card = project.cards.create(:name => 'card with checklists', :card_type_name => 'card')
        card.checklist_items.create(:text => "first item", :completed => "false", :project_id => project.id, :position => 0)
        card.checklist_items.create(:text => "completed item", :completed => "true", :project_id => project.id, :position => 0)
        post :create, :project_id => project.identifier, :card_number => card.number, :item => 'second item'
        card.reload
        assert_equal 3, card.checklist_items.count
        item = card.checklist_items.find_by_position(1)
        assert_equal 'second item', item.text
      end
  end

  def test_descending_order_for_completed_checklist_items
      with_new_project do |project|
        login_as_admin
        card = project.cards.create(:name => 'card with checklists', :card_type_name => 'card')
        checklist_item1 = card.checklist_items.create({:text => "first", :completed => "false", :position => 0})
        checklist_item2 = card.checklist_items.create({:text => "second", :completed => "false", :position => 1})
        checklist_item3 = card.checklist_items.create({:text => "third", :completed => "false", :position => 2})
        post :mark, :project_id => project.identifier, :item_id => checklist_item2.id, :completed => "true"
        post :mark, :project_id => project.identifier, :item_id => checklist_item1.id, :completed => "true"
        post :mark, :project_id => project.identifier, :item_id => checklist_item3.id, :completed => "true"
        assert_equal(["second", "first", "third"], card.reload.completed_checklist_items.map(&:text))
      end
  end

  def test_should_return_not_found_when_card_not_found
    with_first_project do |project|
      post :create, :project_id => project.identifier, :card_number => nil, :item => 'first item'
      assert_response :not_found
    end
  end

  def test_should_not_create_item_when_item_text_is_too_long
    with_first_project do |project|
      card = project.cards.first
      post :create, :project_id => project.identifier, :card_number => card.number, :item => 'This is a very long item and should get truncated to two hundred and fifty six characters ' * 10
      assert_response :bad_request
      card.reload
      assert_equal 0, card.checklist_items.count
    end
  end

  def test_should_not_create_item_when_item_text_is_blank
    with_first_project do |project|
      card = project.cards.first
      post :create, :project_id => project.identifier, :card_number => card.number, :item => ''
      assert_response :bad_request
      card.reload
      assert_equal 0, card.checklist_items.count
    end
  end

  def test_should_delete_item
    with_first_project do |project|
      card = project.cards.first
      item = CardChecklistItem.create!(:card => card, :project => project, :text => "item to be deleted")

      post :delete, :project_id => project.identifier, :item_id => item.id
      assert_response :ok

      assert_blank card.checklist_items
    end
  end


  def test_should_only_delete_if_item_exists
    with_first_project do |project|
      post :delete, :project_id => project.identifier, :item_id => 99999
      assert_response :ok
    end
  end

  def test_should_reorder_items
    with_new_project do |project|
      login_as_admin
      card = project.cards.create!(:card_type_name => 'Card', :name => 'FooBar')
      item1 = CardChecklistItem.create!(:card => card, :project => project, :text => "1", :position => 0)
      item2 = CardChecklistItem.create!(:card => card, :project => project, :text => "2", :position => 1)
      item3 = CardChecklistItem.create!(:card => card, :project => project, :text => "3", :position => 2)

      assert_equal item1.id, card.incomplete_checklist_items[0].id
      assert_equal item2.id, card.incomplete_checklist_items[1].id
      assert_equal item3.id, card.incomplete_checklist_items[2].id

      new_order = [ item1.id.to_s, item3.id.to_s, item2.id.to_s ]
      post :reorder, :project_id => project.identifier, :items => new_order
      assert_response :ok

      assert_equal item1.id, card.reload.incomplete_checklist_items[0].id
      assert_equal item3.id, card.incomplete_checklist_items[1].id
      assert_equal item2.id, card.incomplete_checklist_items[2].id
    end
  end

  def test_should_return_error_when_no_items_passed_to_reorder
    with_first_project do |project|
      post :reorder, :project_id => project.identifier, :items => []
      assert_response 400

      post :reorder, :project_id => project.identifier
      assert_response 400
    end
  end

  def test_should_mark_item_as_complete
    MingleConfiguration.with_metrics_api_key_overridden_to('key') do
      with_first_project do |project|
        card = project.cards.first
        item = CardChecklistItem.create!(:card => card, :project => project, :text => "item to be completed")

        post :mark, :project_id => project.identifier, :item_id => item.id, :completed => "true"
        assert @controller.events_tracker.sent_event?('checked_checklist_item', { :completed => "true" })
        assert item.reload.completed?
      end
    end
  end

  def test_should_mark_item_as_incomplete
    MingleConfiguration.with_metrics_api_key_overridden_to('key') do
      with_first_project do |project|
        card = project.cards.first
        item = CardChecklistItem.create!(:card => card, :project => project, :text => "item to be incomplete")

        post :mark, :project_id => project.identifier, :item_id => item.id, :completed => "false"
        assert @controller.events_tracker.sent_event?('checked_checklist_item', { :completed => "false" })

        assert_equal false, item.reload.completed?
      end
    end
  end

  def test_should_create_item_if_marking_an_already_deleted_item_and_mark_it
    with_first_project do |project|
      card = project.cards.first

      post :mark, :project_id => project.identifier, :item_id => 9999, :completed => "true", :item_text => "deleted item being marked", :card_number => card.number

      item = CardChecklistItem.find_by_text("deleted item being marked")
      assert_not_nil item
      assert_equal true, item.reload.completed?
    end
  end

  def test_should_update_text_for_item
    with_first_project do |project|
      card = project.cards.first
      item = CardChecklistItem.create!(:card => card, :project => project, :text => "item to be updated")

      post :update, :project_id => project.identifier, :item_id => item.id, :item_text => "item updated"

      assert_equal "item updated", item.reload.text
    end
  end

  def test_should_create_an_item_if_updating_an_item_that_was_deleted_by_another_user
    with_first_project do |p|
     post :update, :project_id => p.identifier, :item_id => 9999, :item_text => "deleted item being updated", :item_completed => true, :card_number => p.cards.first.number
     assert_not_nil CardChecklistItem.find_by_text("deleted item being updated")
    end
  end

end
