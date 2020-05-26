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

class CardSelectorControllerTest < ActionController::TestCase
  def setup
    @controller = create_controller CardExplorerController, :own_rescue_action => true
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new    
    login_as_member
  end
  
  def test_filter_cards_with_context_mql_only
    with_first_project do |project|
      get :filter_cards, :project_id => project.identifier, :card_selector => {:context_mql => 'number=1'}
      assert_response :success
      assert_equal [1], assigns['cards'].collect(&:number)
    end
  end
  
  def test_filter_cards_with_both_context_mql_and_additional_query
    with_first_project do |project|
      project.cards.find_by_number(1).tag_with('atag,number1_tag')
      project.cards.find_by_number(4).tag_with('atag')
      xhr :get, :filter_cards, :project_id => project.identifier, :card_selector => {:context_mql => 'tagged with atag'}, :tagged_with => 'number1_tag'
      assert_response :success
      
      assert_equal [1], assigns['cards'].collect(&:number)
    end
  end
  
  def test_should_let_user_know_how_many_cards_in_result_after_search
    with_first_project do |project|
      get :filter_cards, :project_id => project.identifier, :card_selector => {:context_mql => 'number=1'}
      assert_include "Showing 1 result.", @response.body
    end
  end
  
  def test_should_let_user_know_which_part_of_results_showed_when_pagination_happened
    with_first_project do |project|
      get :filter_cards, :project_id => project.identifier, :card_selector => {:context_mql => 'number=1 or number=4'}, :per_page => 1
      assert_include "Showing first 1 result of 2.", @response.body
    end
  end
end
