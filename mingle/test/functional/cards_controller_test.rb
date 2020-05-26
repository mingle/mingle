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
require File.expand_path(File.dirname(__FILE__) + '/../messaging/messaging_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../unit/renderable_test_helper')


class CardsControllerTest < ActionController::TestCase
  include TreeFixtures::PlanningTree, ::RenderableTestHelper::Functional, MessagingTestHelper

  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @member = login_as_member
    @project = first_project
    @project.activate
  end

  def teardown
    logout_as_nil
    Clock.reset_fake
  end

  def test_in_progress
    with_new_project do |project|
      bob = User.find_by_login('bob')

      project.add_member(@member)
      project.add_member(bob)

      setup_user_definition("owner")
      setup_user_definition("pair")
      setup_user_definition("other")
      project.reload

      project.cards.create!(:name => 'one', :card_type_name => 'Card').update_attribute(:cp_pair, @member)
      project.cards.create!(:name => 'two', :card_type_name => 'Card').update_attribute(:cp_other, @member)
      project.cards.create!(:name => 'three', :card_type_name => 'Card').update_attribute(:cp_owner, @member)
      project.cards.create!(:name => 'four', :card_type_name => 'Card').update_attribute(:cp_owner, bob)

      login_as_member
      get :in_progress, :project_id => project.identifier
      result = ActiveSupport::JSON::decode(@response.body).map do |r|
        r["name"]
      end

      assert_equal ["one", "three", "two"], result.sort
    end
  end

  def test_should_escape_html_in_favorite_name
    name = '<script>hackThem();</script>'
    favorite = @project.card_list_views.create_or_update(:view => {:name => name}, :style => 'grid', :group_by => 'status')
    get :list, :project_id => @project.identifier, :style => 'grid'
    assert_select ".favorite-link", :text => truncate(name,  :length => 35).escape_html
  end

  def test_should_escape_html_in_filter_error_message
    get :list, :project_id => @project.identifier, :style => 'grid', :filters => ["[Type\n2<img src=a onerror=alert('xss')>][is][Card]"]
    assert_select "#error", :text => "Filter is invalid. Property Type\n2&lt;img src=a onerror=alert(&#39;xss&#39;)&gt; does not exist.&nbsp;Reset filter"
  end

  # bug #9181
  def test_property_tooltip_on_old_card_version_should_be_escaped
    with_new_project(:anonymous_accessible => true) do |project|

      set_anonymous_access_for(project, true)
      setup_managed_number_list_definition('release', [1,2]).update_attribute(:description, %(this "indicates" great))
      card = create_card!(:name => 'morning sf')

      project.add_member(User.find_by_login('bob'), :readonly_member)
      login_as_bob

      get :show, :project_id => project.identifier, :number => card.number

      assert_select ".property-name[title='release: this &quot;indicates&quot; great']"
    end
  end

  def test_index_should_redirect_to_different_action_according_param_style
     get :index, :project_id => @project.identifier
     assert_redirected_to :action => :list, :style => :list, :project_id => @project.identifier
     get :index, :style => :grid, :project_id => @project.identifier
     assert_redirected_to :action => :list, :style => :grid, :project_id => @project.identifier

     @project.tree_configurations.create!(:name => 'planning')
     get :index, :style => :tree, :project_id => @project.identifier, :tree_name => 'planning'
     assert_redirected_to :action => :list, :style => :tree, :project_id => @project.identifier
   end

   def test_saved_view_render_correct_template
     view = @project.card_list_views.create_or_update(:view => {:name => 'FooBarList'}, :tagged_with => 'iteration-2,status-open')
     get :index, :view => view.name, :project_id => @project.identifier
     assert_view_style_is 'list'

     view = @project.card_list_views.create_or_update(:view => {:name => 'FooBarGrid'}, :style => 'grid')
     get :index, :view => view.name, :project_id => @project.identifier
     assert_view_style_is 'grid'

     tree = @project.tree_configurations.create(:name => 'some tree')
     view = @project.card_list_views.create_or_update(:view => {:name => 'FooBarTree'}, :style => 'tree', :tree_name => tree.name)
     get :index, :view => view.name, :project_id => @project.identifier
     assert_view_style_is 'tree'
   end

   def test_list_xhr_should_not_refresh_tabs_partial_during_maximized_mode
     @project.card_list_views.create_or_update :view => { :name => 'normal' }, :style => 'grid'
     @project.card_list_views.create_or_update :view => { :name => 'max' }, :style => 'grid', :maximized => true
     xhr :get, :list, :project_id => @project.identifier, :view => { :name => 'max' }
     assert_response :success
     assert_not_include('$("hd-nav").replace(', @response.body)

     xhr :get, :list, :project_id => @project.identifier, :view => { :name => 'normal' }
     assert_include('$("hd-nav").replace(', @response.body)
   end

   def test_list_xhr_should_refresh_quick_add_context_menu
     @project.card_list_views.create_or_update :view => { :name => 'normal' }, :style => 'grid'

     xhr :get, :list, :project_id => @project.identifier, :view => { :name => 'normal' }
     assert_response :success
     assert_rjs_replace 'add_card_with_defaults'
   end

   def test_create_view_redirect_to_index_with_view_name_and_favorite_id
     post :create_view, :project_id => @project.identifier, :view => {:name => "some view"}, :style => 'grid'
     follow_redirect
     assert flash[:favorite_id]
     assert_view_style_is 'grid'
   end

   def test_create_view_should_not_populate_personal_favorite_textbox_with_new_team_favorite_name
     post :create_view, :project_id => @project.identifier, :view => { :name => 'some view' }, :style => 'list'
     follow_redirect
     assert_select "input#new-view-name-team[value='some view']"
     assert_select "input#new-view-name-my[value='']"
   end

   def test_async_create_view_does_not_redirect_on_success
    post :create_view_async, :project_id => @project.identifier, :view => { :name => 'some view' }, :ajax => true, :style => 'list'
    assert_response :ok
   end

   def test_async_create_view_renders_errors_as_text_on_failure
    post :create_view_async, :project_id => @project.identifier, :view => { :name => '' }, :ajax => true, :style => 'list'
    assert_response :unprocessable_entity
    assert_equal "Validation failed: Name can't be blank", @response.body
   end

   def test_saved_tree_as_view_and_go_to_the_view_with_view_name
     tree1 = @project.tree_configurations.create!(:name => 'planning')
     tree2 = @project.tree_configurations.create!(:name => 'tree feature')
     post :create_view, :project_id => @project.identifier, :view => {:name => "some view"}, :style => 'tree', :tree_name => 'tree feature'
     follow_redirect
     assert_view_style_is 'tree'
     assert_equal tree2, assigns['tree']
   end

   def test_should_get_rendered_contents_on_preview_post
     xhr :post, :preview, :card => {:name => 'This be cardy', :description => '[[foo]]'}, :project_id => @project.identifier, :properties => {"Type" => "Card"}
     link_to_page_foo = "href=\"/projects/#{Project.current.identifier}/wiki/foo\""
     assert_match link_to_page_foo, @response.body
   end

   # bug 9908
   def test_preview_of_an_unsaved_card_should_have_access_to_properties
     with_three_level_tree_project do |project|
       type = project.card_types.find_by_name('iteration')
       macro = "{{table query: SELECT number, COUNT(*) WHERE 'Planning iteration' = THIS CARD}}"
       xhr :post, :preview, :card => {:name => 'Unsaved card', :description => macro}, :project_id => project.identifier, :properties => {"Type" => type.name}
       assert_match "Macros using <b>THIS CARD</b> will be rendered when card is saved", @response.body
     end
   end

   def test_navigating_to_index_without_any_parameters_creates_an_empty_view
     get 'index', {:project_id => @project.identifier}
     assert_redirected_to 'controller' => 'cards', 'action' => 'list'
     assert_equal Hash.new, session["project-#{@project.id}"]
   end

  # bug 7845
  def test_bulk_adding_a_nonexistent_tag_will_remove_the_card_from_the_list_when_filtering_out_all_cards_without_the_tag
    non_existent_tag = 'nonexistenttag'
    card_one = @project.cards.create!(:name => 'will remain in list', :card_type_name => 'Card')
    card_two = @project.cards.create!(:name => 'will not be in list', :card_type_name => 'Card')
    assert !@project.tags.include?(non_existent_tag)

    xhr :post, 'bulk_add_tags', { :project_id => @project.identifier,
                                  :selected_cards => [card_two.id],
                                  :filters => { "mql" => "not tagged with '#{non_existent_tag}'" },
                                  :tags => non_existent_tag
                                }

    assert_match(/.*card_results.*update.*#{card_one.name}/, @response.body, 'Card one should be in the card list after adding a non-existent tag, but was not.')
    assert_no_match(/.*card_results.*update.*#{card_two.name}/, @response.body, 'Card two should not be in the card list after adding a non-existent tag, but was.')
  end

   def test_create_returns_to_last_tab_view
     create_card!(:name => 'card1', :status => 'open', :release => '1')
     create_card!(:name => 'card2', :status => 'closed', :release => '1')
     create_card!(:name => 'card3', :status => 'closed', :iteration => '2')
     list_view = {:project_id => @project.identifier, :tagged_with => 'release-1', :columns => 'status,release', :sort => 'status', :order => 'asc', :tab => DisplayTabs::AllTab::NAME }

     get 'list', list_view
     post 'create', {:project_id => @project.identifier, :card => {:name => 'my new card', :card_type => @project.card_types.first}, :tag_list => 'release-1'}
     assert_redirected_to list_view.merge(:action => 'list')
   end

   def test_card_view_shows_version_information
     card = create_card!(:name => 'card1', :status => 'open', :release => '1')
     card.tag_with('rss')
     card.save!
     get :show, :number => 1, :project_id => @project.identifier
     assert_tag :p, :content => /Latest version/, :descendant => {:tag => 'b', :content => 'v2'}
     get :show, :number => 1, :project_id => @project.identifier, :version => 1
     assert_tag :span, :content => /Old version/
   end

   def test_requesting_a_non_existent_version_shows_the_current_version
     card = create_card!(:name => 'card1', :status => 'open', :release => '1')
     card.save!
     get :show, :number => 1, :project_id => @project.identifier, :version => 66
     assert_tag :p, :content => /Latest version/
     assert_tag :div, :content => /Version 66 of this card doesn&#39;t exist. Display the current version instead./
   end

   def test_card_view_shows_version_information_of_card_with_deleted_type
     login_as_admin
     with_new_project do |project|
       story_type = project.card_types.create!(:name => 'Story')
       setup_property_definitions(:status =>['New', 'Open', 'Done'])

       card = create_card!(:name => 'card1', :status => 'Open', :card_type => story_type)
       assert_equal story_type, card.card_type
       card.card_type = project.card_types.find_by_name('Card')
       card.save!

       story_type.destroy

       get :show, :number => card.number, :project_id => project.identifier, :version => 1

       assert_tag :a, :attributes => {:id => 'card_type_name'}, :content => 'Story'
     end
   end

   def test_card_transitions_rendered_when_no_version_specified_in_url
     card = create_card!(:name => 'card 1', :status => 'open', :old_type => 'story')
     card.update_attribute(:name, 'new name for card 1')
     close = create_transition @project, 'Close', :required_properties => {:status => 'open', :old_type => 'story'}, :set_properties => {:status => nil}
     assert close.available_to?(card)

     get 'show', {:project_id => @project.identifier, :number => card.number}
     assert_tag :a, :content => 'Close'
   end

   def test_card_transitions_rendered_for_latest_version
     card =create_card!(:name => 'card 1', :status => 'open', :old_type => 'story')
     card.update_attribute(:name, 'new name for card 1')
     close = create_transition @project, 'Close', :required_properties => {:status => 'open', :old_type => 'story'}, :set_properties => {:status => nil}

     get 'show', {:project_id => @project.identifier, :number => card.number, :version => 2}
     assert_tag :a, :content => 'Close'
   end

   def test_card_transition_name_should_be_displayed_as_html_escaped
     card =create_card!(:name => 'card 1', :status => 'open', :old_type => 'story')
     card.update_attribute(:name, 'new name for card 1')
     close = create_transition @project, '<p>weird transition</p>', :required_properties => {:status => 'open', :old_type => 'story'}, :set_properties => {:status => nil}
     get 'show', :project_id => @project.identifier, :number => card.number

     assert_select 'a', :text => '&lt;p&gt;weird transition&lt;/p&gt;'
   end

   def test_card_transitions_not_rendered_for_old_versions
     card =create_card!(:name => 'card 1', :status => 'open', :old_type => 'story')
     card.update_attribute(:name, 'new name for card 1')
     close = create_transition @project, 'Close', :required_properties => {:status => 'open', :old_type => 'story'}, :set_properties => {:status => nil}

     assert close.available_to?(card)

     get 'show', {:project_id => @project.identifier, :number => card.number, :version => 1}
     assert_no_tag :a, :content => 'Close'
   end

  def test_lane_headers_show_links
    with_three_level_tree_project do |project|
      init_planning_tree_types
      get :list, :project_id => project.identifier, :style => 'grid', :group_by => {'lane' => 'planning iteration'}, :filters => ["[Type][is][Story]"]

      assert_response :success
      assert_select 'thead th a', :text => "release1 &gt; iteration1"
    end
  end

  def test_row_headers_show_links
    with_three_level_tree_project do |project|
      init_planning_tree_types
      get :list, :project_id => project.identifier, :style => 'grid', :group_by => {'row' => 'planning iteration'}, :filters => ["[Type][is][Story]"]

      assert_response :success
      assert_select 'tbody th a', :text => "iteration1"
    end
  end

   def test_group_by_user_properties_should_work_when_view_cards_as_grid
     prop_dev = @project.find_property_definition('dev')
     prop_dev.card_types = @project.card_types
     prop_dev.save!

     member = User.find_by_login('member')
     card = create_card!(:name => 'card for testing group by user properties')
     card.update_attribute(:cp_dev, member)

     get :list, :project_id => @project.identifier, :style => 'grid',:group_by => 'dev'
     assert_response :success

     assert_select '#swimming-pool thead th span', :match => "#{member.name} (1)"

     assert_select '.card-icon span', :text => "##{card.number}"
   end

   def test_aggregate_properties_are_avaliable_on_the_DOM
     card1 = create_card!(:name => 'card1', :release => 1)
     card2 = create_card!(:name => 'card2', :release => 5)

     response = get :list, :project_id => @project.identifier, :style => 'grid', :aggregate_type => {:column => 'SUM'}, :aggregate_property => {:column => 'release'}
     assert_match /data\-column\-aggregate\-type\=\"SUM\"/, response.body
     assert_match  /data-column-aggregate-property=\"Release\"/, response.body
   end

   def test_should_support_old_style_column_aggregate_by_on_grid
     card1 = create_card!(:name => 'card1', :release => 1)
     card2 = create_card!(:name => 'card2', :release => 5)

     response = get :list, :project_id => @project.identifier, :style => 'grid', :aggregate_type => 'SUM', :aggregate_property => 'release'
     assert_match /data\-column\-aggregate\-type\=\"SUM\"/, response.body
     assert_match  /data-column-aggregate-property=\"Release\"/, response.body
   end

   def test_should_support_old_style_aggregates_in_saved_views
     card1 = create_card!(:name => 'card1', :release => 1)
     card2 = create_card!(:name => 'card2', :release => 5)
     view = CardListView.find_or_construct(@project, {:style => 'grid', :aggregate_type => 'SUM', :aggregate_property => 'release'})
     view.name = 'open cards'
     view.save!
     assert_equal(1,1)
     response = get :list, :project_id => @project.identifier, :view => view.name
     assert_response :ok
     assert_match /data\-column\-aggregate\-type\=\"SUM\"/, response.body
     assert_match  /data-column-aggregate-property=\"Release\"/, response.body
   end

   def test_should_not_update_all_tab_with_api_call
     get :list, :project_id => @project.identifier, :filters => ["[Type][is][Card]"]
     all_tab = @controller.display_tabs.all_tab
     assert_equal "[Type][is][Card]", all_tab.params[:filters].first

     get :list, :project_id => @project.identifier, :filters => ["[Type][is][Bug]"], :format => "xml"
     all_tab = @controller.display_tabs.all_tab
     assert_equal "[Type][is][Card]", all_tab.params[:filters].first
   end

   def test_should_not_show_text_properties_in_options_for_group_by_and_colour_by_in_grid_mode
     assert_equal TextPropertyDefinition, @project.find_property_definition('id').class
     get :list, :project_id => @project.identifier, :style => 'grid'
     assert_no_tag :option, :attributes => {:value => 'id'}
   end

   def test_should_not_show_card_relationship_properties_in_options_for_group_by_in_grid_mode
     with_card_query_project do |project|
       get :list, :project_id => project.identifier, :style => 'grid'
       assert_no_tag :option, :attributes => {:value => 'related card'}
     end
   end

   def test_showing_card_page_should_be_readonly_when_the_card_is_version
     card =create_card!(:name => 'card for readonly version')
     card.update_attribute(:name, 'new name for card for readonly version')
     get :show, :project_id => @project.identifier, :number => card.number, :version => 1
     assert_no_tag :a, :content => 'Add description'
     assert_no_tag :a, :content => 'Edit'
     assert_no_tag :a, :content => 'Delete'
     assert_tag :a, :content => 'Show latest'
   end

   def test_can_view_card_when_project_has_text_property
     card = create_card!(:name => 'card one')
     get :show, :project_id => @project.identifier, :number => card.number
     assert @response.body.include?('card one')
   end

   def test_card_should_inherit_properties_when_it_is_created_from_list_filter_by_properties
     member = User.find_by_login('member')
     post :create, :project_id => @project.identifier, :properties => {'dev' => member.id, 'old_type' => 'bug'}, :card => {:name => 'This is my first card', :card_type => @project.card_types.first}

     assert assigns['card'].errors.empty?
     assert_equal member, assigns['card'].cp_dev
     assert_equal 'bug', assigns['card'].cp_old_type
   end

   def test_create_should_allow_hidden_property
     with_new_project do |project|
        story = project.card_types.create!(:name => 'Story')
        setup_property_definitions(:status =>[], :size => ['1'], :hidden_property =>['phoenix', 'good boy'])
        project.all_property_definitions.select { |property_definition| property_definition.name = 'hidden_property'}.first.update_attribute(:hidden, true)

        login_as_admin
        post :create, :project_id => project.identifier, :properties => { 'hidden_property' => 'phoenix', 'size' => '1'}, :card => {:name => 'This is my first card', :card_type => story }
        assert_equal 'phoenix', assigns['card'].cp_hidden_property
     end
   end


   def test_should_filter_by_empty_properties
     open_bug = create_card!(:name => 'open bug', :status => 'open', :old_type => 'bug')
     open_card = create_card!(:name => 'open card', :status => 'open')
     bug = create_card!(:name => 'bug', :old_type => 'bug')
     open_r1_story = create_card!(:name => 'open release-1 story', :status => 'open', :old_type => 'story', :release => 1)

     get :list, :project_id => @project.identifier, :filters => ["[status][is][]"]
     assert_tag :a, :attributes => {:id => "card-number-#{bug.number}"}, :content => bug.number.to_s

     get :list, :project_id => @project.identifier, :filters => ["[status][is][#{PropertyValue::IGNORED_IDENTIFIER}]"]
     [open_card, open_bug, bug, open_r1_story].each do |card|
       assert_tag :a, :attributes => {:id => "card-number-#{card.number}"}, :content => card.number.to_s
     end

     get :list, :project_id => @project.identifier, :filters => ["[status][is][#{PropertyValue::IGNORED_IDENTIFIER}]", "[old_type][is][bug]"]
     [open_bug, bug].each do |card|
       assert_tag :a, :attributes => {:id => "card-number-#{card.number}"}, :content => card.number.to_s
     end
     [open_card, open_r1_story].each do |card|
       assert_no_tag :a, :attributes => {:id => "card-number-#{card.number}"}, :content => card.number.to_s
     end
   end

   def test_should_be_able_to_delete_cards_on_a_new_session
     logout_as_nil
     login_as_admin
     open_bug = create_card!(:name => 'open bug', :status => 'open', :old_type => 'bug')
     post :destroy, :project_id => @project.identifier, :number => open_bug.number
     follow_redirect
     assert_notice "Card ##{open_bug.number} deleted successfully."
     logout_as_nil
   end

   def test_update_enumeration_property_color
     login_as_admin
     enum_value = @project.find_property_definition(:priority).enumeration_values.first
     post :update_property_color, :project_id => @project.identifier, :color_provider_type => EnumerationValue.name, :id => enum_value.id, :color_provider_color => 'new color', :style => 'grid', :color_by => 'priority'

     assert_equal 'new color', enum_value.reload.color
   end

   def test_update_card_type_property_color
     login_as_admin
     card_type = @project.card_types.first
     post :update_property_color, :project_id => @project.identifier, :color_provider_type => CardType.name, :id => card_type.id, :color_provider_color => 'new color', :style => 'grid', :color_by => 'type'

     assert_equal 'new color', card_type.reload.color
   end

   def test_update_property_color_should_has_management_access
     login_as_member
     card_type = @project.card_types.first
     assert_raise(ApplicationController::UserAccessAuthorizationError) {
       post :update_property_color, :project_id => @project.identifier, :color_provider_type => CardType.name, :id => card_type.id, :color_provider_color => 'new color'
     }
   end

   # we had a few problems caused by the fact that we were updating all card
   # properties when supposedly updating only a single property from the card
   # show page.  it turns out that it's much too big a deal to change this form
   # to only submit the changed property for the 1.1 release, so instead we'll
   # send along which property actually changed and only update that property
   def test_update_property_only_updates_the_changed_property
     @project.reload
     card = @project.cards.create!(:name => 'a card', :cp_status => 'open', :cp_iteration => '1', :card_type_name => 'Card')
     post('update_property', :project_id => @project.identifier, :card => card.id,
       :properties => {:status => 'closed', :iteration => '2'}, :changed_property => 'status')

     card.reload
     assert_equal '1', card.cp_iteration
     assert_equal 'closed', card.cp_status
   end

   def test_update_property_with_json_format
     card = @project.cards.create!(:name => 'a card', :cp_status => 'open', :card_type_name => 'Card')
     post('update_property', :project_id => @project.identifier, :card => card.id,
       :properties => {:status => 'closed'}, :changed_property => 'status', :format => 'json')
     assert_response :ok
     assert_equal '[]', @response.body

     card.reload
     assert_equal 'closed', card.cp_status
   end

   def test_update_property_with_json_format_should_response_errors
     card = @project.cards.create!(:name => 'a card', :cp_release => 1, :card_type_name => 'Card')
     post('update_property', :project_id => @project.identifier, :card => card.id,
       :properties => {:release => 'hello'}, :changed_property => 'release', :format => 'json')
     assert_response :ok
     assert_equal '["Release: \u003Cb\u003Ehello\u003C/b\u003E is an invalid numeric value"]', @response.body

     card.reload
     assert_equal '1', card.cp_release
   end

   def test_project_admin_should_be_able_to_update_an_existing_tabbed_view
     login_as_proj_admin

     open_cards = CardListView.find_or_construct(@project, {:filters => ["[status][is][Open]"]})
     open_cards.name = 'open cards'
     open_cards.save!
     open_cards.favorite.tab_view = true
     open_cards.save!

     post :create_view, :project_id => @project.identifier, :view => {:name => "open cards"}, :style => 'grid'
     follow_redirect
     assert_no_error
     assert_not_equal open_cards.to_params, @project.card_list_views.find_by_name('open cards').to_params
   end

   def test_team_member_should_be_able_to_update_an_existing_tabbed_view
     login_as_proj_admin

     open_cards = CardListView.find_or_construct(@project, {:filters => ["[status][is][Open]"]})
     open_cards.name = 'open cards'
     open_cards.save!
     open_cards.favorite.tab_view = true
     open_cards.save!

     login_as_member

     post :create_view, :project_id => @project.identifier, :view => {:name => "open cards"}, :style => 'grid'
     follow_redirect
     assert_no_error
     assert_not_equal open_cards.to_params, @project.card_list_views.find_by_name('open cards').to_params
   end

   def test_redirect_to_add_another_card_after_created_card
     post :create, :project_id => @project.identifier, :card => {:name => 'card name', :card_type => @project.card_types.first}, :properties => {:priority => 'high', :status => 'open'}, :add_another => true

     assert_redirected_to :action => :new, :properties => {:Priority => 'high', :Status => 'open'}
     card = @project.reload.cards.find_by_name('card name')
     assert_equal 'high', card.cp_priority
     assert_equal 'open', card.cp_status
     assert_nil card.cp_iteration
     assert_nil card.cp_release
   end



   def test_tree_view_should_show_tree_with_name_if_tree_name_specified
     @project.tree_configurations.create!(:name => 'planning tree')
     second_tree = @project.tree_configurations.create!(:name => 'Another Planning Tree')
     get :list, :project_id => @project.identifier, :tree_name => "another planning tree", :style => "tree"
     assert_response :success
     assert_equal second_tree.name, assigns['tree'].name
   end

   def test_tree_view_should_show_message_when_no_tree_name_specified
     @project.tree_configurations.create!(:name => 'planning tree')
     first_tree = @project.reload.tree_configurations.first
     get :list, :style => :tree, :project_id => @project.identifier
     assert_response :success
     assert_error "You must select a tree first"
   end

   def test_tree_view_should_give_out_tree_creation_link_if_user_is_admin
     login_as_admin
     @project.tree_configurations.delete_all
     get :list, :style => 'tree', :project_id => @project.identifier
     assert_response :success
     creation_link = link_to('Create the first tree', new_card_tree_path(:project_id => @project.identifier))
     assert_info "There are no trees for #{@project.name}. #{creation_link} now."
   end

   def test_tree_view_should_not_show_creating_link_if_user_is_normal_member
     login_as_member
     @project.tree_configurations.delete_all
     get :list, :project_id => @project.identifier, :style => 'tree'
     assert_response :success
     assert_info "There are no trees for #{@project.name}. Only a project administrator can create and configure a tree."
   end

   def test_numeric_list_property_definition_should_be_filtered_by_not_set
     assert @project.find_property_definition('release').numeric?
     card_type = @project.card_types.find_by_name('Card')
     card_type.property_definitions = [@project.find_property_definition('release')]
     card_type.save!
     get :list, :project_id => @project.identifier, :filters => ["[Type][is][Card]", "[release][is][]"]
     assert_response :success
   end

   # bug 2961
   def test_update_properties_should_trim_values
     card = create_card!(:name => 'best movie of all time: my giant', :priority => 'high')
     post :update_property, :project_id => @project.identifier, :changed_property => :'start date', :card => card.id, :properties => {:'start date' => ' 18 Oct 2008 '}
     assert_equal Date.new(2008, 10, 18), card.reload.cp_start_date.to_date
   end

   def test_update_properties_should_include_hidden_properties
     update_property_status_to_hidden_property

     card = create_card!(:name => 'why my eyes feel so sleepy', :priority => 'high', :status => 'open')
     post :update_property, :project_id => @project.identifier, :changed_property => 'status', :card => card.id, :properties => {:status => 'closed'}

     assert_equal 'closed', card.reload.cp_status
   end

  def test_should_be_able_to_add_to_a_tree_when_creating_a_card
    login_as_proj_admin
    create_tree_project(:init_two_release_planning_tree) do |project, tree, config|
      release_card = project.cards.find_by_name('release1')
      iteration_card = project.cards.find_by_name('iteration2')

      post :create, :project_id => project.identifier, :card => {:name => 'my story'}, :properties => {'Planning release' => release_card.id, 'Planning iteration' => iteration_card.id, :type => 'story'}

      story_card = project.cards.find_by_name('my story')
      assert_equal release_card.name, story_card.cp_planning_release.name
      assert_equal iteration_card.name, story_card.cp_planning_iteration.name
    end
  end

  def test_should_be_able_to_select_a_card_that_does_not_belong_to_the_tree_for_a_tree_property
    login_as_proj_admin
    create_tree_project(:init_empty_planning_tree) do |project, tree, config|
      iteration_card = create_card!(:name => 'the iteration', :card_type => 'iteration')
      story_card = create_card!(:name => 'the story', :card_type => 'story')

      post :update_property, :project_id => project.identifier, :changed_property => 'Planning iteration', :card => story_card.id, :properties => {'Planning iteration' => iteration_card.id}

      config.reload
      story_card.reload
      assert_nil story_card.cp_planning_release
      assert_equal iteration_card.name, story_card.cp_planning_iteration.name
    end
  end

  def test_column_selector_holds_union_of_properties_on_regular_list
    type_card = @project.card_types.find_by_name('Card')
    type_story = @project.card_types.create(:name => 'story')

    @project.cards.create!(:name => "some card", :card_type => type_card)

    status = @project.find_property_definition('Status')
    status.card_types = [type_story]
    status.save!

    iteration = @project.find_property_definition('Iteration')
    iteration.card_types = [type_card]
    iteration.save!

    priority = @project.find_property_definition('Priority')
    priority.card_types = @project.card_types
    priority.save!

    get :list, :project_id => @project.identifier

    assert_select "input#toggle_column_enumeratedpropertydefinition_#{priority.id}"
    assert_select "input#toggle_column_enumeratedpropertydefinition_#{iteration.id}"
    assert_select "input#toggle_column_enumeratedpropertydefinition_#{status.id}"
  end

  def test_column_selector_holds_union_of_properties_on_tree_list
    login_as_proj_admin
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types

      story_size = setup_numeric_property_definition('story size', [1, 2, 3])
      story_size.card_types = [type_story]
      story_size.save!

      iteration_size = setup_numeric_property_definition('iteration size', [1, 2, 3])
      iteration_size.card_types = [type_iteration]
      iteration_size.save!

      both_size = setup_numeric_property_definition('both size', [1, 2, 3])
      both_size.card_types = project.card_types
      both_size.save!

      get :list, :project_id => project.identifier

      assert_select "input#toggle_column_enumeratedpropertydefinition_#{both_size.id}"
      assert_select "input#toggle_column_enumeratedpropertydefinition_#{iteration_size.id}"
      assert_select "input#toggle_column_enumeratedpropertydefinition_#{story_size.id}"
    end
  end

  # bug 3619
  def test_user_sees_nice_error_message_when_trying_to_update_property_to_value_with_opening_and_closing_parentheses
    card = @project.cards.create!(:name => 'hi there', :card_type => @project.card_types.first)
    post :update_property, :project_id => @project.identifier, :card => card.id,
          :properties => {:status => '(whoa)'}, :changed_property => 'status'
    assert_equal ["Status: #{"(whoa)".bold} is an invalid value. Value cannot both start with '(' and end with ')' unless it is an existing project variable which is available for this property."], flash[:error]
  end

  def test_user_can_update_property_to_existing_plv_name_and_have_it_work
    status = @project.find_property_definition('status')
    plv = create_plv!(@project, :name => 'waka', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'hello', :property_definition_ids => [status.id])

    card = @project.cards.create!(:name => 'hi there', :card_type => @project.card_types.first)
    post :update_property, :project_id => @project.identifier, :card => card.id,
          :properties => {:status => '(waka)'}, :changed_property => 'status'

    assert_equal 'hello', card.reload.cp_status
  end

  # bug 8519
  def test_changing_the_card_type_of_card_used_as_value_of_plv_should_result_in_an_error_message
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      iteration3 = create_card!(:name => 'iteration3', :card_type => type_story)
      planning_iteration = project.find_property_definition('planning iteration')
      current_iteration = create_plv!(project, :name => 'current iteration', :value => iteration3.id, :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definition_ids => [planning_iteration.id])
      project.reload

      post :set_value_for, :card_number => iteration3.number, :group_by => {'lane' => "type"}, :style => "grid", :tab => "All", :value  => type_release.name, :project_id => project.identifier

      error = "Cannot change card type because card is being used as the value of project variable: #{'(current iteration)'.bold}"
      assert_equal [error], flash[:error]
    end
  end

  # bug 3732
  def test_using_invalid_tree_name_when_another_tree_exists_will_not_result_in_500_error
    @project.cards.create!(:name => 'some card', :card_type_name => 'Card')
    @project.tree_configurations.create!(:name => 'planning tree')
    get :list, :project_id => @project.identifier, :tree_name => "nonexistenttree", :style => 'tree'
    assert_template 'list'
    assert_error "There is no tree named #{'nonexistenttree'.html_bold}."
    assert_select "td", :text => "some card"
  end

  def test_should_escape_invalid_tree_name
    @project.tree_configurations.create!(:name => 'planning tree')
    get :list, :project_id => @project.identifier, :tree_name => "<script>alert(1)</script>", :style => 'tree'
    assert_template 'list'
    assert_error "There is no tree named <b>&lt;script&gt;alert(1)&lt;/script&gt;</b>."
  end

  def test_display_tree_should_from_work_space_otherwise_tree_will_be_created_twice
    @project.tree_configurations.create!(:name => 'planning')
    get :list, :project_id => @project.identifier, :tree_name => 'planning', :style => 'tree'
    display_tree = assigns(:display_tree)
    view = assigns(:view)
    assert_equal display_tree, view.workspace.expanded_cards_tree
  end

  def test_should_display_card_readonly_version_for_readonly_member
    card = create_card!(:name => 'hello')
    @bob = User.find_by_login('bob')
    @project.add_member(@bob, :readonly_member)
    login_as_bob
    get :show, :project_id => @project.identifier, :number => card.number
    assert_response :success
    assert_template 'show_card_version'
  end

  # 5638
  def test_cards_in_context_should_follow_the_list_view_when_tree_is_selected
    with_filtering_tree_project do |project|
      view = CardListView.construct_from_params(project, {:tree_name => 'filtering tree', :style => 'hierarchy'})
      get 'list', :project_id => project.identifier, :tree_name => 'filtering tree'
      assert_equal view.card_numbers, @controller.card_context.current_list_navigation_card_numbers
    end
  end

  def test_cards_context_should_only_include_cards_in_visible_lanes
    view = CardListView.construct_from_params(@project, :group_by => 'priority', :style => 'grid', :lanes => 'high')
    @project.cards.first(:order => :id).update_attributes(:cp_priority => 'high')
    @project.cards.last.update_attributes(:cp_priority => 'low')
    get 'list', view.to_params.merge(:project_id => @project.identifier)
    assert_equal 1, @controller.card_context.current_list_navigation_card_numbers.size
  end

  def test_charts_are_cached
    with_renderable_caching_enabled do
      card_content = %{
        {{
          pie-chart:
            data: SELECT Status, COUNT(*)
        }}
        {{
          pie-chart:
            data: SELECT Status, COUNT(*)
        }}
      }
      card = @project.cards.create!(:name => 'Nice Card', :description => card_content, :card_type_name => 'Card')

      get :chart, :id => card.id, :project_id => @project.identifier, :type => 'pie', :position => 1
      get :chart, :id => card.id, :project_id => @project.identifier, :type => 'pie', :position => 2

      [1,2].each do |position|
        assert_equal('pie', JSON.parse(Caches::ChartCache.get(card, 'pie', position))['data']['type'])
      end
    end
  end

  def test_charts_response_404_when_cannot_find_card_by_id
    @controller = create_controller CardsController, :own_rescue_action => true
    get :chart, :id => 89738242, :project_id => @project.identifier, :type => 'pie', :position => 1
    assert_redirected_to :action => "list"
  end

  def test_can_render_chart_data
    login_as_admin
    with_new_project do |project|
      setup_property_definitions :feature => [], :status => [], :old_type => []
      setup_numeric_property_definition('size', [])
      setup_property_definitions :feature => ['Dashboard', 'Applications', 'Rate calculator', 'Profile builder'],
                                 :size => [1,2,3,4,5], :status => ['Closed'], :old_type => ['Story']
      create_card!(:name => 'Blah', :feature => 'Dashboard', :size => '1', :status => 'Closed', :old_type => 'Story')
      create_card!(:name => 'Blah', :feature => 'Applications', :size => '1', :old_type => 'Story')
      create_card!(:name => 'Blah', :feature => 'Applications', :size => '2', :old_type => 'Story')
      create_card!(:name => 'Blah', :feature => 'Rate calculator', :size => '3', :old_type => 'Story')
      create_card!(:name => 'Blah', :feature => 'Rate calculator', :size => '2', :status => 'Closed', :old_type => 'Story')
      create_card!(:name => 'Blah', :feature => 'Profile builder', :size => '5', :old_type => 'Story')
      expected_chart_column_data = ['data', 100, 0, 40, 0]

      card = create_card!(:name => 'card with chart',
                          :description => '
          {{
            ratio-bar-chart:
              totals: SELECT Feature, SUM(Size) WHERE old_type = Story
              restrict-ratio-with: Status = Closed
          }}
      ')

      get :chart_data, project_id: project.identifier, type: 'ratio-bar', id: card.id, position: 1
      assert_response :success
      assert_false @response.body.blank?
      assert_equal expected_chart_column_data, JSON.parse(@response.body)['data']['columns'][0]
    end
  end

  def test_can_render_chart_data_for_version
    login_as_admin
    with_new_project do |project|
      setup_property_definitions :feature => [], :status => [], :old_type => []
      setup_numeric_property_definition('size', [])
      setup_property_definitions :feature => ['Dashboard', 'Applications', 'Rate calculator', 'Profile builder'],
                                 :size => [1,2,3,4,5], :status => ['Closed'], :old_type => ['Story']
      create_card!(:name => 'Blah', :feature => 'Dashboard', :size => '1', :status => 'Closed', :old_type => 'Story')
      create_card!(:name => 'Blah', :feature => 'Applications', :size => '1', :old_type => 'Story')
      create_card!(:name => 'Blah', :feature => 'Applications', :size => '2', :old_type => 'Story')
      create_card!(:name => 'Blah', :feature => 'Rate calculator', :size => '3', :old_type => 'Story')
      create_card!(:name => 'Blah', :feature => 'Rate calculator', :size => '2', :status => 'Closed', :old_type => 'Story')
      create_card!(:name => 'Blah', :feature => 'Profile builder', :size => '5', :old_type => 'Story')
      expected_chart_column_data = ['data', 100, 0, 40, 0]

      card = create_card!(:name => 'card with chart',
                                   :description => '
          {{
            ratio-bar-chart:
              totals: SELECT Feature, SUM(Size) WHERE old_type = Story
              restrict-ratio-with: Status = Closed
          }}
      ')
      card.update_attributes(name: 'new name', description: 'no chart')

      get :chart_data, project_id: project.identifier, type: 'ratio-bar', id: card.id, version: card.version - 1, position: 1
      assert_response :success
      assert_false @response.body.blank?
      assert_equal expected_chart_column_data, JSON.parse(@response.body)['data']['columns'][0]
    end
  end

  def test_should_fetch_chart_data
    with_renderable_caching_enabled do
      card = @project.cards.create!(:name => 'Nice Card', :description => 'some content', :card_type_name => 'Card')

      chart_type = 'dummy'
      macro_position = 1
      Caches::ChartCache.add(card, chart_type, macro_position, 'this would normally be an image')

      get :chart, :id => card.id, :project_id => @project.identifier, :type => chart_type, :position => macro_position
      assert_equal "this would normally be an image", @response.body
    end
  end

  def test_cached_charts_should_not_be_retrieved_from_cache_when_previewed
    with_renderable_caching_enabled do
      card_content = %{
          {{
            pie-chart:
              data: SELECT Status, COUNT(*)
          }}
        }
      card = @project.cards.create!(:name => 'Nice Card', :description => card_content, :card_type_name => 'Card')
      index = 1
      chart_type = 'pie'
      @request.session[:renderable_preview_content] = card_content
      Caches::ChartCache.add(card, chart_type, index, 'this would normally be an image')

      get :chart, :id => card.id, :project_id => @project.identifier, :type => chart_type, :position => index, :preview => true

      assert_not_equal "this would normally be an image", @response.body
    end
  end

  def test_should_not_raise_error_when_rendering_a_chart_has_invalid_mql
    card_content = %{
        {{
          pie-chart:
            data: SELECT invalid, COUNT(*)
        }}
      }
    card = @project.cards.create!(:name => 'Nice Card', :description => card_content, :card_type_name => 'Card')
    index = 1
    chart_type = 'pie'
    @request.session[:renderable_preview_content] = card_content
    Caches::ChartCache.add(card, chart_type, index, 'this would normally be an image')

    get :chart, :id => card.id, :project_id => @project.identifier, :type => chart_type, :position => index, :preview => true

    assert_equal "", @response.body
  end

  def test_should_not_raise_error_when_rendering_a_chart_in_invalid_position
    card_content = %{
        {{
          pie-chart:
            data: SELECT type, COUNT(*)
        }}
      }
    card = @project.cards.create!(:name => 'Nice Card', :description => card_content, :card_type_name => 'Card')
    index = 5
    chart_type = 'pie'
    @request.session[:renderable_preview_content] = card_content
    Caches::ChartCache.add(card, chart_type, index, 'this would normally be an image')

    get :chart, :id => card.id, :project_id => @project.identifier, :type => chart_type, :position => index, :preview => true

    assert_equal "", @response.body
  end

  def test_save_card_context_and_redirect
    get :list, :project_id => @project.identifier # needed to initialize the controller so that you can call url_for
    url = url_for(:controller => 'cards', :action => 'show')
    post :save_context_and_redirect, :context_numbers => '1,2,3', :redirect_url => url, :project_id => @project.identifier
    assert_redirected_to url
    assert_equal [1, 2, 3], @controller.card_context.current_list_navigation_card_numbers
  end

  def test_should_not_show_large_grid_warning_when_filter_is_invalid
    get :list, :project_id => @project.identifier, :filters => {:mql => 'type = invalid'}, :style => 'list', :tab => 'view'
    assert_select '#large_grid_warning_container', false
  end

  def test_copy_to_should_be_visible_for_readonly_team_members
    with_new_project do |project|
      card = create_card!(:name => 'card one')
      project.add_member(User.find_by_login('bob'), :readonly_member)
      login_as_bob
      get :show, :project_id => project.identifier, :number => card.number
      assert_select "a.copy-to"
    end
  end

  def test_copy_to_should_not_be_visible_for_anonymous_users
    with_new_project(:anonymous_accessible => true) do |project|
      set_anonymous_access_for(project, true)
      card = create_card!(:name => 'card one')
      logout_as_nil
      change_license_to_allow_anonymous_access
      get :show, :project_id => project.identifier, :number => card.number
      assert_response :success
      assert_select "a.copy-to", :count => 0
    end
  ensure
    reset_license
  end

  def test_copy_to_project_selection_should_show_project_selection_lightbox
    xhr :get, :copy_to_project_selection, :project_id => @project.identifier, :number => @project.cards.first.number
    assert assigns(:projects)
    assert @response.body.include?('InputingContexts')
  end

  def test_confirm_copy_should_copy_card_instead_of_confirm_when_copying_within_same_project_and_nothing_is_wrong
    with_new_project do |project|
      project.add_member(User.current)
      card = project.cards.create! :name => "first card", :card_type_name => "card"
      xhr :get, :confirm_copy, :project_id => project.identifier, :number => card.number, :selected_project_id => project.identifier
      assert @response.body.include?("was successfully copied into")
      assert_not_nil project.cards.find_by_name "Copy of first card"
    end
  end

  def test_confirm_copy_should_show_confirmation_when_copying_within_same_project_if_there_are_issues
    with_new_project do |project|
      project.add_member(User.current)
      card = project.cards.create! :name => "first card", :card_type_name => "card"
      card.attach_files(sample_attachment)
      attachment = card.attachments.first
      attachment.write_attribute(:file, "doesnt_exist")
      attachment.save!

      xhr :get, :confirm_copy, :project_id => project.identifier, :number => card.number, :selected_project_id => project.identifier
      assert @response.body.include?("will not be copied because the requisite source file is missing")
      assert_nil project.cards.find_by_name "Copy of first card"
    end
  end

  def test_confirm_copy_should_show_copy_confirmation_lightbox
    other_project = three_level_tree_project
    xhr :get, :confirm_copy, :project_id => @project.identifier, :number => @project.cards.first.number, :selected_project_id => other_project.identifier
    assert assigns(:card)
    assert @response.body.include?('lightbox')
  end

  def test_confirm_copy_should_warn_which_properties_will_not_be_copied
    login_as_admin
    target_project = with_new_project do |target_project|
      status = setup_property_definitions(:status => ['open', 'closed']).first
      status.restricted = true
      status.save!
      dependency = setup_card_relationship_property_definition 'Dependency'
      owner = setup_user_definition 'Owner'
      formula = setup_formula_property_definition('one third', '1/3')

      tree_configuration = target_project.tree_configurations.create!(:name => 'planning')
      init_empty_planning_tree tree_configuration
      type_release, type_iteration, type_story = %w{release iteration story}.collect { |card_type_name| target_project.card_types.find_by_name(card_type_name) }
      aggregate = setup_aggregate_property_definition('Iteration story count', AggregateType::COUNT, nil, tree_configuration.id, type_release.id, type_iteration)
      type_story.property_definitions = type_story.property_definitions + [dependency, owner, formula, aggregate, status]
      type_story.save!
    end

    with_new_project do |project|
      status = setup_property_definitions(:Status => ['new', 'open', 'closed']).first
      dependency = setup_card_relationship_property_definition 'Dependency'
      owner = setup_user_definition 'Owner'
      bob = User.find_by_login('bob')
      project.add_member(bob)
      formula = setup_formula_property_definition('one third', '1/3')

      tree_configuration = project.tree_configurations.create!(:name => 'planning')
      init_empty_planning_tree tree_configuration

      type_release, type_iteration, type_story = %w{release iteration story}.collect { |card_type_name| project.card_types.find_by_name(card_type_name) }

      aggregate = setup_aggregate_property_definition('Iteration story count', AggregateType::COUNT, nil, tree_configuration.id, type_release.id, type_iteration)
      type_story.property_definitions = type_story.property_definitions + [dependency, owner, formula, aggregate, status]
      type_story.save!
      dependant_card = create_card! :name => 'timmy'
      card_to_copy = create_card! :name => 'jimmy', :card_type => type_story, :status => 'new'
      card_to_copy.update_attributes :cp_dependency => dependant_card, :cp_owner => bob

      login_as_bob

      xhr :get, :confirm_copy, :project_id => project.identifier, :number => card_to_copy.number, :selected_project_id => target_project.identifier, :format => 'xml'
      assert_select 'li', :text => "Property value for Status will not be copied because the requisite value does not exist in #{target_project.name} and the property is locked."
      assert_select 'li', :text => "User property value for Owner will not be copied because the requisite team member does not exist in #{target_project.name}."
      assert_select 'li', :text => "Card property value for Dependency will not be copied."
      assert_select 'li', :text => "Tree membership and tree relationship property values for Planning iteration and Planning release will not be copied."
      assert_select 'li', :text => "Aggregate property value for Iteration story count will not be copied."
      assert_select 'li', :text => "Formula property value for one third will not be copied."
      assert_select 'li', :text => "Any properties that do not exist in project #{target_project.name} will not be copied."
    end
  end

  def test_copy_should_inform_that_card_was_copied_into_the_other_project
    login_as_admin
    target_project = create_project
    card_to_copy = nil
    with_new_project do |project|
      card_to_copy = create_card! :name => 'copy'
      xhr :post, :copy, :project_id => project.identifier, :number => card_to_copy.number, :selected_project_id => target_project.identifier
    end

    target_project.with_active_project do |target|
      copied_card = target.cards.find_by_name('copy')
      assert_rjs 'replace', 'flash', /Card ##{card_to_copy.number} was successfully copied into .*#{target_project.name}.* as Card .*\/projects\/#{target_project.identifier}\/cards\/#{copied_card.number}.*##{copied_card.number}.*/
    end
  end

  def test_edit_should_show_latest_content_with_message_that_latest_is_shown
    card = create_card!(:name => 'timmy')
    card.description = 'foo'
    card.save!
    get 'edit', :project_id => @project.identifier, :number => card.number, :coming_from_version => card.version - 1
    assert_response :success
    assert_info /This card has changed since you opened it for viewing. The latest version was opened for editing. You can continue to edit this content, .*go back.* to the previous card view or view the .*latest version.*./
  end

  def test_edit_should_not_show_message_that_latest_is_shown_if_already_coming_from_latest
    card = create_card!(:name => 'timmy')
    card.description = 'foo'
    card.save!
    get 'edit', :project_id => @project.identifier, :number => card.number, :coming_from_version => card.version
    assert_response :success
    assert_nil flash[:info]
  end

  def test_add_comment_should_add_comment_to_card
    card = create_card!(:name => 'timmy')
    xhr :post, :add_comment, :project_id => @project.identifier, :card_id => card.id, :comment => {:content => "comment on card"}
    assert_response :success
    assert_equal "comment on card", card.versions.last.comment
  end

  def test_add_comment_should_add_comment_on_xml_request
    card = create_card!(:name => 'timmy')

    post :add_comment, :project_id => @project.identifier, :number => card.number, :comment => {:content => "murmur on card", :source => 'slack'}, :format => 'xml', :api_version => 'v2'

    assert_response :success
    assert_equal 'murmur on card', card.versions.last.comment
    assert_equal 'murmur on card', card.origined_murmurs.last.murmur
    assert_equal 'slack', card.origined_murmurs.last.source

    murmur = Nokogiri::XML(@response.body) { |config| config.options = Nokogiri::XML::ParseOptions::STRICT }
    assert_equal 'murmur on card', murmur.xpath('*//body').text
    assert_equal 'member@email.com', murmur.xpath('*//author//email').text
    assert_equal card.number, murmur.xpath('*//origin//number').text.to_i
  end

  def test_add_comment_should_return_error_when_card_does_not_exist
    post :add_comment, :project_id => @project.identifier, :number => 464646, :comment => {:content => 'murmur on invalid card number'}, :format => 'xml'
    assert_response :not_found
    assert_equal 'Card not found', @response.body
  end

  def test_add_comment_should_add_create_card_murmur_in_app_monitoring_event
    MingleConfiguration.overridden_to(:metrics_api_key => 'm_key') do
      consumer = MessagingTestHelper::SampleConsumer.new
      tracker = EventsTracker.new(consumer)
      @controller.set_events_tracker(tracker)

      card = create_card!(:name => 'timmy')
      xhr :post, :add_comment, :project_id => @project.identifier, :card_id => card.id, :comment => {:content => "comment on card"}
      EventsTracker.run_once(:processor => tracker)

      assert_response :success
      event_data = JSON.parse(consumer.sent.last[1])["data"]
      assert_equal 'create_card_murmur_in_app', event_data['event']
      assert_equal @project.name, event_data['properties']['project_name']
    end
  end

  def test_show_should_not_display_toggle_hidden_properties_checkbox_when_hidden_properties_available
    view_card(@project.cards.first)
    assert_select "#toggle_hidden_properties", :count => 0
  end

  # bug 7752
  def test_should_refresh_properties_without_error_when_submitting_properties_which_dont_apply_to_changed_card_type
    with_three_level_tree_project do |project|
      type_iteration = Project.current.card_types.find_by_name('iteration')
      iteration1 = project.cards.find_by_name("iteration1")

      response = xhr :post, :refresh_properties, :project_id => project.identifier, :card => {"name" => "", "description" => ""}, "properties" => {"Type"=> type_iteration.name, "Planning iteration" => iteration1.id, "status" => "open"}

      assert_response :success
      assert response.body.include?(%{name=\\"properties[status]\\" type=\\"hidden\\" value=\\"open\\"})
    end
  end

  # bug 7852
  def test_adding_blank_comment_should_not_change_cards_last_modified_at_time
    Clock.fake_now :year => 2009, :month => 10, :day => 20, :hour => 20, :min => 00, :sec => 00
    card = @project.cards.create!(:name => 'some card', :card_type_name => 'Card')
    original_updated_at = card.updated_at
    Clock.fake_now :year => 2009, :month => 10, :day => 20, :hour => 20, :min => 10, :sec => 00
    xhr :post, :add_comment, :project_id => @project.identifier, :card_id => card.id, :comment => {:content => ""}
    assert_equal original_updated_at, card.reload.updated_at
  end

  def test_manage_favorites_and_tabs_should_not_show_personal_favorites
    team_view = @project.card_list_views.create_or_update(:view => {:name => 'Foo'}, :style => 'list')
    personal_view = @project.card_list_views.create_or_update(:view => {:name => 'Foo'}, :style => 'list', :columns => ['Type'], :user_id => User.current.id)
    get :index, :project_id => @project.identifier, :view => 'Foo'
    assert_select ".column-header-link", :count => 2
  end

  def test_no_line_breaks_in_murmurs_should_render_no_breaks
    card = create_card!(:name => 'I have a murmur with line breaks')
    murmur = @project.murmurs.create(:body => "I hate lines", :author => @member)
    CardMurmurLink.create(:project_id => @project.id, :card_id => card.id, :murmur_id => murmur.id)
    get :show, :number => card.number, :project_id => @project.identifier
    assert_response :success
    selected = css_select("div#murmur_content_#{murmur.id} .truncated-content")
    assert_not_include "<br />", selected.first.to_s
  end

  def test_add_comment_should_create_card_comment_murmur_if_murmur_this_flag_is_set
    card = @project.cards.first
    post :add_comment, :card_id => card.id, :comment => {:content => "Murmured comment"}, :project_id => @project.identifier
    card.reload
    assert_equal "Murmured comment", card.versions.last.comment
    assert_equal 1, Murmur.count(:all, :conditions => ["origin_type = ? AND origin_id = ? AND project_id = ?", card.class.name, card.id, @project.id])
  end

  def test_add_comment_referencing_card_number_instead_of_id_should_create_card_comment_murmur_if_murmur_this_flag_is_set
    card = @project.cards.first
    post :add_comment, :number => card.number, :comment => {:content => "Murmured comment"}, :project_id => @project.identifier
    card.reload
    assert_equal "Murmured comment", card.versions.last.comment
    assert_equal 1, Murmur.count(:all, :conditions => ["origin_type = ? AND origin_id = ? AND project_id = ?", card.class.name, card.id, @project.id])
  end

  def test_create_should_create_card_comment_murmur_if_murmur_this_flag_is_set
    post :create, :comment => {:content => "Murmured comment"}, :project_id => @project.identifier, :card => {:name => 'the_card', :card_type => @project.card_types.first}
    card = @project.cards.find_by_name('the_card')
    assert_equal "Murmured comment", card.versions.last.comment
    assert_equal 1, Murmur.count(:all, :conditions => ["origin_type = ? AND origin_id = ? AND project_id = ?", card.class.name, card.id, @project.id])
  end

  def test_cope_when_trying_to_murmur_comment_but_card_validation_fails
    @project.with_active_project do
      assert_nothing_raised do
        post :create, :comment => {:content => 'Murmured comment'}, :project_id => @project.identifier, :card => {:name => '', :card_type => @project.card_types.first}
      end
    end
  end

  def test_add_comment_as_murmur_should_ignore_blank_comments
    card = @project.cards.first
    post :add_comment, :card_id => card.id, :comment => {:content => " "}, :project_id => @project.identifier
    assert_equal 0, Murmur.count(:all, :conditions => ["origin_type = ? AND origin_id = ? AND project_id = ?", card.class.name, card.id, @project.id])
  end

  def test_get_card_name
    card = @project.cards.first
    xhr :get, 'card_name', :project_id => @project.identifier, :number => @project.cards.first.number
    expected_json_response = {:project => @project.identifier, :name => card.name, :number => card.number.to_s}.to_json
    assert_equal expected_json_response, @response.body
  end

  def test_get_card_name_for_tooltip_for_shortened_table_name_on_oracle
    with_new_project(:identifier => 'this_is_a_very_long_identifier') do |p|
      p.add_member(User.current)
      card = p.cards.create!(:name => 'my first card', :card_type => p.card_types.first)
      xhr :get, 'card_name', :project_id => p.identifier, :number => card.number
      expected_json_response = {:project => p.identifier, :name => card.name, :number => card.number.to_s}.to_json
      assert_equal expected_json_response, @response.body
    end
  end

  def test_return_404_if_card_doesnt_exist
    non_existent_number = @project.cards.maximum('number') + 42
    xhr :get, 'card_name', :project_id => @project.identifier, :number => non_existent_number
    assert_response :not_found
  end

  # bug #10105 [UI] Fix "card m of n" navigation tooltip on cards
  def test_navigation_tooltip_should_not_have_html_tags
    get :list, :project_id => @project.identifier, :filters => ["[Type][is][Card]"]
    card = @project.cards.first
    get :show, :project_id => @project.identifier, :number => card.number
    assert_select '#list-navigation span.text-light' do |elements|
      elements.each do |element|
        assert element.attributes['title'] !~ /<b>/
      end
    end
  end

  def test_should_contain_descriptions_if_user_chooses_to_export_descriptions
    @project.cards.each { |c| c.tag_with('') }
    post :csv_export, :project_id => @project.identifier, :export_descriptions => "yes", :include_all_columns => 'no'
    first_card = @project.cards.find_by_name('first card')
    last_card = @project.cards.find_by_name('another card')
    assert_response :success

    content = <<-EXCEL_EXPORT_CONTENT
Number,Name,Description
#{last_card.number},#{last_card.name},#{last_card.description}
#{first_card.number},#{first_card.name},#{first_card.description}
    EXCEL_EXPORT_CONTENT

    assert_match content, @response.body.to_s
  end

  def test_reorder_tags_should_change_tags_order_for_card_and_last_card_version
    with_new_project do |project|
      login_as_admin
      card = project.cards.create(:name => 'cards with tags', :card_type_name => 'Card')
      card.tag_with(['tag1', 'tag2', 'tag3', 'tag4'])
      card.save
      post :reorder_tags, :project_id => project.identifier, :taggable_id => card.id, :new_order => ['tag1', 'tag2', 'tag4','tag3']
      assert_response :success
      assert_equal ['tag1', 'tag2', 'tag4', 'tag3'], card.reload.tags.map(&:name)
      assert_equal ['tag1', 'tag2', 'tag4', 'tag3'], card.versions.second.tags.map(&:name)
      assert_equal ['tag1', 'tag2', 'tag4', 'tag3'], card.versions.last.tags.map(&:name)
    end
  end

  def test_does_not_reorder_tags_when_all_tags_positions_are_not_specified
    with_new_project do |project|
      login_as_admin
      card = project.cards.create(:name => 'cards with tags', :card_type_name => 'Card')
      card.tag_with(['tag1', 'tag2', 'tag3', 'tag4'])
      card.save

      post :reorder_tags, :project_id => project.identifier, :taggable_id => card.id
      assert_response :unprocessable_entity
      post :reorder_tags, :project_id => project.identifier, :taggable_id => card.id, :new_order => ['tag1', 'tag2']
      assert_response :unprocessable_entity
    end
  end

  def test_should_set_excel_export_preferences_on_export
    post :csv_export, :project_id => @project.identifier, :export_descriptions => "yes", :include_all_columns => 'yes'
    assert User.current.reload.display_preference.reload.read_preference(:export_all_columns)
    assert User.current.reload.display_preference.reload.read_preference(:include_description)
  end

  def test_should_unset_excel_export_preferences_on_export
    post :csv_export, :project_id => @project.identifier, :export_descriptions => "no", :include_all_columns => 'no'
    assert !User.current.reload.display_preference.read_preference(:export_all_columns)
    assert !User.current.reload.display_preference.read_preference(:include_description)
  end

  def test_should_set_download_headers_on_export
    post :csv_export, :project_id => @project.identifier, :export_descriptions => "no", :include_all_columns => 'no', :skip_download => ''
    assert_equal "attachment; filename=\"#{@project.identifier}.csv\"", @response.headers['Content-Disposition']
    assert_equal 'text/csv; charset=utf-8', @response.headers['Content-Type']

  end

  def test_should_skip_download_headers_on_export_for_tests
    post :csv_export, :project_id => @project.identifier, :export_descriptions => "no", :include_all_columns => 'no', :skip_download => 'yes'
    assert_nil @response.headers['Content-Disposition']
    assert_equal 'text/html; charset=utf-8', @response.headers['Content-Type']

  end

  def test_card_transitions_for_multiple_selected_cards
    first_card = @project.cards.find_by_number(1)
    first_card.update_attribute(:cp_release, '1')

    last_card = @project.cards.last

    release_transition = create_transition @project, 'release', :required_properties => {'release' => '1'}, :set_properties => {'status' => 'closed'}
    open_transition = create_transition @project, 'open', :set_properties => {'status' => 'open'}

    xhr :get, :card_transitions, :project_id => @project.identifier, :card_ids => [first_card.id, last_card.id]
    assert_response :success

    assert_include({'name' => 'open', 'require_comment' => false, 'html_id' => open_transition.html_id, 'id' => open_transition.id}, card_transitions_data_for(first_card))
    assert_include({'name' => 'open', 'require_comment' => false, 'html_id' => open_transition.html_id, 'id' => open_transition.id}, card_transitions_data_for(last_card))
    assert_include({'name' => 'release', 'require_comment' => false, 'html_id' => release_transition.html_id, 'id' => release_transition.id}, card_transitions_data_for(first_card))
  end

  def test_card_transitions_for_one_selected_card_knows_if_it_needs_comment
    first_card = @project.cards.find_by_number(1)
    first_card.update_attribute(:cp_release, '1')

    last_card = @project.cards.last

    release_transition = create_transition @project, 'release', :required_properties => {'release' => '1'}, :set_properties => {'status' => 'closed'}, :require_comment => true
    open_transition = create_transition @project, 'open', :set_properties => {'status' => 'open'}, :require_comment => false

    xhr :get, :card_transitions, :project_id => @project.identifier, :card_ids => [first_card.id]
    assert_response :success
    assert_include({'name' => 'open', 'require_comment' => false, 'html_id' => open_transition.html_id, 'id' => open_transition.id}, card_transitions_data_for(first_card))
    assert_include({'name' => 'release', 'require_comment' => true, 'html_id' => release_transition.html_id, 'id' => release_transition.id}, card_transitions_data_for(first_card))
    assert_nil card_transitions_data_for(last_card)
  end

  def test_card_transitions_should_not_include_transitions_that_require_user_to_enter_or_have_optional_input
    first_card = @project.cards.find_by_number(1)
    last_card = @project.cards.last

    user_input_required_transition = create_transition @project, 'release', :set_properties => {'status' => Transition::USER_INPUT_REQUIRED}
    open_transition = create_transition @project, 'open', :set_properties => {'status' => 'open'}
    user_input_optional_transition = create_transition @project, 'user_input_optional', :set_properties => {'status' => Transition::USER_INPUT_OPTIONAL}

    xhr :get, :card_transitions, :project_id => @project.identifier, :card_ids => [first_card.id, last_card.id]
    assert_response :success
    assert_include({'name' => 'open', 'require_comment' => false, 'html_id' => open_transition.html_id, 'id' => open_transition.id}, card_transitions_data_for(first_card))
    assert_include({'name' => 'open', 'require_comment' => false, 'html_id' => open_transition.html_id, 'id' => open_transition.id}, card_transitions_data_for(last_card))
    assert_not_include({'name' => 'release', 'require_comment' => false, 'html_id' => user_input_required_transition.html_id, 'id' => user_input_required_transition.id},card_transitions_data_for(first_card))
    assert_not_include({'name' => 'user_input_optional', 'require_comment' => false, 'html_id' => user_input_optional_transition.html_id, 'id' => user_input_optional_transition.id},card_transitions_data_for(first_card))
  end

  def test_card_transitions_should_html_escape_transition_name
    transition = create_transition @project, "transition's <h1>name</h1> with h1 & apostrophe", :set_properties => {'status' => 'open'}
    first_card = @project.cards.first
    xhr :get, :card_transitions, :project_id => @project.identifier, :card_ids => [first_card.id]
    assert_include({'name' => "transition&#39;s &lt;h1&gt;name&lt;/h1&gt; with h1 &amp; apostrophe", 'require_comment' => false, 'html_id' => transition.html_id, 'id' => transition.id}, card_transitions_data_for(first_card))
  end

  def test_should_display_add_card_button_in_tray_for_grid_view
    get :list, :project_id => @project.identifier, :style => 'grid'
    assert_select '#ft #magic_card #add_card_with_defaults', :text => "Add Card", :count => 1
  end

  def test_should_not_display_add_card_button_in_tray_for_list_and_hierarchy_view
    get :list, :project_id => @project.identifier, :style => 'list'
    assert_response :success
    assert_select '#ft #magic_card', :text => "Add Card", :count => 1

    with_filtering_tree_project do |project|
      view = CardListView.construct_from_params(project, {:tree_name => 'filtering tree', :style => 'hierarchy'})
      get 'list', :project_id => project.identifier, :tree_name => 'filtering tree'
      assert_response :success
      assert_select '#ft #magic_card', :text => "Add Card", :count => 1
    end
  end

  def test_readonly_member_should_not_see_add_card_button
     @bob = User.find_by_login('bob')
     @project.add_member(@bob, :readonly_member)
     login_as_bob

     get :list, :project_id => @project.identifier, :style => 'grid'
     assert_response :success
     assert_select '#ft #magic_card', :count => 0
  end

  def test_grid_view_with_results_over_limit_should_not_display_results
    with_max_grid_view_size_of(1) do
      get :list, :project_id => @project.identifier, :style => 'grid'
      assert_select 'div.too_many_cards_on_grid', :count => 1
      assert_select 'div.card-icon', :count => 0
      assert_select 'div.too_many_cards_on_grid', :text => /#{@project.cards.count} cards/
      assert_select 'div.too_many_cards_on_grid', :text => /#{CardViewLimits::MAX_GRID_VIEW_SIZE}/
    end
  end

  def test_grid_with_too_many_results_includes_link_to_switch_to_list
    with_max_grid_view_size_of(1) do
      card_filter = "[Type][is][Card]"
      get :list, :project_id => @project.identifier, :style => 'grid', :filters => [card_filter]
      assert_select "div.too_many_cards_on_grid a" do
        assert_select "[href=?]", /.*#{CGI::escape(card_filter)}.*/
        assert_select "[href=?]", /.*style=list.*/i
      end
    end
  end

  def test_list_with_dirty_tab_will_show_save_button
    open_cards = CardListView.find_or_construct(@project, {:filters => ["[status][is][Open]"]})
    open_cards.name = 'open cards'
    open_cards.save!
    open_cards.favorite.tab_view = true
    open_cards.save!

    get :list, open_cards.to_params.merge(:project_id => @project.identifier, :group_by => { :lane => 'Status' })
    assert_select 'a.update-tab'
  end

  def test_list_with_clean_tab_will_not_show_save_button
    open_cards = CardListView.find_or_construct(@project, {:filters => ["[status][is][Open]"]})
    open_cards.name = 'open cards'
    open_cards.save!
    open_cards.favorite.tab_view = true
    open_cards.save!
    get :list, open_cards.to_params.merge(:project_id => @project.identifier)
    assert_select 'a.update-tab', :count => 0

  end

  def test_list_with_dirty_all_tab_will_not_have_save_button
    get :list, :project_id => @project.identifier, :group_by => { :lane => 'Status' }, :tab => 'All', :style => 'grid'
    assert_select 'a.reset-all-link'
    assert_select 'a.update-tab', :count => 0
  end


  def test_double_print_creates_a_pdf_document
    post :double_print, :project_id => @project.identifier
    assert_response :success
  end

  def test_lazy_load_property_action
    get :show_properties_container, :project_id => @project.identifier, :number => @project.cards.first.number
    assert_response :success
    assert_rjs :replace_html, 'toggle_hidden_properties_bar'
    assert_rjs :replace_html, "show-properties-container"
  end

  # for the case card got deleted when showing the card properties panel
  def test_should_redirect_to_list_page_with_error_if_the_card_does_not_exist
    get :show_properties_container, :project_id => @project.identifier, :number => 1234243
    assert_redirected_to :action => "list"
    assert_equal 'Card 1234243 does not exist.', flash[:error]
  end

  def test_should_show_first_avatars_on_card
    with_new_project do |project|
      project.add_member @member
      dev = setup_user_definition('dev')
      ba = setup_user_definition('ba')
      qa = setup_user_definition('qa')
      zz = setup_user_definition('zz')
      card_type = project.find_card_type('Card')
      card_type.property_definitions = [qa, ba, dev, zz]

      card = create_card!(:name => 'sample')
      assert card.update_attributes(:cp_dev => @member, :cp_ba => @member, :cp_qa => @member, :cp_zz => @member)

      get :list, :style => :grid, :project_id => project.identifier
      assert_response :ok
      assert_select "##{card.html_id} .avatars[data-slot-ids='[&quot;qa&quot;,&quot;ba&quot;,&quot;dev&quot;]']"
      assert_select "##{card.html_id} .avatars img", :count => 3
      assert_select "##{card.html_id} .avatars img[title='dev: #{@member.name}']"
      assert_select "##{card.html_id} .avatars img[title='qa: #{@member.name}']"
      assert_select "##{card.html_id} .avatars img[title='ba: #{@member.name}']"
    end
  end

  def test_should_not_show_error_when_card_list_view_filter_has_invalid_plv
    with_first_project do |project|
      get :list, :style => :grid, :filters => ["[Iteration][is][(current iteration)]"], :group_by => 'status', :project_id => project.identifier
      assert_response :ok
    end
  end

  def test_should_show_top_5_activated_users_on_footbar
    with_first_project do |project|
      users = (1..6).map do |index|
        u = create_user!(:name => '_user' << index.to_s)
        @project.add_member(u)
        u
      end

      get :list, :style => 'grid', :group_by => 'status', :project_id => project.identifier
      assert_response :ok
      assert_select "#ft .team-list .top-5 .avatar", :count => 5
      assert_select "#ft .team-list .avatar", :count => 5
    end
  end

  def test_update_without_content_should_not_escape_the_content_already_in_database
    card =create_card!(:name => "attaching cards")
    card.attach_files(sample_attachment('1.png'))
    card.update_attributes(:description => "!1.png!")
    card.save!
    assert_equal "!1.png!", card.reload.content

    post :update, :properties => { 'Status' => 'new' }, :number => card.number, :project_id => @project.identifier
    assert_response 302
    assert_equal 'new', card.reload.cp_status
    assert_equal '!1.png!', card.description
    assert_equal '!1.png!', card.versions.last.description
  end

  def test_bang_bang_is_escape_when_update
    card =create_card!(:name => "attaching cards")
    card.attach_files(sample_attachment('1.png'))
    card.save!
    post :update, :card => { :description => '!1.png!' }, :number => card.number, :project_id => @project.identifier
    assert_response 302
    assert_equal '&#33;1.png&#33;', card.reload.description
    assert_equal '&#33;1.png&#33;', card.versions.last.description
  end

  def test_response_not_found_when_updating_deleted_card_with_json_format
    post :update, :card => { :description => '!1.png!' }, :number => '22343242344', :project_id => @project.identifier, :format => "json"
    assert_response 404
  end

  def test_edit_card_should_merge_card_name_and_description_from_request_for_continue_editing_in_full_view
    card = @project.cards.first
    post :edit, :number => card.number, :card => {
      :name => "new name",
      :description => "new description" }, :tagged_with => 'tag1,tag2', :project_id => @project.identifier
    assert_response :ok
    assert_equal 'new name', assigns['card'].name
    assert_equal 'new description', assigns['card'].description
    assert_equal 'tag1 tag2', assigns['card'].tag_list

    # have to manually rollback & open db transaction for Oracle, because
    # there is no rollback savepoint implemented in Oracle adapter.
    # And we want to confirm the post :edit action won't save anything into database
    Project.connection.rollback_db_transaction
    Project.connection.begin_db_transaction

    card = assigns['card'].reload
    assert_equal 'first card', card.name
    assert_equal 'this is the first card', card.description
    assert_equal 'first_tag', card.tag_list
  end

  def test_can_get_list_of_transitions_for_single_card_with_json_format
    transition = create_transition(@project, 'open', :set_properties => {:status => Transition::USER_INPUT_REQUIRED})
    card = @project.cards.first
    get :transitions, :number => card.number, :project_id => @project.identifier, :format => 'json'
    assert_response :ok
    assert_equal([{"name" => transition.name,
                    "id"=> transition.id,
                    "require_popup" => true,
                    "card_id" => card.id,
                    "card_number" => card.number,
                    "project_id" => @project.identifier}], JSON.parse(@response.body))
  end

  def test_should_include_transition_ids_when_user_is_api_user_from_slack
    transition = create_transition(@project, 'open', :set_properties => {:status => Transition::USER_INPUT_REQUIRED})
    card = @project.cards.first

    @controller.request = @request
    @controller.response = @response

    logout_as_nil
    MingleConfiguration.overridden_to(:authentication_keys => 'key1',
                                      :slack_encryption_key => 'test_encryption_key') do
      @request.env['HTTP_MINGLE_API_KEY'] = 'key1'
      get :show, {:api_version => 'v2', 'project_id' => @project.identifier,
                  :format => 'xml', :authenticity_token => 'token',
                  :number => "#{card.number}", :include_transition_ids => 'true' }

      assert @response.body.include?("<transition_ids>#{transition.id}</transition_ids>")
    end
  end

  def test_should_include_transition_ids_of_transition_restricted_to_a_group_when_user_is_api_user_from_slack
    member = User.find_by_name('member@email.com')
    bob = User.find_by_name('bob@email.com')

    group = create_group('group1', [member, bob])
    transition = create_transition(@project, 'open', :set_properties => {:status => Transition::USER_INPUT_REQUIRED}, :user_prerequisites => [member.id, bob.id])
    card = @project.cards.first

    @controller.request = @request
    @controller.response = @response

    logout_as_nil
    MingleConfiguration.overridden_to(:authentication_keys => 'key1',
                                      :slack_encryption_key => 'test_encryption_key') do
      @request.env['HTTP_MINGLE_API_KEY'] = 'key1'
      get :show, {:api_version => 'v2', 'project_id' => @project.identifier,
                  :format => 'xml', :authenticity_token => 'token',
                  :number => "#{card.number}", :include_transition_ids => 'true' }

      assert @response.body.include?("<transition_ids>#{transition.id}</transition_ids>")
    end
  end


  def test_list_should_render_wip_limit_for_non_admin_user
    login_as_member
    highLaneName = 'high'
    view = CardListView.construct_from_params(@project, :group_by => 'priority', :style => 'grid', :lanes => highLaneName)

    get 'list', view.to_params.merge(:project_id => @project.identifier)

    assert_response :success
    assert_select ".lane_header ##{highLaneName.to_hex_string}-wip-limit", :text => 'WIP : (not set)'
    assert_select'.lane_header .editable-wip', false
    assert_select '.lane_header .wip-popover .readonly-content'
    assert_select '.lane_header .wip-popover .editable-content', false
  end

  def test_list_should_render_wip_limit_for_admin_user
    login_as_proj_admin
    view = CardListView.construct_from_params(@project, :group_by => 'Status', :style => 'grid', :lanes => 'new')

    get 'list', view.to_params.merge(:project_id => @project.identifier)

    assert_response :success
    assert_select '.lane_header .editable-wip', :text => 'WIP : (not set)'
    assert_select '.lane_header .editable_lane'
    assert_select '.lane_header .wip-popover'
    assert_select '.lane_header .wip-popover .content input[type=text]'
  end

  def test_list_should_not_render_wip_limits_for_rows
    login_as_proj_admin
    view = CardListView.construct_from_params(@project, { :group_by => {:lane => 'priority' ,:row => 'status'}, :style => 'grid', :lanes => 'high' } )

    get 'list', view.to_params.merge(:project_id => @project.identifier)

    assert_response :success
    assert_select '.lane_header .editable-wip'
    assert_select '.row_header .editable-wip', false
    assert_select '.wip-popover'
    assert_select '.lane_header .editable_lane'
  end

  def test_list_should_render_reset_and_save_option_when_wip_are_configured
    view = @project.card_list_views.create_or_update(:view => {:name => 'some tab'}, :tab => 'some tab', :style => 'grid', :group_by => {:lane => 'status'}, :aggregate_type => {:column => 'SUM'}, :aggregate_property => {:column => 'release'})
    view.tab_view = true
    view.save!

    get 'list', view.to_params.merge(:project_id => @project.identifier, :wip_limits => {'open' => {:type => 'count', :limit => '30'}})

    assert_select '#tab_some_tab_save', :count => 1
    assert_select '#reset_to_tab_default', :count => 1
  end

  def test_create_view_should_persist_wip_limits_on_save
    view = @project.card_list_views.create_or_update(:view => {:name => 'some tab'}, :tab => 'some tab', :style => 'grid', :group_by => {:lane => 'status'}, :aggregate_type => {:column => 'SUM'}, :aggregate_property => {:column => 'release'})
    view.tab_view = true
    view.save!

    post :create_view, view.to_params.merge(:project_id => @project.identifier, :wip_limits => {'open' => {:type => 'count', :limit => '30'}}, :view => {:name => 'some tab'})

    wip_limits = {'open' => {'limit' => '30', 'type' => 'count'}}
    assert_equal wip_limits, view.reload.params[:wip_limits]
  end

  def test_list_should_render_configured_wip
    fixedLaneName = 'fixed'
    newLaneName = 'new'
    openLaneName = 'open'
    closedLaneName = 'closed'
    inProgressLaneName = 'in progress'
    lanes = [fixedLaneName, newLaneName, openLaneName, closedLaneName, inProgressLaneName].join(',')
    view = @project.card_list_views.create_or_update(:view => {:name => 'some tab'}, :tab => 'some tab', :style => 'grid', :group_by => {:lane => 'status'}, :lanes => lanes)
    view.tab_view = true
    view.save!
    login_as_proj_admin

    get 'list', view.to_params.merge(:project_id => @project.identifier, :wip_limits => {'open' => {:type => 'count', :limit => '2'}, 'in progress' => {:type => 'count', :limit => '3'}})

    assert_select ".lane_header ##{newLaneName.to_hex_string}-wip-limit", :text => 'WIP : (not set)'
    assert_select ".lane_header ##{openLaneName.to_hex_string}-wip-limit", :text => 'WIP : 2'
    assert_select ".lane_header ##{inProgressLaneName.to_hex_string}-wip-limit", :text => 'WIP : 3'
    assert_select '.wip-limits-section p strong', :text => 'Set Work in Progress limit'
    assert_select '.wip-popover .editable-content .notes', :text => 'To save the set WIP limits, please save the current grid view.'
  end

  private

  def view_card(card)
    get 'show', :project_id => @project.identifier, :number => card.number
  end

  def assert_view_style_is(style)
    assert_to_s_equal style, assigns['view'].style
  end

  def update_property_status_to_hidden_property
    status = @project.find_property_definition('status')
    status.update_attribute(:hidden, true)
  end

  def card_transitions_data_for(card)
    json_data = @response.body.match(/(\{.*\})/).to_s
    card_transitions = ActiveSupport::JSON::decode(json_data)
    card_transitions[card.id.to_s]
  end

end
