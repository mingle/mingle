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

class CardControllerTreeActionsTest < ActionController::TestCase
  include TreeFixtures::PlanningTree

  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_admin
    @project = three_level_tree_project
    @project.activate
    @tree_config = @project.tree_configurations.find_by_name('three level tree')
    @type_release, @type_iteration, @type_story = find_planning_tree_types
  end

  def test_should_add_child_to_card_in_tree_and_disable_child
    new_release = create_card!(:name => 'new release', :card_type => @type_release)
    new_iteration = create_card!(:name => 'new iteration', :card_type => @type_iteration)

    post :add_children, :project_id => @project.identifier, :tree => @tree_config.id, :child_numbers => new_release.number, :parent_expanded => 'true'
    assert_response :success
    assert @tree_config.include_card?(new_release)
    post :add_children, :project_id => @project.identifier, :tree => @tree_config.id, :child_numbers => new_iteration.number, :parent_number => new_release.number, :parent_expanded => 'true'
    assert_response :success
    assert @tree_config.include_card?(new_iteration)

    new_release.reload
    new_iteration.reload

    tree = @tree_config.create_tree
    new_release_node = tree.find_node_by_number(new_release.number)
    new_iteration_node = tree.find_node_by_number(new_iteration.number)
    assert_equal new_iteration_node.name, new_release_node.children.first.name
    assert_equal new_release_node.name, new_iteration_node.parent.name

    assert tree.configuration.contains?(new_release, new_iteration)
  end

  def test_should_add_first_child_to_tree_root_and_disable_child
    with_new_project do |project|
      type_iteration = project.card_types.create! :name => 'iteration'
      type_release = project.card_types.create! :name => 'release'
      tree_config = project.tree_configurations.create!(:name => 'planning tree')
      tree_config.update_card_types({
        type_release => {:position => 0, :relationship_name => 'planning release'},
        type_iteration => {:position => 1},
      })
      release1 = create_card!(:name => 'release 1', :type => type_release.name)
      iteration1 = create_card!(:name => 'story 1', :type => type_iteration.name)

      post :add_children, :project_id => project.identifier, :tree => tree_config.id, :child_numbers => release1.number, :parent_expanded => 'true'
      assert_response :success
      assert tree_config.include_card?(release1)

      release1.reload
      release1_node = tree_config.create_tree.find_node_by_number(release1.number)
      assert release1_node.parent
    end
  end

  def test_should_add_children_show_error_messages_when_it_failed
    new_iteration = create_card!(:name => 'new iteration', :card_type => @type_iteration)
    new_story = create_card!(:name => 'new story', :card_type => @type_story)
    story1 = @project.cards.find_by_name('story1')

    post :add_children,
        :project_id => @project.identifier,
        :tree => @tree_config.id,
        :parent_number => story1.number,
        :child_numbers => [new_iteration.number, new_story.number].join(','),
        :parent_expanded => 'true'
    assert_response :success
    assert_error

    assert_match "Type <b>story</b> cannot contain type <b>iteration</b>", json_unescape(@response.body)
    assert_match "Type <b>story</b> cannot contain type <b>story</b>", json_unescape(@response.body)
  end

  def test_add_children_to_card_in_tree_and_disable_children
    release3 = create_card!(:name => 'release3', :card_type => @type_release)
    release4 = create_card!(:name => 'release4', :card_type => @type_release)

    post :add_children, :project_id => @project.identifier, :tree => @tree_config.id, :parent_expanded => 'true', :child_numbers => [release3.number, release4.number].join(',')
    assert_response :success
    assert_equal ['release1', 'release3', 'release4'], @tree_config.create_tree.root.children.collect(&:name).sort
  end

  def test_delete_card_and_roll_up_its_children_from_tree
    planning_iteration = @project.find_property_definition('Planning iteration')
    iteration1 = @project.cards.find_by_name('iteration1')
    post :remove_card_from_tree, :style => 'tree', :tree => @tree_config, :card_id => iteration1.id.to_s, :project_id => @project.identifier, :tree_name => @tree_config.name
    assert_response :success

    assert_equal ['three level tree', 'release1', 'iteration2', 'story1', 'story2'].sort, @tree_config.create_tree.nodes.collect(&:name).sort
    assert_nil planning_iteration.value(@project.cards.find_by_name('story1'))
  end

  def test_delete_card_and_its_children_from_tree
    iteration1 = @project.cards.find_by_name('iteration1')
    post :remove_card_from_tree, :tree => @tree_config, :card_id => iteration1.id.to_s, :project_id => @project.identifier, :and_children => "true", :tree_name => @tree_config.name
    assert_response :success

    @project.reload
    assert_equal ['three level tree', 'release1', 'iteration2'], @tree_config.create_tree.nodes.collect(&:name)
  end

  def test_delete_card_on_card_view
    iteration1 = @project.cards.find_by_name('iteration1')
    post :remove_card_from_tree_on_card_view, :tree => @tree_config, :card_id => iteration1.id.to_s, :project_id => @project.identifier
    assert_response :success

    assert_equal ['three level tree', 'release1', 'iteration2', 'story1', 'story2'].sort, @tree_config.create_tree.nodes.collect(&:name).sort

  end

  def test_quick_add_tree_node
    iteration2 = @project.cards.find_by_name('iteration2')
    post :tree_cards_quick_add, :project_id => @project.identifier, :tree => @tree_config.id, :parent_number => iteration2.number, :card_type => @type_story,
        :card_names => ['story3', '  ', 'story4']

    assert_response :success
    assert_equal ['story3', 'story4'], @tree_config.create_tree.find_node_by_card(iteration2).children.collect(&:name).sort
  end

  def test_quick_add_tree_node_to_root
    post :tree_cards_quick_add_to_root, :project_id => @project.identifier, :tree => @tree_config.id, :card_type => @type_story,
        :card_names => ['story3', 'story4']

    assert_response :success
    assert_equal ['release1', 'story3', 'story4'], @tree_config.create_tree.root.children.collect(&:name).sort
  end

  def test_quick_add_to_tree_should_show_errors_when_card_name_is_too_long
    post :tree_cards_quick_add_to_root, :project_id => @project.identifier, :tree => @tree_config.id, :card_type => @type_story,
        :card_names => ['s' * 1000]

    assert_response :success
    assert_equal ['release1'], @tree_config.create_tree.root.children.collect(&:name)
    assert_error
    assert_rollback
  end

  def test_quick_add_to_tree_should_show_card_default_errors
    assert User.first_admin.current?

    card_defaults = @type_story.card_defaults
    card_defaults.update_properties :owner => PropertyType::UserType::CURRENT_USER
    card_defaults.save!

    post :tree_cards_quick_add_to_root, :project_id => @project.identifier, :tree => @tree_config.id, :card_type => @type_story,
         :card_names => ['jenny lewis', 'the watson twins']

    assert_response :success
    assert_equal ['release1'], @tree_config.create_tree.root.children.collect(&:name)
    assert_error
    assert_rollback
  end

  def test_tree_cards_quick_add_shuold_not_add_cards_number_to_card_context_whose_type_is_filtered
    release1 = @project.cards.find_by_name 'release1'
    post :tree_cards_quick_add, :project_id => @project.identifier, :tree => @tree_config.id, :parent_number => release1.number, :card_type => @type_iteration,
        :card_names => ['new iteration'], :excluded => [@type_iteration.name]
    new_iteration = @project.cards.find_by_name 'new iteration'

    assert_not_include new_iteration.number, @controller.card_context.current_list_navigation_card_numbers
  end

  def test_tree_cards_quick_add_from_card_show
    with_three_level_tree_project do |project|
      text_with_more_than_255_characters = "a" * 256

      type_release, type_iteration, type_story = find_planning_tree_types
      tree_configuration = project.tree_configurations.find_by_name('three level tree')
      iteration1 = project.cards.find_by_name('iteration1')

      xhr :post, :tree_cards_quick_add, :project_id => project.identifier, :tree => tree_configuration.id, :parent_number => iteration1.number, :tab => 'tab_name',
          :from_card_show => true, :card_type => type_story.id, :card_names => ['child 1 of iteration1', 'child 2 of iteration1']

      assert_rjs 'replace', 'flash', /2 cards were created successfully/
      assert project.cards.find_by_name('child 1 of iteration1').card_type == type_story
      assert project.cards.find_by_name('child 2 of iteration1').card_type == type_story
      assert_match "Planning release", @response.body # make sure we're replacing property container partial
      assert_no_rjs 'insert_html' # make sure we're not getting into the tree_view rendering

      xhr :post, :tree_cards_quick_add, :project_id => project.identifier, :tree => tree_configuration.id, :parent_number => iteration1.number, :tab => 'tab_name',
          :from_card_show => true, :card_type => type_story.id, :card_names => [text_with_more_than_255_characters]
      assert_rjs 'replace', 'flash', /#{text_with_more_than_255_characters.truncate_with_ellipses(50)}.*Name is too long/
    end
  end

  def test_tree_cards_quick_add_from_card_show_works_when_a_transition_that_removes_a_card_from_tree_exists
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.find_by_name('three level tree')
      iteration = project.card_types.find_by_name('iteration')
      create_transition(project, 'remove from tree', :card_type => iteration, :remove_from_trees_with_children => [tree_configuration])
      type_release, type_iteration, type_story = find_planning_tree_types
      iteration1 = project.cards.find_by_name('iteration1')

      xhr :post, :tree_cards_quick_add, :project_id => project.identifier, :tree => tree_configuration.id, :parent_number => iteration1.number, :tab => 'tab_name',
          :from_card_show => false, :card_type => type_story.id, :card_names => ['child 1 of iteration1', 'child 2 of iteration1']

      assert_rjs 'replace', 'flash', /2 cards were created successfully/
      assert project.cards.find_by_name('child 1 of iteration1').card_type == type_story
      assert project.cards.find_by_name('child 2 of iteration1').card_type == type_story
    end
  end

  def test_quick_add_tree_node_should_populate_card_default_properties
    with_filtering_tree_project do |project|
      tree_config = project.tree_configurations.find_by_name('filtering tree')
      release1 = project.cards.find_by_name('release1')
      type_iteration = project.card_types.find_by_name('iteration')
      type_iteration.card_defaults.update_properties :quick_win => 'yes'

      post :tree_cards_quick_add, :project_id => project.identifier, :tree => tree_config.id, :parent_number => release1.number, :card_type => type_iteration, :card_names => ['some iteration', 'another iteration']
      some_iteration = project.cards.find_by_name('some iteration')
      another_iteration = project.cards.find_by_name('another iteration')
      assert_equal 'yes', some_iteration.cp_quick_win
      assert_equal 'yes', another_iteration.cp_quick_win
    end
  end

  #bug 3407 and 3688
  def test_should_display_message_when_added_card_into_tree_but_it_is_filtered
    iteration1 = @project.cards.find_by_name('iteration1')
    card = create_card!(:name => 'new card', :card_type => 'Story')

    post :add_children, :project_id => @project.identifier, :tree => @tree_config.id, :child_numbers => card.number, :tf_release => ["[release1][is][#{iteration1.number}]"]
    assert json_unescape(@response.body).include?("1 card was added to #{@tree_config.name.html_bold}, but is not shown because it does not match the current filter.")
  end

  def test_should_display_filter_message_when_added_card_into_tree_but_it_is_filtered_and_parent_is_collapsed
    iteration1 = @project.cards.find_by_name('iteration1')
    card = create_card!(:name => 'new card', :card_type => 'Story')

    post :add_children, :project_id => @project.identifier, :tree => @tree_config.id, :child_numbers => card.number, :tf_release => ["[release1][is][#{iteration1.number}]"]
    assert json_unescape(@response.body).include?("1 card was added to #{@tree_config.name.html_bold}, but is not shown because it does not match the current filter.")
    assert !json_unescape(@response.body).include?("0 cards  added to #{@tree_config.name.html_bold}, but  not shown because that tree node is collapsed.")
  end

  def test_add_children_should_move_card_within_tree_when_the_child_number_is_already_in_the_tree
    create_tree_project(:init_two_release_planning_tree) do |project, tree, config|
      release2 = project.cards.find_by_name('release2')
      iteration1 = project.cards.find_by_name('iteration1')
      post :add_children, :project_id => project.identifier, :tree => config.id, :child_numbers => iteration1.number, :parent_number => release2.number, :parent_expanded => 'true'
      assert_response :success
      config.reload
      assert_equal ['iteration1', 'iteration3'].sort, config.create_tree.find_node_by_name('release2').children.collect(&:name).sort
      assert_equal ['Planning', 'release1', 'iteration2', 'release2', 'iteration1', 'story1', 'story2', 'iteration3'].sort, tree.nodes.collect(&:name).sort
    end
  end

  def test_add_children_from_card_explorer_should_not_show_child_if_it_does_not_match_the_filter
    create_tree_project(:init_two_release_planning_tree) do |project, tree, config|
      story_type = project.card_types.find_by_name('story')
      iteration_type = project.card_types.find_by_name('iteration')
      parent_card = project.cards.find_by_name('release2')
      child_story1 = project.cards.create!(:name => 'goldie locks and the three bears', :card_type => story_type)
      child_story2 = project.cards.create!(:name => 'jack and jill', :card_type => story_type)
      child_iteration = project.cards.create!(:name => 'iteration4', :card_type => iteration_type)
      existing_iteration = project.cards.find_by_name('iteration3')

      post :add_children, :project_id => project.identifier, :tree => config.id, :child_numbers => "#{child_iteration.number},#{child_story1.number},#{child_story2.number}", :parent_number => parent_card.number, :parent_expanded => 'true', :excluded => [story_type.name], :expands => parent_card.number.to_s

      assert_response :success
      config.reload
      assert_info "2 cards were added to #{parent_card.number_and_name.html_bold}, but are not shown because they do not match the current filter."
      assert_equal [existing_iteration.name, child_iteration.name, child_story1.name, child_story2.name].sort, config.create_tree.find_node_by_name(parent_card.name).children.collect(&:name).sort
    end
  end

  def test_select_tree_should_be_fine_when_tree_has_not_been_visited_before
    create_tree_project(:init_two_release_planning_tree) do |project, tree, config|
      post :select_tree, :project_id => project.identifier, :tab => 'All', :style => 'tree', :tree_name => config.name
      assert_redirected_to :action => :list, :style => :tree, :project_id => project.identifier, :tree_name => config.name
    end
  end

  def test_select_no_tree_on_a_tree_view_should_redirect_to_list_view
    post :select_tree, :project_id => @project.identifier, :tab => 'All', :style => 'tree'
    assert_redirected_to :action => :list, :project_id => @project.identifier
  end

  def test_select_no_tree_on_a_grid_view_should_redirect_to_grid_view
    post :select_tree, :project_id => @project.identifier, :tab => 'All', :style => 'grid'
    assert_redirected_to :action => :list, :style => 'grid', :project_id => @project.identifier
  end

  def test_select_tree_should_remember_prior_parameters
    create_tree_project(:init_two_release_planning_tree) do |project, tree, config|
      get :list, :project_id => project.identifier, :tab => 'All', :filters => ['[Type][is][story]'], :columns => "Created by"
      assert_response :success

      get :list, :project_id => project.identifier, :tab => 'All', :excluded => ['story'], :tree_name => config.name, :columns => "Modified by"
      assert_response :success

      post :select_tree, :project_id => project.identifier, :tab => 'All', :style => 'list'
      assert_redirected_to :filters => ['[Type][is][story]'], :columns => "Created by"

      post :select_tree, :project_id => project.identifier, :tab => 'All', :style => 'tree', :tree_name => config.name
      assert_redirected_to :excluded => ['story'], :columns => "Modified by", :tree_name => config.name
    end
  end

  def test_tree_should_show_link_to_this_page
    with_filtering_tree_project do |project|
      get :list, :project_id => project.identifier, :tree_name => 'filtering tree', :tab => 'All',:style => "tree"
      assert_select 'a', :text => 'Update URL'
    end
  end

  def test_should_display_reset_filter_link_when_filtered_down_to_no_cards
    with_filtering_tree_project do |project|
      get :list, :project_id => project.identifier, :tree_name => 'filtering tree', :style => 'tree', :tab => 'All', :excluded => %w{release iteration story task minutia}
      assert_info "No cards that have been assigned to <strong title=\"filtering tree\">filtering tree</strong> tree match the current filter - <a href=\"/projects/filtering_tree_project/cards/tree?tab=All&amp;tree_name=filtering+tree\">Reset filter</a>"
    end
  end

  def test_should_show_warning_message_when_quick_added_card_will_not_shows
    iteration1 = @project.cards.find_by_name('iteration1')
    post :tree_cards_quick_add, :project_id => @project.identifier, :tree => @tree_config.id,
      :parent_number => iteration1.number, :excluded => [@type_story.name], :style => 'tree', :tree_name => @tree_config.name,
      :card_type => @type_story.id, :card_names => ['story jia', 'story yi']
    assert json_unescape(@response.body).include?("2 cards were added to #{iteration1.number_and_name.html_bold}, but are not shown because they do not match the current filter.")
  end

  def test_should_not_show_expand_or_collapse_node_in_the_root_node
    get :list, :project_id => @project.identifier, :tree_name => 'three level tree', :style => "tree"
    assert_select "#twisty_for_card_0", false
  end

  def test_should_not_show_subtree_when_the_node_has_children_but_not_collapsed
    get :list, :project_id => @project.identifier, :tree_name => 'three level tree', :style => "tree"
    assert_select "div[class=sub-tree no-child]", :count => 1
  end

  # Bug 6833
  def test_should_add_the_subtree_to_the_card_context_when_add_card_to_the_collapsed_node
    release1 = @project.cards.find_by_name('release1')
    card = create_card!(:name => 'new card', :card_type => 'Story')

    post :add_children, :project_id => @project.identifier, :tree => @tree_config.id, :child_numbers => card.number, :parent_number => release1.number
    current_list_card_numbers = [release1.number, @project.cards.find_by_name('iteration1').number,@project.cards.find_by_name('iteration2').number,card.number]
    assert_equal current_list_card_numbers.sort, @controller.card_context.current_list_navigation_card_numbers.sort
  end
end
