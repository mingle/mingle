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

require File.expand_path(File.dirname(__FILE__) + '/../../../acceptance/acceptance_test_helper')

# Tags: gridview, ranking
class Scenario123CardRankingOnGridViewTest < ActiveSupport::TestCase
  fixtures :users, :login_access
  STATUS = "status"

    def setup
      destroy_all_records(:destroy_users => false, :destroy_projects => true)
      @browser = selenium_session
      @project = create_project(:prefix => 'scenario_123', :admins => [users(:proj_admin)])
      @project.activate
      login_as_proj_admin_user

      create_property_definition_for(@project, STATUS)
      @card1 = create_card!(:name => 'card1', :status => 'new', :card_type => 'Card')
      @card2 = create_card!(:name => 'card2', :status => 'open', :card_type => 'Card')
      @card3 = create_card!(:name => 'card3', :status => 'new', :card_type => 'Card')
      @card4 = create_card!(:name => 'card4', :status => 'open', :card_type => 'Card')
      @card5 = create_card!(:name => 'card5', :status => 'new', :card_type => 'Card')
      @card6 = create_card!(:name => 'card6', :status => 'open', :card_type => 'Card')
      navigate_to_grid_view_for(@project)
    end

    def teardown
      @browser.wait_for_all_ajax_finished
    end

    # TODO: expand this to involve more than one cell [mingle1/#10629]
    def test_rank_card_in_same_cell_when_group_by_row
      group_rows_by(STATUS)
      drag_and_drop_card_to(@card5, @card3)
      assert_ordered('card_1','card_5','card_3')
      assert_ordered('card_2','card_4','card_6')

      ungroup_by_row_in_grid_view
      assert_ordered('card_1','card_5','card_2', 'card_3','card_4','card_6')
    end

    # TODO: move this one to scenario 28 later
    def test_should_maintain_ranking_order_even_in_groups
      group_columns_by(STATUS)
      assert_ordered('card_2','card_4','card_6')
      assert_ordered('card_1','card_3','card_5')
    end

    # TODO: consider moving to cards controller test
    def test_card_from_quick_add_appears_last
      card_type = @project.card_types.first
      card_defaults = card_type.card_defaults
      card_defaults.update_properties :status => "new"

      group_columns_by(STATUS)

      new_card_number = add_card_via_quick_add("card7")

      assert_card_in_lane(STATUS, "new", new_card_number)
      assert_ordered('card_1','card_3','card_5', "card_7")
    end

    # TODO: consider moving to cards controller test
    def test_card_from_excel_appears_last
      group_columns_by(STATUS)

      header_row = ['number', 'name', 'status']
      card_data = [['7', 'card7', "new"]]

      import_in_grid_view(excel_copy_string(header_row, card_data))
      new_card = Project.find_by_identifier(@project.identifier).cards.find_by_name("card7")
      assert_card_in_lane(STATUS, "new", new_card.number)
      assert_ordered('card_1','card_3','card_5', "card_7")
    end
end
