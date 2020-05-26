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

class CardsControllerDeletionTest < ActionController::TestCase

  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_member
  end

  def test_destroy_cards_in_trees
    with_three_level_tree_project do |project|
      login_as_proj_admin
      story1 = project.cards.find_by_name('story1')
      post :destroy, :project_id => project.identifier, :number => story1.number
      assert_response :redirect
      assert flash[:error].nil?
      assert project.cards.find_by_name('story1').nil?
    end
  end

  def test_delete_card_that_belongs_tree_should_show_warings
    with_three_level_tree_project do |project|
      login_as_proj_admin
      iteration1 = project.cards.find_by_name('iteration1')
      post :confirm_delete, :project_id => project.identifier, :number => iteration1.number
      assert_response :success
      assert_match "Belongs to 1 tree: #{"three level tree".html_bold}", json_unescape(@response.body)
      assert_match("Used as a tree relationship property value on #{'2 cards'.html_bold}. Tree relationship property, #{'Planning iteration'.html_bold}, will be (not set) for all affected cards", json_unescape(@response.body))
    end
  end

  def test_bulk_destroy_cards_in_trees
    with_three_level_tree_project do |project|
      login_as_proj_admin
      story1 = project.cards.find_by_name('story1')
      iteration1 = project.cards.find_by_name('iteration1')
      post :bulk_destroy, :project_id => project.identifier, :selected_cards => "#{story1.id},#{iteration1.id}"
      assert flash[:error].nil?
      assert project.cards.find_by_name('story1').nil?
      assert project.cards.find_by_name('iteration1').nil?
    end
  end

  def test_bulk_delete_card_that_belongs_tree_should_show_warings
    with_three_level_tree_project do |project|
      login_as_proj_admin
      iteration1 = project.cards.find_by_name('iteration1')
      post :confirm_bulk_delete, :project_id => project.identifier, :selected_cards => "#{iteration1.id}"
      assert_response :success
      assert_match "Belongs to 1 tree: #{"three level tree".html_bold}", json_unescape(@response.body)
      assert_match("Used as a tree relationship property value on #{'2 cards'.html_bold}. Tree relationship property, #{'Planning iteration'.html_bold}, will be (not set) for all affected cards", json_unescape(@response.body))
    end
  end

  def test_should_have_bulk_delete_button_in_tree_list_view
    with_three_level_tree_project do |project|
      login_as_admin
      get :list, :project_id => project.identifier, :tree_name => 'three level tree'
      assert_response :success
      assert_select "input#bulk-delete-button"
    end
  end

  def test_delete_button_should_be_available_for_cards_in_trees
    with_three_level_tree_project do |project|
      login_as_proj_admin
      iteration1 = project.cards.find_by_name('iteration1')
      get :show, :project_id => project.identifier, :number => iteration1.number
      assert_response :success
      assert_select 'a.delete[href=javascript:void(0)]', :text => 'Delete'
    end
  end

  def test_confirm_delete_should_show_even_when_there_are_no_specific_known_usages_of_the_card
    login_as_admin
    with_new_project do |project|
      card = create_card!(:name => 'nomen', :card_type_name => project.card_types.first.name)
      post :confirm_delete, :project_id => project.identifier, :number => card.number
      assert_response :success
      assert_include "<h2>Delete card</h2>", json_unescape(@response.body)
    end
  end

  def test_deleting_already_deleted_card_gives_appropriate_error
    login_as_admin
    with_new_project do |project|
      post :confirm_delete, :project_id => project.identifier, :number => 93874587348957349875
      assert_equal "The card you attempted to delete no longer exists.", flash[:error]
    end
  end

  def test_confirm_delete_should_warn_about_use_in_other_cards
    login_as_admin
    with_card_query_project do |project|
      project.cards.each(&:destroy)
      related_card = create_card!(:name => 'related card', :card_type_name => project.card_types.first.name)
      ['card1', 'card2'].each do |name|
        card = create_card!(:name => name)
        card.cp_related_card = related_card
        card.save!
      end
      post :confirm_delete, :project_id => project.identifier, :number => related_card.number
      assert_response :success
      assert_match "Used as a card relationship property value on #{'2 cards'.html_bold}", json_unescape(@response.body)
    end
  end

end
