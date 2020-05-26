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

class CardsControllerBulkOperationTest < ActionController::TestCase

  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    login_as_member
    @project = project_without_cards
    @project.activate
  end

  def test_bulk_transition_should_show_message_if_no_transition_select
    post :bulk_transition, :project_id => @project.identifier, :transition_id => ""
    assert flash[:error].include?("Please select a transition.")
  end

  def test_bulk_destroy_cards
    login_as_proj_admin
    card_one =create_card!(:name  => 'card one for bulk destroy')
    card_two =create_card!(:name  => 'card two for bulk destroy')
    @project.reload
    assert_equal 2, @project.cards.size
    post :bulk_destroy, :project_id => @project.identifier, :selected_cards => "#{card_one.id},#{card_two.id}"
    assert flash[:notice]
    assert_equal 0, @project.cards.size
  end

  def test_destroy_cards
    login_as_proj_admin
    card_one = create_card!(:name  => 'card one for destroy')
    card_two = create_card!(:name  => 'card two for destroy')
    card_two.update_attribute :description, 'card2 des'
    card_two.update_attribute :description, 'card2 des 2'

    @project.reload
    assert_equal 2, @project.cards.size
    # go to list to load up prev/next list
    get :list, :project_id => @project.identifier
    get :show, :project_id => @project.identifier, :number => card_one.number

    post :destroy, :project_id => @project.identifier, :number => card_one.number
    assert_redirected_to :action => 'show', :number => card_two.number
    assert flash[:notice]
    assert_equal 1, @project.cards.size

    get :show, :project_id => @project.identifier, :number => card_two.number
    post :destroy, :project_id => @project.identifier, :number => card_two.number
    assert_redirected_to :action => 'list'
    assert flash[:notice]
    assert_equal 0, @project.reload.cards.size
    history = History.for_period(@project, :period => :all_history)
    assert history.events.empty?
  end

  def test_project_member_should_not_be_able_to_destroy_card
    card =create_card!(:name => 'card not allowed member to delete')
    assert card, @project.cards.find_by_name(card.name)

    get :list, :project_id => @project.identifier
    assert_raise ApplicationController::UserAccessAuthorizationError do
      post :destroy, :project_id => @project.identifier, :number => card.number
    end
    assert card, @project.cards.find_by_name(card.name)
  end

  def test_project_member_should_not_be_able_to_bulk_destroy_card
    card_one =create_card!(:name  => 'card one for bulk destroy')
    card_two =create_card!(:name  => 'card two for bulk destroy')
    assert_raise ApplicationController::UserAccessAuthorizationError do
      post :bulk_destroy, :project_id => @project.identifier, :selected_cards => "#{card_one.id},#{card_two.id}"
    end
    assert_equal 2, @project.cards.size
  end

  def test_bulk_update_properties_only_changes_changed_property
    status = @project.find_property_definition('status')
    card = create_card!(:name => 'card')

    xhr :post, :bulk_set_properties, :project_id => @project.identifier, :changed_property => status.name, :properties => { 'Status' => 'open', 'Iteration' => '1'}, :selected_cards => card.id.to_s
    assert_equal 'open', card.reload.cp_status
    assert_equal nil, card.cp_iteration
  end

  # bug 3343
  def test_bulk_set_properties_panel_shows_error_when_card_selection_no_longer_valid_because_card_not_in_tree
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.find_by_name('three level tree')
      story1 = project.cards.find_by_name('story1')

      xhr :get, :bulk_set_properties_panel, :project_id => project.identifier, :selected_cards => story1.id.to_s, :tree_name => 'three level tree', :style => 'list'
      assert_no_rjs 'replace', 'flash', /Please make another selection and try again./

      card_no_longer_in_tree = story1
      tree_configuration.remove_card(card_no_longer_in_tree)

      xhr :get, :bulk_set_properties_panel, :project_id => project.identifier, :selected_cards => card_no_longer_in_tree.id.to_s, :tree_name => 'three level tree', :style => 'list'
      assert_rjs 'replace', 'flash', Regexp.new(json_escape("Card #{'story1'.html_bold} has either been removed from the tree or deleted while you were working.  Please make another selection and try again."))
    end
  end

  def test_bulk_set_properties_panel_shows_error_when_card_selection_no_longer_valid_because_card_destroyed
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.find_by_name('three level tree')
      story1 = project.cards.find_by_name('story1')

      xhr :get, :bulk_set_properties_panel, :project_id => project.identifier, :selected_cards => story1.id.to_s, :style => 'list'
      assert_no_rjs 'replace', 'flash', /Please make another selection and try again./

      card_no_longer_in_tree = story1
      tree_configuration.remove_card(card_no_longer_in_tree)
      card_no_longer_in_tree.destroy

      xhr :get, :bulk_set_properties_panel, :project_id => project.identifier, :selected_cards => card_no_longer_in_tree.id.to_s, :style => 'list'
      assert_rjs 'replace', 'flash', /A selected card has been deleted while you were working.  Please make another selection and try again./
    end
  end

  def test_bulk_transition_should_not_execute_transition_if_no_comment_when_transition_is_require_comment
    open_transition = create_transition(@project, 'Open',
            :card_type => @card,
            :required_properties => {:status => nil},
            :set_properties => {:status => 'open'},
            :require_comment => true)
    card = create_card!(:name => "I am card")
    card_2 = create_card!(:name => "I am card two")
    selected_cards = [card.id.to_s, card_2.id.to_s].join(',')
    post :bulk_transition, :project_id => @project.identifier, :transition_id => open_transition.id, :selected_cards => selected_cards
    follow_redirect
    assert_equal nil, card.reload.cp_status
    assert_equal nil, card_2.reload.cp_status
    assert_error
  end

  def test_bulk_transition_should_save_comment_on_transition_execution_if_require_comment
    open_transition = create_transition(@project, 'Open',
            :card_type => @card,
            :required_properties => {:status => nil},
            :set_properties => {:status => 'open'},
            :require_comment => true)
    card = create_card!(:name => "I am card")
    card_2 = create_card!(:name => "I am card two")
    selected_cards = [card.id.to_s, card_2.id.to_s].join(',')
    post :bulk_transition, :project_id => @project.identifier, :transition_id => open_transition.id, :selected_cards => selected_cards, :comment => {:content => "transition comment"}
    assert_equal "transition comment", card.reload.discussion.first.murmur
    assert_equal "transition comment", card_2.reload.discussion.first.murmur
  end

  def test_user_sees_nice_error_message_when_trying_to_bulk_update_property_to_value_with_opening_and_closing_parentheses
    card = @project.cards.create!(:name => 'hi there', :card_type => @project.card_types.first)
    xhr :post, :bulk_set_properties, :project_id => @project.identifier, :changed_property => 'Status',
               :properties => { 'Status' => '(whoa)' }, :selected_cards => card.id.to_s
    assert_rjs :replace, 'flash', Regexp.new(json_escape('Status: <b>\(whoa\)<\/b> is an invalid value'))
  end

  # bug 4686
  def test_bulk_removing_a_tag_should_update_number_of_cards_on_screen
    (1..4).each do |i|
      card = @project.cards.create!(:name => "cardomatic #{i}", :card_type_name => 'Card')
      card.tag_with('thisisace')
      card.save!
    end

    thisisace_tag = @project.tags.find_by_name('thisisace')
    card_to_remove_tag_from = @project.cards.find_by_name('cardomatic 1')

    post :bulk_remove_tag, :project_id => @project.identifier, :tagged_with => "thisisace", :tag_id => "#{thisisace_tag.id}", :selected_cards => "#{card_to_remove_tag_from.id}"
    assert_match /Listed below: 1 to 3 of 3/, @response.body
  end

  def test_bulk_set_properties_should_update_number_of_cards_on_screen
    @project.reload
    (1..4).each do |i|
      @project.cards.create!(:name => "cardomatic #{i}", :cp_status => 'na ge zhe ge', :card_type_name => 'Card')
    end

    card_to_change_status_of = @project.cards.find_by_name('cardomatic 1')
    post :bulk_set_properties, :project_id => @project.identifier, :changed_property => 'Status', :properties => { 'Status' => 'open' },
         :selected_cards => card_to_change_status_of.id.to_s, :filters => ["[Status][is][na ge zhe ge]"]
    assert_match /Listed below: 1 to 3 of 3/, @response.body
  end

  # bug 6335
  def test_when_select_all_bulk_set_properties_should_report_number_of_cards_updated
    @project.reload
    (1..4).each do |i|
      @project.cards.create!(:name => "cardomatic #{i}", :cp_status => 'na ge zhe ge', :card_type_name => 'Card')
    end

    card_to_change_status_of = @project.cards.find_by_name('cardomatic 1')
    post :bulk_set_properties, :project_id => @project.identifier, :changed_property => 'Status', :properties => { 'Status' => 'open' },
         :selected_cards => card_to_change_status_of.id.to_s, :filters => ["[Status][is][na ge zhe ge]"], :all_cards_selected => 'true'

    assert_equal "4 cards updated.", flash[:notice]
  end

  #  This test failed using mysql and so exposed bug #6436. Uncomment when we fix that
  # # bug 6335
  # def test_when_select_all_bulk_delete_tags_should_report_number_of_cards_updated_when_filter_by_tag_being_deleted
  #     (1..4).each do |i|
  #       card = @project.cards.create!(:name => "cardomatic #{i}", :card_type_name => 'Card')
  #       card.tag_with('thisisace')
  #       card.save!
  #     end
  #
  #     thisisace_tag = @project.tags.find_by_name('thisisace')
  #     card_to_remove_tag_from = @project.cards.find_by_name('cardomatic 1')
  #
  #   post :bulk_remove_tag, :project_id => @project.identifier, :tagged_with => "thisisace", :tag_id => "#{thisisace_tag.id}",
  #        :selected_cards => card_to_remove_tag_from.id.to_s, :all_cards_selected => 'true'
  #
  #   assert_equal "4 cards updated.", flash[:notice]
  # end

  def test_bulk_set_properties_should_report_number_of_cards_updated
    @project.reload
    (1..4).each do |i|
      @project.cards.create!(:name => "cardomatic #{i}", :cp_status => 'na ge zhe ge', :card_type_name => 'Card')
    end

    card_to_change_status_of = @project.cards.find_by_name('cardomatic 1')
    post :bulk_set_properties, :project_id => @project.identifier, :changed_property => 'Status', :properties => { 'Status' => 'open' },
         :selected_cards => card_to_change_status_of.id.to_s, :filters => ["[Status][is][na ge zhe ge]"], :all_cards_selected => 'false'

    assert_equal "1 card updated.", flash[:notice]
  end

end
