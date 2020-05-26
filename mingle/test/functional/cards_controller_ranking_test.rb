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

class CardsControllerRankingTest < ActionController::TestCase
  include CardRankingTestHelper

  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    login_as_member
    @project = first_project
    @project.activate
  end

  def test_reranking_cards
    with_project_without_cards do |project|
      card1, card2 = (1..2).collect{ |i| create_card!(:name => i.to_s) }
      moving_card = create_card!(:name => 'M')
      xhr :post, :set_value_for, :project_id => project.identifier, :card_number => moving_card.number, :rerank => { :following_card_number => card1.number },
          :group_by => {'lane' => "status"}, :style => "grid", :value => "closed"

      assert_equal ['M', '1', '2'], project_card_names_sorted_by_ranking(project)

      xhr :post, :set_value_for, :project_id => project.identifier, :card_number => moving_card.number, :rerank => { :leading_card_number => card2.number },
          :group_by => {'lane' => "status"}, :style => "grid", :value => "closed"

      assert_equal ['1', '2', 'M'], project_card_names_sorted_by_ranking(project)
    end
  end

  def test_rerank_without_group_by
    with_project_without_cards do |project|
      card1, card2 = (1..2).collect{ |i| create_card!(:name => i.to_s) }
      moving_card = create_card!(:name => 'M')

      xhr :post, :set_value_for, :project_id => project.identifier, :card_number => moving_card.number, :rerank => { :following_card_number => card1.number }
      assert_response :success
      assert_equal ['M', '1', '2'], project_card_names_sorted_by_ranking(project)
    end
  end

  def test_should_show_rank_checkbox_is_checked_by_default_on_first_load_of_grid_view
    get :list, :project_id => @project.identifier, :style => 'grid'

    assert_select "#rank_checkbox[checked]"
  end

  def test_rank_checkbox_should_switch_between_enabled_and_disabled
    get :list, :project_id => @project.identifier, :style => "grid"
    assert_select '#rank_checkbox[checked]', {:count => 1}
    get :list, :project_id => @project.identifier, :style => "grid", :rank_is_on => "false"
    assert_select '#rank_checkbox[checked]', {:count => 0}
  end

  def test_reranking_cards_in_transition_only_lane
    with_project_without_cards do |project|
      status = project.find_property_definition('status')
      status.update_attribute(:transition_only, true)

      card1, card2 = (1..2).collect{ |i| create_card!(:name => i.to_s, :status => 'closed') }
      moving_card = create_card!(:name => 'M', :status => 'closed')

      xhr :post, :set_value_for, :project_id => project.identifier,
        :card_number => moving_card.number, :rerank => { :following_card_number => card2.number, :leading_card_number => card1.number },
        :group_by => {'lane' => "status"}, :style => "grid", :value => "closed"

      assert_equal ['1', 'M', '2'], project_card_names_sorted_by_ranking(project)
      assert_no_error_in_ajax_response
    end
  end

  #bug #6230
  def test_should_not_show_rank_checkbox_to_readonly_user
    read_only_user = User.find_by_login('longbob')
    @project.add_member(read_only_user, :readonly_member)
    login_as_longbob
    get :list, :project_id => @project.identifier, :style => 'grid'
    assert_response :success
    assert_select '#ranking_control', {:count => 0}
  end

  def test_rerank_card_in_rows_without_lanes_should_work_correctly
    with_project_without_cards do |project|
      card1, card2, card3 = (1..3).collect{ |i| create_card!(:name => i.to_s) }
      xhr :post, :set_value_for, :project_id => project.identifier,
        :card_number => card3.number, :rerank => { :following_card_number => card2.number, :leading_card_number => card1.number },
        :group_by => {'row' => 'status'}, :style => "grid", :value => "closed"
      assert_response :success
      assert_equal ['1', '3', '2'], project_card_names_sorted_by_ranking(project)
    end
  end

  #bug 12477
  def test_rerank_card_witnin_same_row_grouped_by_transition_only_property_should_not_trigger_auto_transition
    with_project_without_cards do |project|
      status_prop = project.find_property_definition('status')
      assert status_prop.update_attributes(:transition_only => true)
      card1, card2, card3 = (1..3).collect{ |i| create_card!(:name => i.to_s, :status => "closed") }
      xhr :post, :set_value_for, :project_id => project.identifier,
          :card_number => card3.number, :rerank => { :following_card_number => card2.number, :leading_card_number => card1.number },
          :group_by => {'row' => 'status'}, :style => "grid", :value => ""
      assert_response :success
      assert_nil flash[:error]
      assert_equal ['1', '3', '2'], project_card_names_sorted_by_ranking(project)
      assert_equal ["closed", "closed", "closed"], [card1, card2, card3].collect(&:cp_status)
    end
  end

  # bug 8960
  def test_rerank_cards_and_changing_lanes_should_execute_auto_transition
    with_project_without_cards do |project|
      status = project.find_property_definition('status')
      status.update_attribute(:transition_only, true)

      transition = create_transition(project, 'status', :required_properties => { :status => 'new' }, :set_properties => { :status => 'closed', :Assigned_to => 'Jon' })

      moving_card = create_card!(:name => 'M', :status => "new")
      card1, card2 = (1..2).collect { |i| create_card!(:name => i.to_s, :status => "closed") }

      # current order is ['1', '2'] in 'closed' lane.  Move 'M' into that lane, between those two cards.
      response = xhr :post, :set_value_for, :project_id => project.identifier, :card_number => moving_card.number, :value => "closed", :group_by => {'lane' => "status"}, :rerank => { :following_card_number => card2.number, :leading_card_number => card1.number }

      assert_equal ['1', 'M', '2'], project_card_names_sorted_by_ranking(project)
      assert_equal "closed", moving_card.reload.cp_status
      assert_equal "Jon", moving_card.reload.cp_assigned_to
    end
  end
end
