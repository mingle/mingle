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

class CardsHelperTest < ActionView::TestCase
  include ApplicationHelper, CardsHelper, ActionView::Helpers::JavaScriptHelper, ActionView::Helpers::TagHelper, ActionView::Helpers::FormTagHelper, ActionView::Helpers::FormOptionsHelper, TreeFixtures::PlanningTree, ActionView::Helpers::TextHelper


  def setup
    login_as_member
    @project = create_project
    setup_property_definitions :release => ['1'], :status => ['new', 'open', 'closed']
    setup_numeric_property_definition("thing", [1,2,3])
    create_card!(:name => 'card 1', :thing => 1)
    create_card!(:name => 'card 2')
    create_card!(:name => 'card 3')
    create_card!(:name => 'card 4')
    create_card!(:name => 'card 5')
    @first_card = @project.cards.find_by_number(1)
    @another_card = @project.cards.find_by_number(4)
    view_helper.default_url_options = {:project_id => @project.identifier, :host => 'example.com'}
  end

  def test_card_aggregate_properties_should_return_json_string_of_all_aggregate_property_and_values
    view = CardListView.find_or_construct(@project, {:group_by => { :lane =>"status"}, :aggregate_type => { :column => "sum", :row => "count"}, :aggregate_property => { :column => "thing" }})
    assert_equal("{\"thing\":\"1\",\"wip.thing\":\"1\"}", card_aggregate_properties(@first_card, view))
  end

  def test_transitions_require_popup_array_works_for_require_comment
    close_transtion = create_transition @project, 'close', :set_properties => {'status' => 'close'}
    open_transtion = create_transition @project, 'open', :set_properties => {'status' => 'open'}, :require_comment => true
    status_transition = create_transition @project, 'status', :set_properties => {'status' => Transition::USER_INPUT_REQUIRED}

    assert !close_transtion.require_comment
    assert open_transtion.require_comment
    assert status_transition.require_user_to_enter?
    @project.transitions.reload
    assert_equal "transitions_require_comment = new Array();transitions_require_comment.push(\"open\");", transitions_require_popup_array
  end

  def test_color_by_and_group_by_option_are_not_exclusive
    @project = first_project
    @project.activate
    @view = CardListView.find_or_construct(@project)

    assert options_for_group_by_column.include?(["Release", "release", "Release"])
    assert options_for_color_by.include?(["Release", 'release', "Release"])
    @view = CardListView.find_or_construct(@project, {:group_by => 'release'})

    assert options_for_group_by_column.include?(["Release", "release", "Release"])
    assert options_for_group_by_column.include?(["Release", 'release', "Release"])
    @view = CardListView.find_or_construct(@project, {:color_by => 'release'})

    assert options_for_group_by_column.include?(["Release", "release", "Release"])
    assert options_for_group_by_column.include?(["Release", 'release', "Release"])
  end

  def test_group_by_options_with_excluding_an_option
    with_first_project do |project|
      @view = CardListView.find_or_construct(project)
      status = project.find_property_definition('status')
      assert !options_for_group_by_column(status).collect(&:first).include?('Status')
    end
  end

  def test_style_switching_panel
    view = CardListView.find_or_construct(@project, {:style => 'list'})
    assert_equal "List", Nokogiri::HTML::DocumentFragment.parse(style_switch_panel(view)).search(".selected_view").text
    view = CardListView.find_or_construct(@project, {:style => 'grid'})
    assert_equal "Grid", Nokogiri::HTML::DocumentFragment.parse(style_switch_panel(view)).search(".selected_view").text
  end

  def test_switch_to_tree_style_should_highlight_the_tree_icon
    @project.tree_configurations.create!(:name => 'Planning')
    view = CardListView.find_or_construct(@project, {:style => 'tree', :tree_name => 'Planning'})
    result = style_switch_panel(view)
    assert_equal "Tree", Nokogiri::HTML::DocumentFragment.parse(style_switch_panel(view)).search(".selected_view").text
  end

  def test_should_not_create_filter_values_if_property_definition_name_is_not_set
    view_with_ignored_filter = CardListView.find_or_construct(@project, {:filters => ['[][is][:ignore]', '[status][is][open]']})
    view_without_ignored_filter = CardListView.find_or_construct(@project, {:filters => ['[status][is][open]']})
    assert_equal 1, view_with_ignored_filter.filters.size
    assert_equal to_js_filters(view_with_ignored_filter.filters), to_js_filters(view_without_ignored_filter.filters)
  end

  def test_show_add_children_link_does_not_display_when_the_card_cannot_be_a_parent
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.find_by_name('three level tree')
      type_release, type_iteration, type_story = find_planning_tree_types

      card_not_on_tree = project.cards.create!(:name => 'not_on_tree', :card_type => type_iteration)
      assert_equal '', show_add_children_link(CardsHelper::CARD_SHOW_MODE, card_not_on_tree, tree_configuration, 'tab name')

      card_at_bottom_level = project.cards.find_by_name('story1')
      assert_equal '', show_add_children_link(CardsHelper::CARD_SHOW_MODE, card_at_bottom_level, tree_configuration, 'tab name')
    end
  end

  def test_show_add_children_link_should_not_show_on_card_edit_page
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.find_by_name('three level tree')
      type_release, type_iteration, type_story = find_planning_tree_types

      valid_card = project.cards.find_by_name('iteration1')
      assert_equal '', show_add_children_link(CardsHelper::CARD_EDIT_MODE, valid_card, tree_configuration, 'tab name')
    end
  end

  def test_show_add_children_link_when_user_does_not_have_permission
    with_three_level_tree_project do |project|
      user = User.find_by_login('member')
      user.light = true
      user.save!
      project.member_roles.setup_user_role(user, :readonly_member)
      project.reload

      tree_configuration = project.tree_configurations.find_by_name('three level tree')
      type_release, type_iteration, type_story = find_planning_tree_types

      valid_card = project.cards.find_by_name('iteration1')
      Thread.current[:controller_name] = 'cards'
      begin
        assert_equal '', show_add_children_link(CardsHelper::CARD_SHOW_MODE, valid_card, tree_configuration, 'tab name')
      ensure
        Thread.current[:controller_name] = nil
      end
    end
  end

  def test_relationship_filter_options_should_include_plv_of_that_relationship_property
    with_three_level_tree_project do |project|
      config = project.tree_configurations.first
      n = config.create_tree
      iteration = project.find_property_definition('planning iteration')
      iteration_type = project.card_types.find_by_name('iteration')
      create_plv!(project, :name => 'current iteration', :value => n['iteration1'].id, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => iteration_type, :property_definition_ids => [iteration.id])
      create_plv!(project, :name => 'next iteration', :value => n['iteration2'].id, :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => iteration_type, :property_definition_ids => [iteration.id])
      iteration.reload
      name_values = to_js_property_definition_structure([iteration]).first[:nameValuePairs]
      assert_include '(current iteration)', name_values.flatten
      assert_include '(next iteration)', name_values.flatten
    end
  end

  # bug 3681
  def test_tree_from_url_uses_tree_id_instead_of_tree_name
    with_three_level_tree_project do |project|
      config = project.tree_configurations.first

      @view = CardListView.find_or_construct(project, {:tree_name => config.name, :style => 'tree'})
      assert tree_from_url_params.key?(:tree_id)
      assert !tree_from_url_params.key?(:tree_name)
    end
  end

  def test_tree_belonging_message
    create_tree_project(:init_planning_tree_with_multi_types_in_levels) do |project, tree, configure|
      type_release, type_iteration, type_story = find_planning_tree_types
      create_card!(:name => 'release2', :card_type => type_release)
      create_card!(:name => 'iteration3', :card_type => type_iteration)
      create_card!(:name => 'story6', :card_type => type_story)
      assert_tree_belonging_message configure, 'release1', "This card belongs to this tree."
      assert_tree_belonging_message configure, 'iteration2', "This card belongs to this tree."
      assert_tree_belonging_message configure, 'story5', "This card belongs to this tree."

      assert_tree_belonging_message configure, 'release2', "This card is available to this tree."
      assert_tree_belonging_message configure, 'iteration3', "This card is available to this tree."
      assert_tree_belonging_message configure, 'story6', "This card is available to this tree."

      assert_tree_belonging_message configure, 'story1', "This card belongs to this tree."
      assert_tree_belonging_message configure, 'story4', "This card belongs to this tree."
      assert_tree_belonging_message configure, 'iteration1', "This card belongs to this tree."
    end
  end

  # bug 4633
  def test_no_cards_for_project_message_will_look_normal_when_user_is_read_only
    member_user = User.find_by_login('member')

    @project.add_member(member_user)
    @view = CardListView.find_or_construct(@project)
    actual_link = no_cards_for_project_message(@project, :create_first_card_link => 'LINK1', :import_cards_link => 'LINK2')
    link_one = "<a href=\"http://mingle?action=new&controller=cards\">Create the first card</a>"
    link_two = "<a href=\"http://mingle?action=import&controller=cards_import\">import existing cards</a>"
    assert_include "There are no cards for #{@project.name}", actual_link
    assert_include "Create the first card", actual_link
    assert_include "import existing cards", actual_link

    @project.add_member(member_user, :readonly_member)
    actual_link = no_cards_for_project_message(@project, :create_first_card_link => 'LINK1', :import_cards_link => 'LINK2')
    assert_include "There are no cards for #{@project.name}", actual_link
    assert_not_include "Create the first card", actual_link
    assert_not_include "import existing cards", actual_link
  end

  def test_tree_belongings_warning_should_be_blank_if_no_trees_present
    assert_nil(tree_belongings_warning([]))
  end

  def test_tree_belongings_warning_should_list_multiple_trees
    assert_equal("Belongs to 2 trees: #{'Planning'.bold} and #{'Release 1'.bold}. Any child cards will remain in the trees.".as_li, tree_belongings_warning(['Planning', 'Release 1']))
  end

  def test_tree_relationship_usage_warning_should_show_no_warning_if_not_parent_to_any_cards
    assert_nil(tree_relationship_usage_warning(0, []))
  end

  def test_card_types_options
    @project.card_types.delete_all
    hello = @project.card_types.create(:name => 'hello')
    kitty = @project.card_types.create(:name => 'kitty')
    assert_equal [['hello', 'hello'], ['kitty', 'kitty']], card_type_options
  end

  def test_card_relationship_usage_warning_should_show_property_names
    assert_equal("Used as a card relationship property value on #{'1 card'.bold}. Card relationship property, #{'Completed Release'.bold}, will be (not set) for all affected cards.".as_li, card_relationship_usage_warning(1, ['Completed Release']))
  end

  def test_tree_relationship_usage_warning_should_show_property_names
    assert_equal("Used as a tree relationship property value on #{'2 cards'.bold}. Tree relationship properties, #{'Planned Iteration'.bold} and #{'Completed Iteration'.bold}, will be (not set) for all affected cards.".as_li, tree_relationship_usage_warning(2, ['Planned Iteration', 'Completed Iteration']))
  end

  def test_group_by_transition_only_returns_false_if_group_by_is_not_selected
    @view = CardListView.find_or_construct(@project, :group_by => nil)
    assert !group_by_transition_only?
  end

  def test_group_by_transition_only_returns_false_if_group_by_property_is_not_transition_only
    status = @project.find_property_definition('status')
    @view = CardListView.find_or_construct(@project, :group_by => 'status')
    assert !group_by_transition_only?
  end

  def test_group_by_transition_only_returns_true_if_group_by_property_is_transition_only
    setup_property_definitions :foo => ['100']
    transition_only = @project.find_property_definition('foo')
    transition_only.update_attribute :transition_only, true
    create_transition(@project, 'transition_only', :set_properties => { :foo => '100' })
    @view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'foo')
    assert group_by_transition_only?
  end

  def test_rank_url_params_gives_td_html_attribute_correctly
    @view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status', :grid_sort_by => '')
    url_params = rank_url_params(@project, @view.group_lanes.visibles(:lane).first)
    assert_equal 'cards', url_params[:controller]
    assert_equal 'set_value_for', url_params[:action]
    assert_equal @project.identifier, url_params[:project_id]

    @view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status', :grid_sort_by => 'number')
    url_params = rank_url_params(@project, @view.group_lanes.visibles(:lane).first)
    assert_nil url_params
  end

  def test_set_value_for_attribute_keep_rank_mode_and_set_correct_action_and_value
    @view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status', :grid_sort_by => '', :lanes => ' ,closed', :rank_is_on => 'false')
    url_params = set_value_for_url_params(@project, @view.group_lanes.visibles(:lane).find { |lane| lane.value == 'closed' })
    assert_equal 'set_value_for', url_params[:action]
    assert_not_nil url_params[:rank_is_on]
    assert_equal false, url_params[:rank_is_on]
    assert_equal 'closed', url_params[:value]
  end

  def test_show_twisty_if_node_has_children_except_the_root_node
    with_three_level_tree_project do |project|
      tree = project.find_tree_configuration('three level tree').create_tree
      assert show_twisty_for?(tree.find_node_by_name('release1'))
      assert !show_twisty_for?(tree.root)
      assert !show_twisty_for?(tree.find_node_by_name('story1'))
    end
  end

  def test_show_info_instead_of_link_when_limit_exceeded
    assert_match /<p/, export_to_excel_link(99999)
  end

  def test_when_limit_enabled_export_link_is_enabled_if_cards_in_view_are_less_than_500
    assert_match /<a/, export_to_excel_link(499)
  end

  def test_when_limit_enabled_export_link_is_enabled_if_cards_in_view_are_equal_to_500
    assert_match /<a/, export_to_excel_link(500)
  end

  def test_when_limit_enabled_export_link_is_disabled_if_cards_in_view_are_over_500
    assert_match /<p class=\"disabled.*>Export cards<\/p>/, export_to_excel_link(501)
  end

  def test_can_add_lane_is_true_when_grouped_by_enum_prop
    @view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status', :lanes => 'new,open,closed')
    assert can_add_lane?(@view)
  end

  def test_can_add_lane_is_true_when_only_not_set_lane_visible
    @view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status', :lanes => ' ')
    assert can_add_lane?(@view)
  end

  def test_cannot_hide_lane_when_not_an_enumerated_property
    @view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'dev')
    assert_false @view.group_lanes.visibles(:lane).first.can_hide?
  end

  def test_can_hide_lane_when_it_is_an_enumerated_property
    @view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status', :lanes => 'new,open')
    assert @view.group_lanes.visibles(:lane).first.can_hide?
  end

  def test_only_project_admin_can_reorder_columns
    @project.add_member(User.find_by_login('proj_admin'), :project_admin)
    login_as_member
    @view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status', :grid_sort_by => '', :lanes => 'new,open,closed')

    assert_false can_reorder_lane?(@view.group_lanes.visibles(:lane).first)
    login_as_proj_admin
    assert can_reorder_lane?(@view.group_lanes.visibles(:lane).first)
  end

  def test_include_card_ready_status_as_part_of_cta_url
    with_new_project do |project|
      setup_managed_text_definition("status", ['new', 'open', 'closed'])
      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => 'status', :lanes => 'new,open,closed')
      assert_false cta_params(reload_view(view), view_helper)[:cards_ready]

      project.cards.create!(:name => 'status not set', :card_type_name => 'card')
      assert_false cta_params(reload_view(view), view_helper)[:cards_ready]

      card = project.cards.create!(:name => 'changing status', :card_type_name => 'card')
      assert_false cta_params(reload_view(view), view_helper)[:cards_ready]

      card.update_attribute('cp_status', 'new')
      assert_false cta_params(reload_view(view), view_helper)[:cards_ready]

      card.update_attribute('cp_status', 'closed')
      assert cta_params(reload_view(view), view_helper)[:cards_ready]
    end
  end

  def reload_view(view)
    CardListView.find_or_construct(view.project, view.to_params)
  end

  def test_cta_params_has_card_type_uri
    MingleConfiguration.overridden_to(:site_u_r_l => "http://example.com") do
      view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status')
      expected_uri = "http://example.com/api/v2/projects/#{@project.identifier}/card_types/#{@project.card_types.first.id}.xml"
      assert_equal expected_uri, cta_params(view, view_helper)[:process_definition][:card_type_uri]
    end
  end

  def test_cta_params_has_property_uri
    MingleConfiguration.overridden_to(:site_u_r_l => "http://example.com") do
      view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status')
      assert_equal "http://example.com/api/v2/projects/#{@project.identifier}/property_definitions/#{@project.find_property_definition('status').id}.xml", cta_params(view, view_helper)[:process_definition][:property_uri]
    end
  end

  def test_cta_params_has_property_values
    view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status', :grid_sort_by => '', :lanes => 'new,open')
    assert_equal ['new', 'open', 'closed'], cta_params(view, view_helper)[:process_definition][:stages]
  end

  def test_cta_params_has_start_and_end_value
    view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status', :grid_sort_by => '', :lanes => 'new,open')
    assert_equal 'new', cta_params(view, view_helper)[:start_value]
    assert_equal 'open', cta_params(view, view_helper)[:end_value]
  end

  def test_cta_params_uses_api_url_when_configured
    MingleConfiguration.overridden_to(:api_u_r_l => "https://mingle-api:7900/") do
      view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status')
      assert_equal "https://mingle-api:7900/api/v2/projects/#{@project.identifier}.xml", cta_params(view, view_helper)[:source_uri]
      assert_equal "https://mingle-api:7900/api/v2/projects/#{@project.identifier}/property_definitions/#{@project.find_property_definition('status').id}.xml", cta_params(view, view_helper)[:process_definition][:property_uri]
      assert_equal "https://mingle-api:7900/api/v2/projects/#{@project.identifier}/card_types/#{@project.card_types.first.id}.xml", cta_params(view, view_helper)[:process_definition][:card_type_uri]

    end
  end

  def test_cta_params_has_last_completed_in_when_configured
    MingleConfiguration.overridden_to(:cycle_time_last_completed_in => "315360000") do
      view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status', :grid_sort_by => '', :lanes => 'new,open')
      assert_equal '315360000', cta_params(view, view_helper)[:last_completed_in]
    end
  end

  def test_cta_params_has_time_zone_offset
    @project.update_attributes(:exclude_weekends_in_cta => true, :time_zone => 'Berlin')
    view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status')
    assert_equal 3600000, cta_params(view, view_helper)[:ignore_weekend_by_tz_offset]
  end

  def test_cta_params_does_not_time_zone_offset
    view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status')
    assert_nil cta_params(view, view_helper)[:ignore_weekend_by_tz_offset]
  end

  def test_cta_params_has_admin_flag
    view = CardListView.find_or_construct(@project, :style => 'grid', :group_by => 'status')
    assert_false cta_params(view, view_helper)[:admin]
    login_as_proj_admin
    assert cta_params(view, view_helper)[:admin]
    login_as_admin
    assert cta_params(view, view_helper)[:admin]
  end

  private

  def params
    @params || {}
  end

  def controller
    @controller
  end

  def protect_against_forgery?
    false
  end

  def image_tag(image_name, options={})
    image_name
  end

  def link_to(name, options={}, html_options = nil)
    "<a href=\"http://mingle?#{options.to_query}\"> #{name}</a>"
  end

  def url_for(*args)
    "http://mingle.exmaple"
  end

  def assert_tree_belonging_message(tree_configure, card_name, expected_message)
    card = tree_configure.project.cards.find_by_name(card_name)
    assert_equal(expected_message, tree_belonging_message(tree_configure, card))
  end
end
