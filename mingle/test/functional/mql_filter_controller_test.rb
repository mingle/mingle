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

class MqlFilterControllerTest < ActionController::TestCase
  include HelpDocHelper, ActionView::Helpers::AssetTagHelper

  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    login_as_member
    @project = card_query_project
    @project.activate
  end

  def test_should_show_mql_filter_tab_when_filter_by_mql
    get :list, :project_id => @project.identifier, :filters => {:mql => 'type = Card'}
    assert_equal nil, select_element("div#advanced-filter-container").attributes['style']
    assert_equal 'display: none;', select_element("div#filter-container").attributes['style']
  end

  def test_columns_selectable_on_list_should_be_any_properties_that_applicable_to_types_from_mql_filter
    get :list, :project_id => @project.identifier, :filters => {:mql => ' type = card '}
    assert_select '#column-selector ul li', {:count => @project.property_definitions.size + 3} #all properties + type + created_by + modified_by

    create_type_and_create_a_card_for_it('story', ['size'])
    get :list, :project_id => @project.identifier, :filters => {:mql => 'type = story'}

    assert_select '#column-selector ul li', {:count => 4} #size + type + created_by + modified_by

    create_type_and_create_a_card_for_it('bug', ['owner'])
    get :list, :project_id => @project.identifier, :filters => {:mql => 'type = story or type = bug'}

    assert_select '#column-selector ul li', {:count => 5} #owner + size + type + created_by + modified_by
  end

  def test_should_show_validation_error_when_mql_is_invalid
    get :list, :project_id => @project.identifier, :filters => {:mql => ' something is not correct '}
    assert_select 'div#error', :html => /Filter is invalid. Card property &#39;#{"something".html_bold}&#39; does not exist!/

    get :list, :style => 'grid', :project_id => @project.identifier, :filters => {:mql => ' something is not correct '}
    assert_select 'div#error', :html => /Filter is invalid. Card property &#39;#{"something".html_bold}&#39; does not exist!/
  end

  def test_should_validate_filter_mql_specified_part_and_show_error_message
    get :list, :project_id => @project.identifier, :filters => {:mql => 'select name where type=story'}
    assert_select 'div#error', :html => /Filter is invalid. #{"SELECT".html_bold} is not required to filter by MQL. Enter MQL conditions only./
  end

  def test_error_message_should_contain_link_to_help_and_link_to_reset_filter
    get :list, :project_id => @project.identifier, :filters => {:mql => 'select name where type=story'}
    assert_select 'div#error a[href=?]', link_to_help('Filter list by MQL')
    assert_select 'div#error a[href=?]', "/projects/card_query_project/cards/list?style=list&amp;tab=All"
  end

  def test_should_support_usage_of_from_tree
    with_three_level_tree_project do |project|
      get :list, :project_id => project.identifier, :filters => {:mql => 'FROM TREE "three level tree" WHERE type=story'}

      assert_response :success
      assert_no_error
      assert_select '#cards tbody tr', {:count => 2}
    end
  end

  def test_should_be_able_to_switch_to_grid_view_when_using_mql_filter
    get :list, :project_id => @project.identifier, :filters => {:mql => ' type=card'}
    assert_select 'span#list-grid-toggle'
    get :list,  :style => 'grid', :project_id => @project.identifier, :filters => {:mql => 'type=card'}
    assert_response :success
  end

  def test_bulk_edit_properties_should_be_multual_properties_of_all_implied_card_types
    xhr :get, :bulk_set_properties_panel, :project_id => @project.identifier, :filters => {:mql => 'type = card'}, :all_cards_selected => 'true'
    assert_property_names_in_bulk_edit_panel_equal @project.find_card_type('card').property_definitions.collect(&:name)

    create_type_and_create_a_card_for_it('story', ['status', 'size'])
    create_type_and_create_a_card_for_it('bug', ['status'])

    xhr :get, :bulk_set_properties_panel, :project_id => @project.identifier, :filters => {:mql => 'type = bug or type = story'}, :all_cards_selected => 'true'
    assert_property_names_in_bulk_edit_panel_equal ['Status']
  end

  def test_reset_filter_should_clean_filter
    view = CardListView.construct_from_params(@project, :filters => {:mql => 'type = card'}, :style => 'list')
    view.name = 'view'
    view.save!
    view.tab_view = true
    view.save!

    get :list, :project_id => @project.identifier, :filters => {:mql => 'type = card'}, :style => 'list', :tab => 'view'
    assert_select 'li#tab_view #reset_to_tab_default', false
    get :list, :project_id => @project.identifier, :filters => {:mql => 'type = story'}, :style => 'list', :tab => 'view'
    assert_select 'li#tab_view #reset_to_tab_default', true
  end

  private

  def assert_property_names_in_bulk_edit_panel_equal(expects)
    assert_response :success
    assert_not_nil selection = assigns['card_selection']
    @project.with_active_project do
      assert_equal expects.sort, selection.property_definitions.collect(&:name).sort
    end
  end

  def create_type_and_create_a_card_for_it(type_name, properties)
    by_first_admin_within(@project) {
      setup_card_type(@project, type_name, :properties => properties)
      create_card!(:name => "#{type_name}1", :type => type_name)
    }
  end

  def select_element(selector)
    assert_select(selector, {:count => 1}).first
  end


end
