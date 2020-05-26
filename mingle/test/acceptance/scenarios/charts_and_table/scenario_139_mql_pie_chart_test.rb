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

#Tags: mql, macro, chart, PieChart

class Scenario139MqlPieChartTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  PIE_CHART= 'pie-chart'
  INSERT_PIE_CHART = 'Insert Pie Chart'
  PIE_CHART_ALL_PARAMETERS = ['data', 'project','chart-width','chart-height','radius']
  PIE_CHART_NON_DEFAULT_PARAMETERS = ['project','chart-width','chart-height','radius']
  PIE_CHART_DEFAULT_PARAMETERS = ['data']
  SELECT_EXAMPLE = 'Example: SELECT property, aggregate WHERE condition'

  PIE_CHART_DEFAULT_CONTENT = %{
  pie-chart
    data: SELECT property, aggregate WHERE condition
}

  PRIORITY = "priority"
  SIZE = 'size'

  SAVED_VIEW = '='
  HIGH = 'high'
  LOW = 'low'
  BUG = 'bug'
  SIMPLE_CARD = 'simple card'

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project_admin_user = users(:proj_admin)
    @project = create_project(:prefix => 'scenario_137', :admins => [@project_admin_user, users(:admin)])
    @priority = setup_property_definitions(PRIORITY => [HIGH, LOW])
    @size = create_managed_number_list_property(SIZE, [1, 2, 3])
    @type_bug = setup_card_type(@project, BUG, :properties => [PRIORITY, SIZE])
    login_as_proj_admin_user
    @cookie = create_card!(:name => 'cookie', :card_type => BUG, PRIORITY => HIGH, SIZE => 1)
    @cracker = create_card!(:name => 'cracker', :card_type => BUG, PRIORITY => HIGH, SIZE => 2)
    @waffle = create_card!(:name => 'waffle', :card_type => BUG, PRIORITY => LOW, SIZE => 3)
  end

   # bug 8173
  def test_charts_should_be_rendered_on_card_show_page_as_anonymous
    register_license_that_allows_anonymous_users
    login_as_proj_admin_user
    open_card_for_edit(@project, @waffle)

    pie_content = %{
      pie-chart
        data: select name, sum(size)
        chart-width: 300
        chart-height: 300
        radius: 50
    }

    create_free_hand_macro_and_save(pie_content)
    navigate_to_project_admin_for(@project)
    assert_project_anonymous_accessible_present
    enable_project_anonymous_accessible_on_project_admin_page

    logout

    open_card(@project, @waffle)
    wait_for_card_contents_to_load
    @browser.wait_for_element_present class_locator('c3')
    %w(cookie cracker waffle).each do |label|
      @browser.assert_element_present c3_data_label(label)
    end
  end

    #Story 7890 - Using THIS CARD.property in macro.
    def test_can_use_this_card_property_value_for_the_parameters_used_in_pivot_table_macro
      chart_width = setup_numeric_property_definition("chart_width", ["200"])
      chart_height = setup_numeric_property_definition("chart_height", ["200"])
      radius = setup_numeric_property_definition("radius", ["50"])
      add_properties_for_card_type(@type_bug,[chart_width, chart_height, radius])
      bug_1 = create_card!(:name => 'story_1', :card_type => BUG, SIZE => '2', PRIORITY => "#{HIGH}", "chart_width" => 200, "chart_height" => 200, "radius" => 60)
      bug_2 = create_card!(:name => 'story_2', :card_type => BUG, SIZE => '1',PRIORITY => "#{LOW}")
      open_card(@project, bug_1.number)

      click_edit_link_on_card
      pie_content = %{
      pie-chart
        data: Select number, count(*) where type = THIS CARD.type
        chart-width: THIS CARD.chart_width
        chart-height: THIS CARD.chart_height
        radius: THIS CARD.radius
    }

      create_free_hand_macro(pie_content)

      wait_for_wysiwyg_editor_ready
      edit_macro('pie-chart')
      assert_equal_ignore_cr(pie_content.strip, @browser.get_value(class_locator('cke_dialog_ui_input_textarea', 1)))

      click_cancel_on_wysiwyg_editor
      save_card
      wait_for_card_contents_to_load
      @browser.assert_element_not_present("css=.error")
   end

   def test_pie_chart_should_show_display_name_and_login_name_with_rendered_user_properties
     another_user = users(:admin)
     setup_user_definition('owner')
     card_1 = create_card!(:name => 'cookie', :card_type => BUG, 'owner' =>  @project_admin_user.id)
     card_2 = create_card!(:name => 'cracker', :card_type => BUG, 'owner' => another_user.id)
     login_as_proj_admin_user
     open_card_for_edit(@project, @waffle)
     add_pie_chart_and_save_for("owner", "count(*)",:render_as_text => true)
     open_card(@project, @waffle)
     click_link_with_ajax_wait(WikiPageId::CHART_DATA_LINK)
     assert_chart('slice_labels',"#{another_user.name} (#{another_user.login}), #{@project_admin_user.name} (#{@project_admin_user.login}), (not set)")
   end

end
