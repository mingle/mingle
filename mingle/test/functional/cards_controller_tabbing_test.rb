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

class CardsControllerTabbingTest < ActionController::TestCase

  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    login_as_member
    @project = create_project :users => [User.find_by_login('member')]
    @project.add_member(User.find_by_login('proj_admin'), :project_admin)
    @type_bug = @project.card_types.create!(:name => 'Bug')
    @type_story = @project.card_types.create!(:name => 'story')
    setup_property_definitions :old_type => ['story', 'bug'], :feature => ['cards'], :priority => ['high', 'low'],
      :release => [1], :iteration => [1,2], :status => ['open', 'closed']
    @project.reload.property_definitions.each do |definition|
      definition.update_attributes(:card_types => @project.card_types)
    end
    @non_member_admin = User.find_by_login('admin')
    @project.remove_member(@non_member_admin)
  end

  def test_should_highlight_tab_specified_by_tab_name_parameter_for_card_listings
    create_card!(:name => 'card1', :card_type => 'bug', :priority => 'high')
    create_card!(:name => 'card2', :card_type => 'bug', :priority => 'low', :feature => 'cards', :release => '1')
    create_card!(:name => 'card3', :card_type => 'bug')
    story_card = create_card!(:name => 'card4', :card_type => 'story')

    create_tabbed_view('Bugs', @project, :filters => ['[type][is][bug]'])
    create_tabbed_view('Stories', @project, :filters =>['[type][is][story]'])

    get 'list', {:project_id => @project.identifier, :tab => 'bugs'}
    assert_equal 'Bugs', @controller.current_tab[:name]

    get 'list', {:project_id => @project.identifier, :tab => 'bugs', :filters => ['[Type][is][story]']}
    assert_equal 'Bugs', @controller.current_tab[:name]

    get 'show', {:project_id => @project.identifier, 'number' => story_card.number}
    assert_equal 'Bugs', @controller.current_tab[:name]
  end

  def test_should_highllight_tab_based_on_card_context_if_card_in_context
    create_card!(:name => 'card1', :card_type => 'bug', :priority => 'high')
    create_card!(:name => 'card2', :card_type => 'bug', :priority => 'low', :feature => 'cards', :release => '1')
    bug = create_card!(:name => 'card3', :card_type => 'bug')
    story = create_card!(:name => 'card4', :card_type => 'story')

    create_tabbed_view('Bugs', @project, :filters => ['[type][is][bug]'])
    create_tabbed_view('Stories', @project, :filters =>['[type][is][story]'])

    get 'list', {:project_id => @project.identifier, :tab => 'bugs', :filters => ['[type][is][bug]']}
    get 'show', {:project_id => @project.identifier, 'number' => bug.number}
    assert_equal 'Bugs', @controller.current_tab[:name]

    get 'show', {:project_id => @project.identifier, 'number' => story.number}
    assert_equal 'All', @controller.current_tab[:name]

    get 'list', {:project_id => @project.identifier, :tab => 'Stories', :filters => ['[type][is][story]']}
    get 'show', {:project_id => @project.identifier, 'number' => story.number}
    assert_equal 'Stories', @controller.current_tab[:name]

    get 'show', {:project_id => @project.identifier, 'number' => bug.number}
    assert_equal 'All', @controller.current_tab[:name]
  end

  def test_should_not_highlight_all_tab_if_no_tab_name_parameter_is_present
    story_card = create_card!(:name => 'card4', :card_type => 'story')
    get 'show', {:project_id => @project.identifier, 'number' => story_card.number}
    assert_equal 'All', @controller.current_tab[:name]
  end

  def test_should_not_highlight_all_tab_upon_direct_navigation_to_a_saved_view
    create_named_view('bugs', @project, :filters => ['[Type][is][bug]'])
    get 'list', {:project_id => @project.identifier, 'view' => {'name' => 'bugs'}}
    assert_equal 'All', @controller.current_tab[:name]
  end

  def test_navigating_away_from_view_with_saved_columns_allows_user_to_navigate_back_into_same_view
    create_card!(:name => 'card1', :card_type => 'bug', :priority => 'high')
    card2 = create_card!(:name => 'card2', :card_type => 'bug', :priority => 'low', :feature => 'cards', :release => '1')
    create_card!(:name => 'card3', :card_type => 'bug')
    create_card!(:name => 'card4', :card_type => 'story')

    create_tabbed_view('Bugs', @project, :filters => ['[type][is][bug]'])
    create_tabbed_view('Stories', @project, :filters =>['[type][is][story]'])

    get 'list', {:project_id => @project.identifier, :filters => ['[type][is][bug]'], :tab => 'Bugs'}
    assert_equal 'Bugs', @controller.current_tab[:name]

    @controller.card_context.clear_current_list_navigation_card_numbers

    get 'show', {:project_id => @project.identifier, 'number' => card2.number}
    assert_equal 'All', @controller.current_tab[:name]
    assert_equal(['[Type][is][bug]'], session["project-#{@project.id}"]['Bugs_tab'][CardContext::NO_TREE][:filters])
    assert_nil(session["project-#{@project.id}"]['last_tab']) #if you switched to a card outside the context, you lose the last tab info
  end

  def test_handle_navigation_directly_to_card_with_an_existing_list_selection
    @card_on_list = create_card!(:name => 'card1', :card_type => 'bug', :priority => 'high')
    @card_not_on_list = create_card!(:name => 'card1', :card_type => 'bug', :priority => 'low')
    @high_priority_tab = create_tabbed_view('High Priority', @project, :filters => ['[priority][is][high]'])

    get :list, :project_id => @project.identifier, :filters => ['[priority][is][high]'], :tab => 'High Priority'

    get :show, :project_id => @project.identifier, :number => @card_not_on_list.number
    assert_tag :div, :attributes => {:id => 'card-index'}, :content => /#{@card_not_on_list.number}/
    assert_equal 'All', @controller.current_tab[:name]
    assert_select "li#tab_all.current-menu-item"

    get :list, :project_id => @project.identifier, :filters => ['[priority][is][high]'], :tab => 'High Priority'

    get :show, :project_id => @project.identifier, :number => @card_on_list.number
    assert_tag :div, :attributes => {:id => 'card-index'}, :content => /#{@card_on_list.number}/
    assert_select "li#tab_high_priority.current-menu-item"

    get :show, :project_id => @project.identifier, :number => @card_not_on_list.number
    assert_tag :div, :attributes => {:id => 'card-index'}, :content => /#{@card_not_on_list.number}/
    assert_equal 'All', @controller.current_tab[:name]
    assert_select "li#tab_all.current-menu-item"

    get :show, :project_id => @project.identifier, :number => @card_on_list.number
    assert_tag :div, :attributes => {:id => 'card-index'}, :content => /#{@card_on_list.number}/
    assert_equal 'All', @controller.current_tab[:name]
  end

  def test_navigating_away_after_filter_should_retain_filter_on_return
    create_card!(:name => 'card1', :status => 'open', :iteration => '1')
    create_card!(:name => 'card2', :status => 'open', :iteration => '2')
    get 'list', {:project_id => @project.identifier, :filters => ['[iteration][is][1]'], :tab => DisplayTabs::AllTab::NAME}
    assert_card_list_view_params({:filters => ["[iteration][is][1]"], :action => 'list', :tab => DisplayTabs::AllTab::NAME}, session["project-#{@project.id}"]["All_tab"][CardContext::NO_TREE])
    view_first_card
    get 'index', {:project_id => @project.identifier, :filters => ["[iteration][is][1]"]}
    assert_redirected_to(card_list_view_params.merge({:project_id => @project.identifier, :action => 'list', :filters => ["[iteration][is][1]"], :tab => DisplayTabs::AllTab::NAME}))
   end

  def test_navigating_away_from_filtered_contents_of_a_named_tab_remembers_the_filter
    create_card!(:name => 'card1', :status => 'open', :iteration => '1')
    create_card!(:name => 'card2', :status => 'open', :iteration => '2')
    create_tabbed_view('iteration 1', @project, {:filters => ['[iteration][is][1]']})
    get 'list', {:project_id => @project.identifier, :filters => ['[iteration][is][1]'], 'columns' => ['status','iteration'], :tab => 'iteration 1'}
    assert_equal 'iteration 1', @controller.current_tab[:name]
    get 'list', {:project_id => @project.identifier, :filters => ['[iteration][is][1]', '[status][is][closed]'], 'columns' => ['status','iteration'], :tab => 'iteration 1'}

    assert_equal 'iteration 1', @controller.current_tab[:name]
    view_first_card
    assert_card_list_view_params({:filters => ['[iteration][is][1]','[status][is][closed]'], :columns => 'status,iteration', :action => 'list', :tab => 'iteration 1'}, @request.session["project-#{@project.id}"]['iteration 1_tab'][CardContext::NO_TREE])
  end

  def test_should_show_back_to_history_link_if_visiting_card_from_history_page
    post :create, :project_id => @project.identifier, :card => {:name => 'card name', :card_type => @project.card_types.first}, :properties => {:status => 'open'}

    @controller.card_context.store_tab_params({'controller' => 'history', 'period' => 'today', 'project_id' => @project.identifier}, 'History', CardContext::NO_TREE)
    get :show, :project_id => @project.identifier, :number => @project.cards.first.number

    assert_select '#up', {:count => 2, :text => 'Back to History'}
  end

  def test_should_show_back_to_search_link_if_visiting_card_from_history_page
    post :create, :project_id => @project.identifier, :card => {:name => 'card name', :card_type => @project.card_types.first}, :properties => {:status => 'open'}

    @controller.card_context.store_tab_params({'controller' => 'search', 'q' => 'search string', 'project_id' => @project.identifier}, 'Search', CardContext::NO_TREE)
    get :show, :project_id => @project.identifier, :number => @project.cards.first.number

    assert_select '#up', {:count => 2, :text => 'Back to Search'}
  end

  def test_should_show_back_to_wiki_page_if_visiting_card_from_history_page
    post :create, :project_id => @project.identifier, :card => {:name => 'card name', :card_type => @project.card_types.first}, :properties => {:status => 'open'}

    @controller.card_context.store_tab_params({'controller' => 'pages', 'page_identifier' => 'Overview', 'project_id' => @project.identifier}, 'Page', CardContext::NO_TREE)
    get :show, :project_id => @project.identifier, :number => @project.cards.first.number

    assert_select '#up', {:count => 2, :text => 'Back to Page'}
  end

  def test_should_show_up_to_last_tab_if_visiting_from_a_card_tab
    post :create, :project_id => @project.identifier, :card => {:name => 'card name', :card_type => @project.card_types.first}, :properties => {:status => 'open'}

    get :list, :project_id => @project.identifier
    get :show, :project_id => @project.identifier, :number => @project.cards.first.number

    assert_select '#up', {:count => 2, :text => 'Up to All'}
  end

  def test_should_retain_currebt_tab_if_directly_navigating_to_a_card_in_the_same_context
    story_1 = @project.cards.create!(:name => 'story 1', :card_type => @type_story)
    story_2 = @project.cards.create!(:name => 'story 2', :card_type => @type_story)
    bug_1 = @project.cards.create!(:name => 'bug 1', :card_type => @type_bug)

    stories_tab = create_tabbed_view('Stories', @project, :filters => ['[Type][is][Story]'])

    get :list, :project_id => @project.identifier, :tab => 'Stories', :filters => ['[Type][is][Story]']

    get :show, :project_id => @project.identifier, :number => story_1.number
    assert_equal 'Stories', @controller.current_tab[:name]

    get :show, :project_id => @project.identifier, :number => story_2.number
    assert_equal 'Stories', @controller.current_tab[:name]
  end

  def test_should_switch_to_all_tab_if_directly_navigating_to_a_card_not_in_the_same_context
    story_1 = @project.cards.create!(:name => 'story 1', :card_type => @type_story)
    story_2 = @project.cards.create!(:name => 'story 2', :card_type => @type_story)
    bug_1 = @project.cards.create!(:name => 'bug 1', :card_type => @type_bug)

    stories_tab = create_tabbed_view('Stories', @project, :filters => ['[Type][is][Story]'])

    get :list, :project_id => @project.identifier, :tab => 'Stories', :filters => ['[Type][is][Story]']

    get :show, :project_id => @project.identifier, :number => story_1.number
    assert_equal 'Stories', @controller.current_tab[:name]

    get :show, :project_id => @project.identifier, :number => bug_1.number
    assert_equal 'All', @controller.current_tab[:name]
  end

  def test_should_retain_context_if_directly_navigating_to_a_card_in_the_same_context
    story_1 = @project.cards.create!(:name => 'story 1', :card_type => @type_story)
    story_2 = @project.cards.create!(:name => 'story 2', :card_type => @type_story)
    bug_1 = @project.cards.create!(:name => 'bug 1', :card_type => @type_bug)

    stories_tab = create_tabbed_view('Stories', @project, :filters => ['[Type][is][Story]'])
    bugs_tab = create_tabbed_view('Bugs', @project, :filters => ['[Type][is][bug]'])

    get :list, :project_id => @project.identifier, :tab => 'Stories', :filters => ['[Type][is][Story]']

    get :show, :project_id => @project.identifier, :number => story_1.number
    assert_equal 'Stories', @controller.current_tab[:name]
    assert_select "#list-navigation", {:count => 2, :text => 'Card 2 of 2'}

    get :show, :project_id => @project.identifier, :number => story_2.number
    assert_equal 'Stories', @controller.current_tab[:name]
    assert_select "#list-navigation", {:count => 2, :text => 'Card 1 of 2'}
  end

  def test_should_lose_last_tab_info_when_navigating_past_first_card_result_from_history
    post :create, :project_id => @project.identifier, :card => {:name => 'story 1', :card_type => @type_story}
    post :create, :project_id => @project.identifier, :card => {:name => 'story 2', :card_type => @type_story}
    post :create, :project_id => @project.identifier, :card => {:name => 'bug 1', :card_type => @type_bug}


    story_1 = @project.cards.find_by_name('story 1')
    story_2 = @project.cards.find_by_name('story 2')
    bug_1 = @project.cards.find_by_name('bug 1')

    @controller.card_context.store_tab_params({'controller' => 'history', 'period' => 'today', 'project_id' => @project.identifier}, 'History', CardContext::NO_TREE)

    get :show, :project_id => @project.identifier, :number => story_1.number
    assert_equal 'All', @controller.current_tab[:name]
    assert_select "#up", {:count => 2, :text => 'Back to History'}

    get :show, :project_id => @project.identifier, :number => story_2.number
    assert_equal 'All', @controller.current_tab[:name]
    assert_select "#up", {:count => 2, :text => 'Up to All'}
  end

  def test_should_lose_last_tab_info_when_navigating_past_first_card_result_from_search_results
    post :create, :project_id => @project.identifier, :card => {:name => 'story 1', :card_type => @type_story}
    post :create, :project_id => @project.identifier, :card => {:name => 'story 2', :card_type => @type_story}
    post :create, :project_id => @project.identifier, :card => {:name => 'bug 1', :card_type => @type_bug}


    story_1 = @project.cards.find_by_name('story 1')
    story_2 = @project.cards.find_by_name('story 2')

    @controller.card_context.store_tab_params({'controller' => 'search', 'q' => 'search string', 'project_id' => @project.identifier}, 'Search', CardContext::NO_TREE)

    get :show, :project_id => @project.identifier, :number => story_1.number
    assert_equal 'All', @controller.current_tab[:name]
    assert_select "#up", {:count => 2, :text => 'Back to Search'}

    get :show, :project_id => @project.identifier, :number => story_2.number
    assert_equal 'All', @controller.current_tab[:name]
    assert_select "#up", {:count => 2, :text => 'Up to All'}
  end

  def test_should_show_truncated_name_of_view_in_up_link_for_long_view_names
    story_1 = @project.cards.create!(:name => 'story 1', :card_type => @type_story)
    create_tabbed_view('rumpelstiltskin', @project, :filters => ['[Type][is][Story]'])

    get :list, :project_id => @project.identifier, :tab => 'rumpelstiltskin', :filters => ['[Type][is][Story]']

    get :show, :project_id => @project.identifier, :number => story_1.number
    assert_select "#up", {:count => 2, :text => 'Up to rumpelstil...'}
  end

  def test_should_escape_tab_name_on_card_show_action_bar
    story_1 = @project.cards.create!(:name => 'story 1', :card_type => @type_story)
    create_tabbed_view('<b>123</b>', @project, :filters => ['[Type][is][Story]'])

    get :list, :project_id => @project.identifier, :tab => '<b>123</b>', :filters => ['[Type][is][Story]']

    get :show, :project_id => @project.identifier, :number => story_1.number
    assert_select "#up", {:count => 2, :html => /&lt;b&gt;123&lt;\/b&gt;/}

  end

  # Bug 3369.
  def test_hierarchy_view_should_allow_tab_reset
    with_filtering_tree_project do |project|
      hierarchy_view = CardListView.construct_from_params(project, {:tree_name => 'filtering tree', :style => 'hierarchy'})
      hierarchy_view.update_attributes(:name => "hire archie")
      hierarchy_view.favorite.tab_view = true
      hierarchy_view.save!

      get :list, :project_id => project.identifier, :style => 'hierarchy', :tab => 'hire archie', :tree_name => 'filtering tree', :excluded => ['release']
      assert_response :success
      assert_select "#reset_to_tab_default"
    end
  end

  def test_should_show_correct_tab_when_drilling_down_into_cards_from_a_tree_tab
    with_filtering_tree_project do |project|
      tree_view = CardListView.construct_from_params(project, {:tree_name => 'filtering tree', :style => 'tree'})
      tree_view.update_attributes(:name => "tree tab")
      tree_view.favorite.tab_view = true
      tree_view.save!

      get :list, :project_id => project.identifier, :style => 'tree', :tab => 'tree tab', :tree_name => 'filtering tree', :expands => '1'

      get :show, {:project_id => project.identifier, :number => '1'}
      assert_select "#up", {:count => 2, :text => 'Up to tree tab'}
    end
  end

  private
  def view_first_card
    get 'show', :project_id => @project.identifier, :number => @project.cards.first.number
  end
end
