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

class DisplayTabsTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    @project.activate
    @member = login_as_member
    @controller = OpenStruct.new(:current_tab => {
                                   :name => 'All',
                                   :type => 'All'
                                 },
                                 :card_context => CardContext.new(@project, {}),
                                 :session => {})
    class << @controller
      include UserAccess
    end
    @tabs = DisplayTabs.new(@project, @controller)
  end

  def teardown
    cleanup_repository_drivers_on_failure
  end

  def test_knows_tab_order
    assert_equal ['Overview', 'Dependencies', 'All', 'History'], @tabs.collect(&:name)
  end

  def test_display_tabs_act_like_the_old_tab_info
    tab = DisplayTabs::AllTab.new(@project)
    assert_equal 'All', tab[:name]
    assert_equal 'All', tab[:type]
  end

  def test_reorder_tabs
    original_order = @tabs.sortable_tabs.collect(&:identifier)
    new_order = original_order.shuffle
    assert @tabs.reorder!(new_order)
    assert_equal new_order, @tabs.collect(&:identifier)
  end

  def test_save_persists_tab_order
    original_order = @tabs.sortable_tabs.collect(&:identifier)
    new_order = original_order.shuffle
    assert @tabs.reorder!(new_order)
    @project.reload
    @tabs = DisplayTabs.new(@project, @controller)
    assert_equal new_order, @tabs.collect(&:identifier)
  end

  def test_tabs_not_in_the_persisted_order_end_up_at_the_end
    assert @tabs.reorder!(['All'])
    @project.reload
    @tabs = DisplayTabs.new(@project, @controller)
    assert_equal ["All", "Overview", "Dependencies", "History"], @tabs.collect(&:identifier)
  end

  def test_wiki_tabs_and_card_list_view_tabs_can_be_reordered
    page = @project.pages.create!(:name => 'test page')
    wiki_favorite = @project.tabs.of_pages.create!(:favorited => page)

    view = @project.card_list_views.create_or_update(:view => { :name => "view fav" }, :filters => ['[type][is][card]'])
    assert view.valid?
    view.tab_view = true
    view.save!
    view_favorite = view.favorite

    assert @tabs.reorder!([wiki_favorite.id, "All", view_favorite.id, "Overview", "History", "Dependencies"])
    @project.reload
    @tabs = DisplayTabs.new(@project, @controller)
    assert_equal [wiki_favorite.id.to_s, "All", view_favorite.id.to_s, "Overview", "History", "Dependencies"], @tabs.collect(&:identifier)
  end

  def test_should_include_predefined_tabs
    tabs = @tabs.collect(&:name)
    assert_include 'Overview', tabs
    assert_include 'All', tabs
    assert_include 'History', tabs
  end

  def test_overview_should_be_the_first_tab
    assert_equal 'Overview', @tabs.collect(&:name).first
  end

  def test_source_should_appear_when_repository_is_set_for_project
    assert_not_include 'Source', @tabs.collect(&:name)
    driver = svn_repository
    configure_subversion_for(@project, {:repository_path => driver.repos_dir})
    @project.save!
    @tabs.reload
    assert_include 'Source', @tabs.collect(&:name)
  end

  def test_source_should_not_appear_when_repository_is_set_for_project_but_scm_feature_is_off
    assert_not_include 'Source', @tabs.collect(&:name)
    driver = svn_repository
    configure_subversion_for(@project, {:repository_path => driver.repos_dir})
    @project.save!
    @tabs.reload
    begin
      FEATURES.deactivate("scm")
      assert_not_include 'Source', @tabs.collect(&:name)
    ensure
      FEATURES.activate("scm")
    end
  end

  def test_should_include_view_tab_that_user_saved
    create_tabbed_view('Stories', @project, :filters => ['[type][is][story]'])
    create_tabbed_view('Open Stories', @project, :filters => ['[type][is][story]', '[status][is][open]'])
    assert_include 'Open Stories', @tabs.collect { |tab| tab.name }
    assert_include 'Stories', @tabs.collect { |tab| tab.name }
  end

  def test_overview_tab_should_use_overview_page_url_as_params
    overview_tab = @tabs.overview_tab
    assert_equal 'Overview', overview_tab.name
    assert_equal 'projects', overview_tab.params[:controller]
    assert_equal 'overview', overview_tab.params[:action]
    assert_equal @project.identifier, overview_tab.params[:project_id]
    assert_equal 'w', overview_tab.access_key
  end

  def test_source_tab_should_point_to_head_revision
    driver = svn_repository
    configure_subversion_for(@project, {:repository_path => driver.repos_dir})
    source_tab = @tabs.source_tab
    assert_equal 'source', source_tab.params[:controller]
    assert_equal 'index', source_tab.params[:action]
    assert_equal 'HEAD', source_tab.params[:rev]
    assert_equal @project.identifier, source_tab.params[:project_id]
  end

  def test_view_tab_should_have_name_same_with_view_and_params_point_to_cards
    view = create_tabbed_view('Stories', @project, :columns => 'type,status,priority')
    view_tab = @tabs.find_by_identifier(view.favorite.id)
    assert_equal view.name, view_tab.name
    assert_card_list_view_params({:columns => 'type,status,priority', :controller => 'cards', :action => 'list', :tab => 'Stories'}, view_tab.params)
  end

  def test_view_tab_should_use_params_in_context_if_tab_is_stored_to_context
    view = create_tabbed_view('Stories', @project, :columns => 'type,status,priority')
    @controller.card_context = CardContext.new(@project, 'Stories_tab' => {CardContext::NO_TREE => {:columns => 'type'}})
    tab = @tabs.find_by_identifier(view.favorite.id)
    assert_equal 'type', tab.params[:columns]
  end

  def test_tab_should_be_current_if_the_controller_tells_it
    assert !@tabs.find_by_identifier(overview_tab.identifier).current?
    @controller.current_tab = DisplayTabs::OverviewTab.new(@project)
    assert @tabs.find_by_identifier(overview_tab.identifier).current?
    assert_equal @tabs.current, @tabs.find_by_identifier(overview_tab.identifier)
  end

  def test_html_id_for_tab_should_underscorelized
    assert_equal 'tab_overview', overview_tab.html_id
  end

  def test_view_tab_should_not_be_dirty_there_is_not_same_view_in_card_contex
    view = create_tabbed_view('Stories', @project, :columns => 'type,status,priority')
    assert !@tabs.find_by_identifier(view.favorite.id).dirty?
  end

  def test_view_tab_should_be_dirty_if_params_from_context_is_different_with_view
    view = create_tabbed_view('Stories', @project, :columns => 'type,status,priority')
    setup_context_with_state('Stories', :columns => 'type')
    assert @tabs.find_by_identifier(view.favorite.id).dirty?
  end

  def test_view_tab_should_not_be_dirty_if_params_from_context_differs_only_by_defaults
    view = create_tabbed_view('All Grid', @project, :style => 'grid')
    @controller.card_context = CardContext.new(@project, 'All_tab' => {:style => 'list'})
    assert !@tabs.find_by_identifier(view.favorite.id).dirty?
    all_tab = @tabs.find_by_identifier("All")
    assert all_tab.current?
    assert_false all_tab.dirty?
  end

  private

  def svn_repository
    driver = with_cached_repository_driver(name) do |driver|
      driver.create
      driver.user = 'bob'
      driver.initialize_with_test_data_and_checkout
      driver.add_file('new_file_1.txt', 'some content')
      driver.commit "add #13"
      driver.user = 'joe'
      driver.add_file('new_file_2.txt', 'some content')
      driver.commit "add #157"
    end
  end

  def setup_context_with_state(tab, state)
    @controller.card_context = CardContext.new(@project, {})
    view = CardListView.construct_from_params(@project, state)
    view.instance_eval do
      def view.card_count
        25
      end
    end
    @controller.card_context.store_tab_state(view, tab, CardContext::NO_TREE)
  end

  def overview_tab
    @tabs.overview_tab
  end
end
