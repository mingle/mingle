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

# Tags: scenario, gridview
class GridViewUiTest < ActiveSupport::TestCase

  fixtures :users, :login_access

  STATUS = 'Status'
  NEW = 'new'
  OPEN = 'open'
  SIZE = 'size'
  SIZE1 = 'size1'
  ITERATION_SIZE = 'iteration size'
  AVERAGE = 'avg'

  STORY = 'story'
  DEFECT = 'defect'
  ITERATION = 'iteration'

  PRIORITY = 'priority'
  URGENT = 'URGENT'
  HIGH = 'High'
  TYPE = 'Type'

  RELEASE = 'Release'
  CARD = 'Card'


  PROPERTY_WITHOUT_VALUES = 'property_without_values'
  PASSWORD_FOR_LONGBOB_USER = 'longtest'

  MANAGED_TEXT_PROPERTY = 'managed text list'


  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @mingle_admin = users(:admin)
    @project_admin_user = users(:proj_admin)
    @team_member = users(:project_member)
    @project = create_project(:prefix => 'scenario_28', :users => [@team_member], :admins => [@project_admin_user])
    setup_property_definitions(STATUS => [NEW, OPEN], PRIORITY => [URGENT, HIGH], :property_without_values => [])
    login_as_proj_admin_user
    @card = create_card!(:name => 'first card')
  end

  def test_resize_while_all_lanes_are_present_should_resize_cards_down_accordingly
    setup_numeric_property_definition(SIZE1, %w(1 2 3 4 5 6 7 8 9 10))
    setup_card_type(@project, STORY, :properties => [SIZE1, PRIORITY, STATUS])
    card = create_card!(:name =>'me should resize', :card_type => STORY, SIZE1 => 1)
    navigate_to_grid_view_for(@project)
    group_columns_by(SIZE1)
    normal_lane_width  = @browser.get_eval("this.browserbot.getCurrentWindow().$('#{card.html_id}').parentNode.getWidth()").to_i
    normal_card_width  = @browser.get_eval("this.browserbot.getCurrentWindow().$('#{card.html_id}').getWidth()").to_i
    normal_card_height = @browser.get_eval("this.browserbot.getCurrentWindow().$('#{card.html_id}').getHeight()").to_i
    add_lanes(@project, SIZE1, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10])
    smaller_lane_width  = @browser.get_eval("this.browserbot.getCurrentWindow().$('#{card.html_id}').parentNode.getWidth()").to_i
    smaller_card_width  = @browser.get_eval("this.browserbot.getCurrentWindow().$('#{card.html_id}').getWidth()").to_i
    smaller_card_height = @browser.get_eval("this.browserbot.getCurrentWindow().$('#{card.html_id}').getHeight()").to_i
    assert smaller_lane_width < normal_lane_width, 'Resizing cards is not quite working'
    assert smaller_card_width < normal_card_width, 'Resizing cards is not quite working'
    assert smaller_card_height < normal_card_height, 'Resizing cards is not quite working'
  end
end
