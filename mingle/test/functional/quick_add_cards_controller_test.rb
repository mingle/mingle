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
require File.expand_path(File.dirname(__FILE__) + '/../unit/renderable_test_helper')

class QuickAddCardsControllerTest < ActionController::TestCase
  include TreeFixtures::PlanningTree, ::RenderableTestHelper::Functional

  def setup
    @controller = create_controller QuickAddCardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    login_as_member
    @project = first_project
    @project.activate
  end

  def test_add_card_popup
    get :add_card_popup, :project_id => @project.identifier, :from_url => {}

    assert_response :success
    assert_include 'add_card_popup', @response.body
  end

  def test_error_message_when_name_too_long
    card_type = @project.card_types.first
    xhr :post, :create_by_quick_add, :card => {:name => 'x'*256, :card_type_name => card_type.name }, :project_id => @project.identifier, :from_url => {}
    assert_match /Name is too long/, @response.body
  end

  def test_does_not_corrupt_macros_when_quick_adding_to_tree
    with_new_project do |project|
      project.add_member(User.current)

      tree_config = project.tree_configurations.create!(:name => "simple")
      type_release, type_iteration, type_story = init_planning_tree_types
      tree_config.update_card_types({
        type_release => {:position => 0, :relationship_name => "release"},
        type_iteration => {:position => 1, :relationship_name => "iteration"},
        type_story => {:position => 2}
      })

      xhr :post, :create_by_quick_add,
                 :from_url => {},
                 :project_id => project.identifier,
                 :tree_config_id => tree_config.id,
                 :card => {:name => "new card with macro", :card_type_name => type_story.name, :description => create_raw_macro_markup("{{ project }}") }

      assert_response :success
      assert_equal 1, project.cards.reload.count
      assert_equal "{{ project }}", project.cards.first.description.strip
    end
  end

  def test_show_error_for_invalid_numeric_property_value
    card_type = @project.card_types.first
    xhr :post, :create_by_quick_add,
              :card => {:name => 'card x', :card_type_name => card_type.name },
              :properties => { 'Release' => 'xxx' },
              :project_id => @project.identifier, :from_url => {}
    assert_match /is an invalid numeric value/, @response.body
  end

  def test_should_give_invalid_tree_location_error_when_card_selection_is_invalid_on_tree
    login_as_admin
    ##################################################################################
    #                                     Planning tree
    #                             -------------|---------
    #                            |                      |
    #                    ----- release1----           release2
    #                   |                 |
    #            ---iteration1----    iteration2
    #           |                |
    #       story1            story2
    #
    ##################################################################################
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.first
      type_release = project.card_types.find_by_name('release')
      release_prop = project.reload.find_property_definition_or_nil('Planning release')
      iteration_prop = project.find_property_definition_or_nil('Planning iteration')
      iteration_2 = project.cards.find_by_name('iteration2')
      release_1 = project.cards.find_by_name('release1')
      release_2 = tree_configuration.add_child(create_card!(:name => 'release2', :card_type => type_release), :to => :root)
      assert_no_difference "project.cards.count" do
        xhr :post, :create_by_quick_add,
                   :project_id => project.identifier,
                   :card => { :name => 'story 3', :card_type_name => 'story' },
                   :properties => { 'Planning iteration' => iteration_2.id, 'Planning release' => release_2.id }
      end
      assert_match(/Suggested location on tree/, @response.body)
      assert_match(/Cannot have .* at the same time/, @response.body)
    end
  end

  def test_should_quick_add_with_tree_relationship_properties
    with_three_level_tree_project do |project|
      tree = project.tree_configurations.first

      iteration_type = project.card_types.find_by_name 'iteration'
      iteration_two = project.cards.create!(:name => 'iteration 2',:card_type => iteration_type)

      xhr :post, :create_by_quick_add,
                 :from_url => {},
                 :project_id => project.identifier,
                 :card => { :name => 'new card', :card_type_name => 'story' },
                 :properties => { 'planning iteration' => iteration_two.id }

      new_card = project.cards.find_by_name("new card")
      assert_equal iteration_two, new_card.cp_planning_iteration
    end

  end

  def test_create_by_quick_add_should_create_card
    card_type = @project.card_types.first
    xhr :post, :create_by_quick_add, :from_url => {}, :card => {:name => 'new card', :card_type_name => card_type.name }, :project_id => @project.identifier
    assert @project.cards.find_by_name('new card')
  end

  def test_verify_no_cards_controller_actions_are_appended_with_quick_add_cards_controller_in_it
    # By no means this is a thorough test - but it is something
    xhr :post, :create_by_quick_add, :from_url => {}, :card => {:name => 'new card', :card_type_name => @project.card_types.first.name }, :project_id => @project.identifier
    quick_add_links = @response.body.scan(%r|(/projects/#{@project.identifier}/[^'" ]+)|).flatten.uniq.find_all { |url| url.include?('quick_add_cards') }
    actuals         = quick_add_links.map { |url| url.scan(%r|projects/.+/quick_add_cards/([\w]+)|) }.flatten.uniq
    quick_add_action_methods = QuickAddCardsController.public_instance_methods(false)
    unexpected_actions_on_quick_add = actuals - quick_add_action_methods
    assert unexpected_actions_on_quick_add.empty?, "Some controller actions (#{unexpected_actions_on_quick_add.inspect}) aren't defined on QuickAddCardsController are generated as links."
  end

  def test_should_show_flash_message_that_card_added_but_not_in_current_view_if_card_is_filtered
    create_card!(:name => 'card3', :status => 'new')

    xhr :post, :create_by_quick_add, :card => {:name => 'new card', :card_type_name => 'Card' }, :project_id => @project.identifier, :from_url => {:filters => ["[status][is][new]"]}
    assert_match /was successfully created, but is not shown because it does not match the current filter/, json_unescape(@response.body)
  end

  def test_should_highlight_card_when_card_added_is_not_filtered
    xhr :post, :create_by_quick_add, :card => {:name => 'new card', :card_type_name => 'Card' }, :properties => { :status => 'new' }, :project_id => @project.identifier, :from_url => {:controller => 'cards', :action => 'list', :filters => ["[status][is][new]"]}
    assert_match /was successfully created\./, json_unescape(@response.body)
    assert_match /Effect.SafeHighlight/, json_unescape(@response.body)
  end

  def test_quick_add_popup_should_know_tree_if_tree_selected
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.first
      xhr :post, :add_card_popup, :project_id => project.identifier, :use_filters => true, :from_url => {:tree_name => tree_configuration.name}
      assert_include 'input id=\"tree_config_id\" name=\"tree_config_id\" type=\"hidden\" value=\"%s\"' % tree_configuration.id, json_unescape(@response.body)
    end
  end

  def test_inplace_add_should_retain_properties_from_row_and_column
    type_bug = @project.card_types.create!(:name => 'bug')
    @project.find_property_definition('status').card_types = [type_bug]

    xhr :post, :add_card_popup, :card_type_name => type_bug.name, :project_id => @project.identifier, :from_url => {}, :card_properties => {"Status" => "Open"}
    assert_match /Open/, @response.body
  end

  def test_should_add_card_to_root_of_tree_if_tree_selected_but_no_tree_relationship_filters_set
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.first
      assert_difference("project.cards.count", 1) do
        xhr :post, :create_by_quick_add, :card => {:name => 'card in tree', :card_type_name => 'release'}, :tree_config_id => tree_configuration.id, :project_id => project.identifier, :from_url => {}
        assert_response :success
        assert tree_configuration.reload.include_card?(project.cards.find_by_name('card in tree'))
      end
    end
  end

  def test_should_not_add_card_to_tree_if_card_type_is_not_in_tree
    with_three_level_tree_project do |project|
      not_in_tree_type = project.card_types.create!(:name => "not_in_tree")
      tree_configuration = project.tree_configurations.first
      assert_difference("project.cards.count", 1) do
        xhr :post, :create_by_quick_add, :card => {:name => 'card should not be in tree', :card_type_name => not_in_tree_type.name}, :tree_config_id => tree_configuration.id , :project_id => project.identifier, :from_url => {}
        assert_response :success
        assert !tree_configuration.include_card?(project.cards.find_by_name('card should not be in tree'))
      end
    end
  end

  def test_should_set_override_default_values_with_equality_filter_values
    type_bug = @project.card_types.create!(:name => 'bug')
    @project.find_property_definition('status').card_types = [type_bug]
    defaults = type_bug.card_defaults
    defaults.update_properties(:status => 'open')

    xhr :post, :add_card_popup, :from_url => {:filters => ["[Type][is][bug]", "[Status][is][closed]"]}, :use_filters => true, :project_id => @project.identifier

    assert_match "value=\\\"closed\\\"", @response.body
  end

  def test_popup_should_show_defaults_and_filter_values
    type_bug = @project.card_types.create!(:name => 'bug')
    @project.find_property_definition('status').card_types = [type_bug]
    @project.find_property_definition('Stage').card_types = [type_bug]
    defaults = type_bug.card_defaults
    defaults.update_properties(:status => 'open')

    xhr :post, :add_card_popup, :from_url => {:filters => ["[Type][is][bug]", "[Stage][is][25]"]}, :use_filters => true, :project_id => @project.identifier

    assert_match /<input[^>]+properties\[Stage\][^>]+>/x, json_unescape(@response.body)
    assert_match /<input[^>]+properties\[Status\][^>]+>/x, json_unescape(@response.body)
  end

  def test_popup_should_show_tags_if_used_in_filters
    type_bug = @project.card_types.create!(:name => 'bug')
    xhr :post, :add_card_popup,
        :from_url => {:filters => ["[Type][is][bug]"],
                      :tagged_with => 'pumpkin, skeleton'},
        :use_filters => true, :project_id => @project.identifier

    assert_equal ['pumpkin', 'skeleton'], assigns['card'].tags.map(&:name)
  end

  def test_should_not_have_tag_if_tag_was_removed
    type_bug = @project.card_types.create!(:name => 'bug')
    xhr :post, :create_by_quick_add, :tagged_with => 'pumpkin', :card => {:name => 'new card', :card_type_name => 'bug' }, :from_url => {:tagged_with => 'pumpkin, skeleton'}, :project_id => @project.identifier
    card = @project.cards.find_by_name('new card')
    assert_equal 'pumpkin', card.tag_summary
  end

  def test_should_add_tags_when_add_with_details
    type_bug = @project.card_types.create!(:name => 'bug')
    post :quick_add_with_details, :card => {:name => 'new card', :card_type_name => 'bug', :tagged_with => 'pumpkin' }, :from_url => {:tagged_with => 'pumpkin, skeleton'}, :project_id => @project.identifier
    assert_redirected_to :controller => "cards", :action => "new", :card => {:name => 'new card', :card_type_name => 'bug', :tagged_with => 'pumpkin'}
  end

  def test_card_type_param_should_override_all_in_magic_card
    # card_type_name is used for remembering the last selected card_type from the dropdown menu
    @project.card_types.create!(:name => 'Bug')
    @project.card_types.create!(:name => 'Story')
    @project.card_types.create!(:name => 'Defect')
    xhr :post, :add_card_popup, :card => {:card_type_name => "Defect"}, :from_url => {:filters => ["[Type][is][Story]"]}, :project_id => @project.identifier

    assert_equal "Defect", session[:quick_add_card_type]
  end

  def test_should_update_partials_when_change_card_type
    @project.card_types.create!(:name => 'Bug')
    @project.card_types.create!(:name => 'Story')
    defect = @project.card_types.create!(:name => 'Defect')
    defect.update_attribute('color', '#ffffff')

    xhr :post, :add_card_popup, :card => {:card_type_name => "Defect"}, :card_properties => {:Type => 'story'}, :project_id => @project.identifier, :use_filters => true, :from_url => { :color_by => 'Type' }
    assert_rjs 'replace', "add-card-properties"
    assert_rjs 'replace', 'card-type-editor'
    assert_match /trigger\('property_value_changed'\)/, @response.body
    assert_match /trigger\('update_card_defaults', /, @response.body
  end

  def test_trigger_save_error_event_when_quick_add_card_failed
    card_type = @project.card_types.first
    xhr :post, :create_by_quick_add, :card => {:name => 'x'*256, :card_type_name => card_type.name }, :project_id => @project.identifier, :from_url => {}
    assert_match /trigger\('save:error'/, @response.body
  end

  def test_card_type_param_should_override_card_properties_param
    # card_type_name is used for remembering the last selected card_type from the dropdown menu
    @project.card_types.create!(:name => 'Bug')
    @project.card_types.create!(:name => 'Story')
    @project.card_types.create!(:name => 'Defect')
    xhr :post, :add_card_popup, :card => {:card_type_name => "Defect"}, :card_properties => {:Type => 'story'}, :project_id => @project.identifier, :use_filters => true, :from_url => {}
    assert_match "Defect", session[:quick_add_card_type]
  end

  def test_popup_should_set_card_type_from_filter_if_set
    @project.card_types.create!(:name => 'Story')
    @project.card_types.create!(:name => 'Bug')

    xhr :post, :add_card_popup,
        :from_url => {:filters => ["[Type][is][Story]"]},
        :use_filters => true, :project_id => @project.identifier
    assert_equal "Story", session[:quick_add_card_type]
  end

  def test_card_type_should_be_set_from_session_when_no_filter_or_param_values
    # card_type_name is used for remembering the last selected card_type from the dropdown menu
    @project.card_types.create!(:name => 'Bug')
    session[:quick_add_card_type] = "Card"

    xhr :post, :add_card_popup, :from_url => {:filters => []}, :project_id => @project.identifier

    assert_equal "Card", session[:quick_add_card_type]
  end

  def test_quick_add_with_details_should_translate_db_identifier_params_to_url_identifier_params
    with_three_level_tree_project do |project|
      card_type = project.card_types.find_by_name("story")
      related_card = project.cards.find_by_name("story1")

      post :quick_add_with_details, :card => {:name => 'card1', :card_type_name => card_type.name }, :properties => {"related card" => related_card.id }, :project_id => project.identifier
      assert_redirected_to :controller => "cards", :action => "new", :properties => {"related card" => related_card.number }
    end
  end

  def test_quick_add_with_details_should_redirect_with_card_type_and_name_params
    card_type = @project.card_types.first
    post :quick_add_with_details, :card => {:name => 'card1', :card_type_name => card_type.name}, :project_id => @project.identifier
    assert_redirected_to :controller => "cards", :action => "new", :card => { :name => 'card1', :card_type_name => card_type.name }
  end

  def test_create_wysiwyg_card_by_quick_add_should_set_default_card_checklists
    with_new_project do |project|
      login_as_admin
      card_type = project.card_types.create!(:name => 'Story')
      default_checklists = ["first", "second"]

      card_type.card_defaults.set_checklist_items(default_checklists)
      card_type.card_defaults.save
      post :create_by_quick_add, :card => {:name => 'card1', :card_type_name => card_type.name}, :project_id => project.identifier, :from_url => {}
      assert_response :success
      assert_equal default_checklists, project.cards.find_by_name("card1").incomplete_checklist_items.map(&:text)
    end
  end

  def test_add_card_pop_up_should_default_to_a_card_type_included_in_filter
    @project.card_types.create!(:name => 'Story')
    xhr :get, :add_card_popup, :project_id => @project.identifier, :from_url => {:filters => "[Type][is][Story]"}, :use_filters => true

    assert_equal 'Story', session[:quick_add_card_type]
  end

  def test_add_card_pop_up_should_not_default_to_a_filtered_card_type
    @project.card_types.create!(:name => 'Story')
    xhr :get, :add_card_popup, :project_id => @project.identifier, :from_url => {:filters => "[Type][is][Story]"},:use_filters => true

    card_type_selected_is_card = /selected=\\\\\\\"selected\\\\\\"\\\\u003ECard/

    assert_no_match card_type_selected_is_card, @response.body
  end

  def test_should_be_able_to_overwrite_card_properties_inherited_from_filters_when_shows_add_card_popup
    # card_properties is set when dragging and dropping the magic card
    type_bug = @project.card_types.create!(:name => 'bug')
    @project.find_property_definition('status').card_types = [type_bug]
    xhr :get, :add_card_popup, :card_properties => {'status' => 'new'}, :from_url => {:filters => ["[Type][is][bug]", "[Status][is][closed]"]}, :use_filters => true, :project_id => @project.identifier

    assert_match "value=\\\"new\\\"", @response.body
  end

  def test_should_not_use_card_defaults_from_card_type_in_filters_if_card_properties_contains_card_type
    # card_properties is set when dragging and dropping the magic card
    type_bug = @project.card_types.create!(:name => 'bug')
    type_task = @project.card_types.create!(:name => 'task')
    @project.find_property_definition('status').card_types = [type_bug]
    @project.find_property_definition('priority').card_types = [type_task]
    type_bug.card_defaults.update_properties(:status => 'open')
    type_task.card_defaults.update_properties(:priority => 'low')
    xhr :get, :add_card_popup, :card_properties => {:Type => 'task'}, :from_url => {:filters => ["[Type][is][bug]"]}, :use_filters => true, :project_id => @project.identifier
    assert_no_match(/value=\\\"open\\\"/, @response.body)
    assert_match "value=\\\"low\\\"", @response.body
  end

  def test_create_by_quick_add_should_only_close_popup_when_no_display_to_update
    xhr :post, :create_by_quick_add, :card => {:name => 'new card', :card_type_name => "Card" }, :project_id => @project.identifier, :from_url => {}
    assert_match /InputingContexts.pop/i, @response.body
    assert_no_match /redirect_to/, @response.body
    assert_match /was successfully created/, json_unescape(@response.body)
  end

  def test_create_by_quick_add_should_update_results_for_card_list_view
    xhr :post, :create_by_quick_add, :card => {:name => 'new card', :card_type_name => "Card" }, :project_id => @project.identifier, :from_url => {:controller => "cards", :action => "list"}
    assert_match /InputingContexts.pop/i, @response.body
    assert_no_match /redirect_to/, @response.body
    assert_match /was successfully created/, json_unescape(@response.body)
    assert_match /\$\(\"card_results\"\)\.update\(/, json_unescape(@response.body)
  end

  # bug #12837
  def test_create_card_by_quick_add_should_not_refresh_add_card_with_defaults
    xhr :post, :create_by_quick_add, :card => {:name => 'new card', :card_type_name => "Card" }, :project_id => @project.identifier, :from_url => {:controller => "cards", :action => "list"}
    assert_no_match /add_card_with_defaults/, @response.body
  end

  def test_create_by_quick_add_should_redirect_to_given_url
    xhr :post, :create_by_quick_add, :card => {:name => 'new card', :card_type_name => "Card" }, :project_id => @project.identifier, :from_url => {:controller => 'cards', :action => 'show'}
    assert_match /InputingContexts.pop/i, @response.body
    assert_rjs :redirect_to, {:controller => 'cards', :action => 'show'}
    assert_match /was successfully created/, flash[:notice]

    xhr :post, :create_by_quick_add, :card => {:name => 'new card', :card_type_name => "Card" }, :project_id => @project.identifier, :from_url => {:controller => 'history', :action => 'index'}
    assert_match /InputingContexts.pop/i, @response.body
    assert_rjs :redirect_to, {:controller => 'history', :action => 'index'}
    assert_match /was successfully created/, flash[:notice]

    xhr :post, :create_by_quick_add, :card => {:name => 'new card', :card_type_name => "Card" }, :project_id => @project.identifier, :from_url => {:controller => 'projects', :action => 'overview'}
    assert_match /InputingContexts.pop/i, @response.body
    assert_rjs :redirect_to, {:controller => 'projects', :action => 'overview'}
    assert_match /was successfully created/, flash[:notice]

    xhr :post, :create_by_quick_add, :card => {:name => 'new card', :card_type_name => "Card" }, :project_id => @project.identifier, :from_url => {:controller => 'pages', :action => 'show'}
    assert_match /InputingContexts.pop/i, @response.body
    assert_rjs :redirect_to, {:controller => 'pages', :action => 'show'}
    assert_match /was successfully created/, flash[:notice]
  end

  def test_the_current_tab_should_be_from_url_tab
    xhr :post, :create_by_quick_add, :card => {:name => 'new card', :card_type_name => "Card" }, :project_id => @project.identifier, :from_url => {:controller => 'cards', :action => 'show', :tab => 'hello'}
    assert_equal({:name => 'hello', :type => CardListView.name}, @controller.current_tab)

    get :add_card_popup, :project_id => @project.identifier, :from_url => {:tab => 'hello again'}
    assert_equal({:name => 'hello again', :type => CardListView.name}, @controller.current_tab)
  end

  def test_should_be_default_tab_if_no_tab_in_from_url
    xhr :post, :create_by_quick_add, :card => {:name => 'new card', :card_type_name => "Card" }, :project_id => @project.identifier, :from_url => {:controller => 'cards', :action => 'show'}
    assert_equal DisplayTabs::AllTab::NAME, @controller.current_tab[:name]
  end

  def test_by_default_quick_add_popup_does_not_have_an_editor_style_selector
    xhr :get, :add_card_popup, :project_id => @project.identifier, :from_url => {}
    assert_nil @response.body =~ /classic/i
    assert_nil @response.body =~ /editor style/i
  end

end
