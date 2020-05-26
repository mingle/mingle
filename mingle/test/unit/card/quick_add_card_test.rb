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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/quick_add_card_support')

class QuickAddCardTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree, QuickAddCardSupport

  def setup
    @project = first_project
    @project.activate
    login_as_member

    @type_bug = @project.card_types.create!(:name => 'bug')
    @project.find_property_definition('status').card_types = [@type_bug]
    @project.reload
    @type_bug.card_defaults.update_properties(:status => 'open')
  end

  def teardown
    Clock.reset_fake
  end

  def test_should_ignore_filters_when_creating_card_from_default
    status_def = @project.find_property_definition('status')
    priority_def = @project.find_property_definition('priority')
    priority_def.card_types = [@type_bug]
    @project.reload

    quick = build_quick_add_card_via_filters(["[Type][is][bug]", "[priority][is][Critical]"], :use_filters => false)
    card = quick.card
    assert_equal nil, card.cp_priority
    assert_equal "open", card.cp_status
    assert_equal [status_def], quick.displayed_inherited_property_definitions

    quick = build_quick_add_card_via_filters(["[Type][is][bug]", "[priority][is][Critical]"], :use_filters => true)
    card = quick.card
    prop_defs = quick.displayed_inherited_property_definitions
    assert_equal "Critical", card.cp_priority
    assert_equal "open", card.cp_status
    assert_equal 2, prop_defs.size
    assert prop_defs.include?(status_def)
    assert prop_defs.include?(priority_def)
  end

  def test_should_choose_first_value_when_multiple_values_for_properties
    assert_equal "open", build_quick_add_card_via_filters(["[Type][is][bug]", "[status][is][open]", "[status][is][closed]"]).card.cp_status
  end

  def test_should_choose_from_session_when_multiple_values_for_card_type_include_the_card_type_from_session
    view  = CardListView.find_or_construct(@project, :filters => ["[Type][is][bug]", "[Type][is][Card]"])
    quick_add = QuickAddCard.new(view, :use_filters => true, :card_type_from_session => 'Card')
    assert_equal "Card", quick_add.card.card_type_name
  end

  def test_should_choose_card_type_from_session_when_it_satisfies_filter_conditions
    @project.card_types.create!(:name => 'Task')
    @project.reload

    CardListView.find_or_construct(@project, :filters => ["[Type][is not][bug]"]).tap do | view |
      quick_add = QuickAddCard.new(view, :use_filters => true, :card_type_from_session => 'Task')
      assert_equal "Task", quick_add.card.card_type_name

      quick_add = QuickAddCard.new(view, :use_filters => true, :card_type_from_session => 'Card')
      assert_equal "Card", quick_add.card.card_type_name
    end

    CardListView.find_or_construct(@project, :filters => ["[Type][is not][bug]", "[Type][is][Card]"]).tap do | view |
      quick_add = QuickAddCard.new(view, :use_filters => true, :card_type_from_session => 'Card')
      assert_equal "Card", quick_add.card.card_type_name

      quick_add = QuickAddCard.new(view, :use_filters => true, :card_type_from_session => 'Task')
      assert_equal "Task", quick_add.card.card_type_name
    end
  end

  def test_should_choose_card_type_filtered_by_exact_match
    @project.card_types.create!(:name => 'Task')
    @project.reload

    CardListView.find_or_construct(@project, :filters => ["[Type][is not][bug]"]).tap do | view |
      quick_add = QuickAddCard.new(view, :use_filters => true, :card_type_from_session => 'bug')
      assert_equal "Card", quick_add.card.card_type_name
    end

    CardListView.find_or_construct(@project, :filters => ["[Type][is not][bug]", "[Type][is][Task]"]).tap do | view |
      quick_add = QuickAddCard.new(view, :use_filters => true, :card_type_from_session => 'bug')
      assert_equal "Task", quick_add.card.card_type_name
    end
  end

  def test_should_choose_first_card_type_from_filter_when_card_type_from_session_is_not_applicable
    @project.card_types.create!(:name => 'Task')
    @project.reload

    view  = CardListView.find_or_construct(@project, :filters => ["[Type][is][bug]", "[Type][is][Card]"])
    quick_add = QuickAddCard.new(view, :use_filters => true, :card_type_from_session => 'Task')
    assert_equal "bug", quick_add.card.card_type_name
  end

  def test_should_choose_card_type_from_session_only_if_tree_filters_card_types_include_it
    with_three_level_tree_project do |project|

      release_type   = project.card_types.find_by_name 'release'
      iteration_type = project.card_types.find_by_name 'iteration'
      story_type = project.card_types.find_by_name 'story'

      [release_type, iteration_type, story_type].each do |card_type|
        card_type.update_attributes(:name => card_type.name.capitalize)
      end

      release_two    = project.cards.create!(:name => 'release 2',:card_type => release_type)
      iteration_two  = project.cards.create!(:name => 'iteration 2',:card_type => iteration_type)

      tree = project.tree_configurations.first
      view = CardListView.construct_from_params(project, :tree_name => tree.name, :excluded => ["release"])
      quick_add = QuickAddCard.new(view, :use_filters => true)
      assert_equal 'Iteration', quick_add.card.card_type_name

      view = CardListView.construct_from_params(project, :tree_name => tree.name, :excluded => ["release"])
      quick_add = QuickAddCard.new(view, :use_filters => true, :card_type_from_session => 'story')
      assert_equal 'Story', quick_add.card.card_type_name

      project.card_types.create!(:name => 'not_on_tree')
      project.reload

      view = CardListView.construct_from_params(project, :tree_name => tree.name, :excluded => ["release"])
      quick_add = QuickAddCard.new(view, :use_filters => true, :card_type_from_session => 'not_on_tree')
      assert_equal 'Iteration', quick_add.card.card_type_name
    end
  end

  def test_should_choose_card_type_from_session_should_be_case_insensitive
    view  = CardListView.find_or_construct(@project, :filters => ["[Type][is][BUG]", "[Type][is][CARD]"])
    quick_add = QuickAddCard.new(view, :use_filters => true, :card_type_from_session => 'Card')
    assert_equal "Card", quick_add.card.card_type_name
  end

  def test_should_set_card_values_to_defaults
    assert_equal "open", build_quick_add_card_via_filters(["[Type][is][bug]"]).card.cp_status
  end

  def test_should_set_enumerated_properties_based_on_filters
    assert_equal "closed", build_quick_add_card_via_filters(["[Type][is][bug]", "[status][is][closed]"]).card.cp_status
  end

  def test_should_set_card_relationship_properties_based_on_filters
    with_three_level_tree_project do |project|
      story_type = project.card_types.find_by_name 'story'
      iteration_type = project.card_types.find_by_name 'iteration'
      iteration_one  = project.cards.create!(:name => 'iteration 1',:card_type => iteration_type)
      iteration_two  = project.cards.create!(:name => 'iteration 2',:card_type => iteration_type)
      story_type.card_defaults.update_properties('related card' => iteration_one.id)

      assert_equal iteration_two, build_quick_add_card_via_filters(["[Type][is][story]", "[related card][is][#{iteration_two.number}]"]).card.cp_related_card
    end
  end

  def test_should_set_user_properties_based_on_filters
    @project.find_property_definition('dev').card_types = [@type_bug]
    @project.reload
    defaults = @type_bug.card_defaults
    defaults.update_properties(:dev => User.find_by_login('member').id)

    filtered_user = User.find_by_login('bob')
    assert_equal filtered_user, build_quick_add_card_via_filters(["[Type][is][bug]", "[dev][is][#{filtered_user.login}]"]).card.cp_dev
  end

  def test_should_set_user_properties_based_on_filters_for_current_user
    @project.find_property_definition('dev').card_types = [@type_bug]
    @project.reload
    defaults = @type_bug.card_defaults
    defaults.update_properties(:dev => User.find_by_login('bob').id)

    current_user = login_as_member
    assert_equal current_user, build_quick_add_card_via_filters(["[Type][is][bug]", "[dev][is][#{PropertyType::UserType::CURRENT_USER}]"]).card.cp_dev
  end

  def test_should_set_property_values_when_tree_selected
    with_three_level_tree_project do |project|
      project.card_types.find_by_name('story').update_attribute :name, 'StOrY'
      tree_configuration = project.tree_configurations.first
      view = CardListView.find_or_construct(project, :excluded => ["release","iteration"],
        :tree_name => tree_configuration.name,
        :tf_release   => [],
        :tf_iteration => [],
        :tf_story     => ["[status][is][closed]"])
      assert_equal "closed", QuickAddCard.new(view, :use_filters => true).card.cp_status
    end
  end

  def test_displayed_inherited_property_definitions_should_include_properties_that_are_in_card_default
    dev_prop_def = @project.find_property_definition('dev')
    dev_prop_def.card_types = [@type_bug]
    @project.reload
    @type_bug.card_defaults.update_properties(:dev => User.find_by_login('bob').id, :status => nil)
    assert_equal [dev_prop_def], build_quick_add_card_via_filters(["[Type][is][bug]"]).displayed_inherited_property_definitions
  end

  def test_displayed_inherited_property_definitions_should_include_properties_derived_from_filters
    status_prop_def = @project.find_property_definition('status')
    status_prop_def.card_types = [@type_bug]
    @type_bug.card_defaults.update_properties(:status => nil)

    quick_card = build_quick_add_card_via_filters(["[Type][is][bug]", "[Status][is][(not set)]"])
    assert_equal ['Status'], quick_card.displayed_inherited_property_definitions.map(&:name)
  end

  def test_displayed_inherited_property_definitions_should_include_tree_filter_properties_only_for_selected_card_type
    with_three_level_tree_project do |project|
      tree = project.tree_configurations.first
      release_type   = project.card_types.find_by_name 'release'
      iteration_type = project.card_types.find_by_name 'iteration'
      release_two    = project.cards.create!(:name => 'release 2',:card_type => release_type)
      iteration_two  = project.cards.create!(:name => 'iteration 2',:card_type => iteration_type)

      view = CardListView.construct_from_params(project, :tree_name => tree.name,
                                                         :excluded     => ["release", "iteration"],
                                                         :tf_release   => ["[planning release][is][#{release_two.number}]"],
                                                         :tf_iteration => ["[planning iteration][is][#{iteration_two.number}]", "[status][is][open]"],
                                                         :tf_story     => [])
      assert_equal ["Planning release", 'Planning iteration'], QuickAddCard.new(view, :use_filters => true).displayed_inherited_property_definitions.map(&:name)
    end
  end

  def test_displayed_inherited_property_definitions_should_only_include_properties_specified_by_filters
    card_type_with_no_defaults = @project.card_types.create!(:name => 'no_defaults')
    status_prop_def = @project.find_property_definition('status')
    status_prop_def.card_types = [card_type_with_no_defaults]
    @project.reload
    assert_equal [], build_quick_add_card_via_filters(["[Type][is][no_defaults]"]).displayed_inherited_property_definitions
    assert_equal [status_prop_def], build_quick_add_card_via_filters(["[Type][is][no_defaults]", "[Status][is][open]"]).displayed_inherited_property_definitions
  end

  def test_displayed_inherited_property_definitions_should_resolve_all_implicit_tree_properties
    with_three_level_tree_project do |project|
      release_prop   = project.find_property_definition_or_nil('Planning release')
      iteration_prop = project.find_property_definition_or_nil('Planning iteration')
      iteration_1    = project.cards.find_by_name('iteration1')
      release_1      = project.cards.find_by_name('release1')
      type_story     = project.find_card_type('Story')

      quick_card = build_quick_add_card_via_filters(["[Type][is][Story]", "[Planning iteration][is][#{iteration_1.number}]", "[Planning release][is][#{release_1.number}]"])
      assert_equal [release_prop, iteration_prop], quick_card.displayed_inherited_property_definitions
    end
  end

  def test_displayed_inherited_property_definitions_should_include_higher_level_tree_properties_when_tree_property_is_set_by_card_default
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.first
      release_prop   = project.find_property_definition_or_nil('Planning release')
      iteration_prop = project.find_property_definition_or_nil('Planning iteration')

      iteration_1    = project.cards.find_by_name('iteration1')
      iteration_1.update_properties(release_prop.name => nil);
      iteration_1.save!
      release_1      = project.cards.find_by_name('release1')
      type_story     = project.find_card_type('Story')
      type_story.card_defaults.update_properties(iteration_prop.name => iteration_1.id)

      view = CardListView.find_or_construct(project, {})
      quick_card = QuickAddCard.new(view, :use_filters => false, :card_type_from_session => 'Story')
      displayed_prop_defs = quick_card.displayed_inherited_property_definitions

      assert_equal 2, displayed_prop_defs.size
      assert_equal [release_prop, iteration_prop], displayed_prop_defs
    end
  end

  def test_displayed_inherited_property_definitions_should_group_properties_by_tree_and_leave_tree_properties_at_the_end
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.first
      release_prop   = project.find_property_definition_or_nil('Planning release')
      iteration_prop = project.find_property_definition_or_nil('Planning iteration')

      iteration_1    = project.cards.find_by_name('iteration1')
      iteration_1.update_properties(release_prop.name => nil);
      iteration_1.save!
      release_1      = project.cards.find_by_name('release1')
      type_story     = project.find_card_type('Story')
      type_story.card_defaults.update_properties(iteration_prop.name => iteration_1.id, :status => 'open')

      view = CardListView.find_or_construct(project, {})
      quick_card = QuickAddCard.new(view, :use_filters => false, :card_type_from_session => 'Story')
      displayed_prop_defs = quick_card.displayed_inherited_property_definitions

      assert_equal ['status', 'Planning release', 'Planning iteration'], displayed_prop_defs.map(&:name)
    end
  end

  def test_displayed_inherited_property_definitions_should_not_include_tree_relationship_properties_when_tree_is_selected_even_when_not_use_filters
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.first
      release_prop   = project.find_property_definition_or_nil('Planning release')
      iteration_prop = project.find_property_definition_or_nil('Planning iteration')

      iteration_1    = project.cards.find_by_name('iteration1')
      release_1      = project.cards.find_by_name('release1')
      type_story     = project.find_card_type('Story')

      view = CardListView.find_or_construct(project, :tree_name => tree_configuration.name, :excluded => ["release", "iteration"],
        :filters      => ["[Planning iteration][is][#{iteration_1.number}]"],
        :tf_release   => ["[Planning release][is][#{release_1.number}]"],
        :tf_iteration => ["[Planning iteration][is][#{iteration_1.number}]"])
      quick_card = QuickAddCard.new(view, :use_filters => false, :card_type_from_session => 'Story')
      displayed_prop_defs = quick_card.displayed_inherited_property_definitions

      assert_equal [], displayed_prop_defs
    end
  end

  def test_displayed_inherited_property_definitions_do_not_include_duplicate_tree_relationship_properties_when_tree_is_selected_and_when_used_in_filters
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.first
      release_prop   = project.find_property_definition_or_nil('Planning release')
      iteration_prop = project.find_property_definition_or_nil('Planning iteration')
      iteration_1    = project.cards.find_by_name('iteration1')
      release_1      = project.cards.find_by_name('release1')
      type_story     = project.find_card_type('Story')

      view = CardListView.find_or_construct(project, :tree_name => tree_configuration.name, :excluded => ["release", "iteration"],
        :filters      => ["[Planning iteration][is][#{iteration_1.number}]"],
        :tf_release   => ["[Planning release][is][#{release_1.number}]"],
        :tf_iteration => ["[Planning iteration][is][#{iteration_1.number}]"])
      quick_card = QuickAddCard.new(view, :use_filters => true)
      displayed_prop_defs = quick_card.displayed_inherited_property_definitions

      assert_equal 2, displayed_prop_defs.size
      assert_equal [release_prop, iteration_prop], displayed_prop_defs
    end
  end

  def test_displayed_inherited_property_definitions_should_only_show_tree_properties_that_apply_to_card_when_tree_selected
    with_three_level_tree_project do |project|
      configuration  = project.tree_configurations.first
      release_prop   = project.find_property_definition('Planning release')
      iteration_prop = project.find_property_definition('Planning iteration')

      view = CardListView.find_or_construct(project, :tree_name => configuration.name, :excluded => ["release"])
      displayed_prop_defs = QuickAddCard.new(view, :use_filters => true).displayed_inherited_property_definitions

      assert_equal 1, displayed_prop_defs.size
      assert_false displayed_prop_defs.include?(iteration_prop)
      assert_equal [release_prop], displayed_prop_defs
    end
  end

  def test_displayed_inherited_property_definitions_should_not_show_tree_properties_when_tree_selected_if_not_using_filters
    with_three_level_tree_project do |project|
      configuration  = project.tree_configurations.first
      release_1      = project.cards.find_by_name('release1')
      iteration_1    = project.cards.find_by_name('iteration1')

      view = CardListView.find_or_construct(project, :tree_name => configuration.name, :excluded => ["release", "iteration"],
        :filters      => ["[Planning iteration][is][#{iteration_1.number}]"],
        :tf_release   => ["[Planning release][is][#{release_1.number}]"],
        :tf_iteration => ["[Planning iteration][is][#{iteration_1.number}]"])
      displayed_prop_defs = QuickAddCard.new(view, :use_filters => false).displayed_inherited_property_definitions
      assert displayed_prop_defs.empty?
    end
  end

  def test_implicit_tree_properties_from_filter_should_override_card_default
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
      iteration_1 = project.cards.find_by_name('iteration1')
      release_1 = project.cards.find_by_name('release1')
      release_2 = tree_configuration.add_child(create_card!(:name => 'release2', :card_type => type_release), :to => :root)
      type_story = project.find_card_type('Story')

      type_story.card_defaults.update_properties('Planning iteration' => iteration_1.id)
      card = build_quick_add_card_via_filters(["[Type][is][Story]", "[Planning release][is][#{release_2.number}]"]).card
      assert_equal release_2.number_and_name, card.cp_planning_release.number_and_name
      assert_nil card.cp_planning_iteration
    end
  end

  def test_should_set_user_properties_based_on_filters_for_not_set
    @project.find_property_definition('dev').card_types = [@type_bug]
    @project.reload
    @type_bug.card_defaults.update_properties(:dev => User.find_by_login('bob').id)
    assert_nil build_quick_add_card_via_filters(["[Type][is][bug]", "[dev][is][]"]).card.cp_dev
  end

  def test_should_set_date_properties_based_on_filters
    @project.find_property_definition('start date').card_types = [@type_bug]
    @project.reload
    @type_bug.card_defaults.update_properties('start date' => '04 Feb 2012')
    filter_date = Date.new(2012, 02, 03)

    assert_equal filter_date, build_quick_add_card_via_filters(["[Type][is][bug]", "[start date][is][#{filter_date}]"]).card.cp_start_date
  end

  def test_should_not_set_today_when_filtering_by_date_not_today
    @project.find_property_definition('start date').card_types = [@type_bug]
    @project.reload
    card = build_quick_add_card_via_filters(["[Type][is][bug]", "[start date][is not][(today)]"]).card
    assert_not_equal @project.today, card.cp_start_date
    assert_equal @project.today.advance(:days => -1), card.cp_start_date
  end

  def test_should_set_tree_properties_based_on_filters
    with_three_level_tree_project do |project|
      iteration_one = project.cards.find_by_name('iteration1')
      iteration_two = project.cards.find_by_name('iteration2')
      release_1 = project.cards.find_by_name('release1')
      type_story = project.find_card_type('Story')

      type_story.card_defaults.update_properties('Planning iteration' => iteration_one.id)
      card = build_quick_add_card_via_filters(["[Type][is][Story]", "[Planning iteration][is][#{iteration_two.number}]"]).card
      assert_equal iteration_two, card.cp_planning_iteration
      assert_equal release_1, card.cp_planning_release

      assert_nil build_quick_add_card_via_filters(["[Type][is][Story]", "[Planning iteration][is][]"]).card.cp_planning_iteration
    end
  end

  def test_should_set_tree_properties_based_on_filters_using_project_variables
    with_three_level_tree_project do |project|
      iteration_one = project.cards.find_by_name('iteration1')
      story_type = project.find_card_type('Story')
      iteration_type = project.find_card_type('Iteration')
      iteration_property = project.find_property_definition("planning iteration")
      create_plv!(project, :name => 'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => iteration_type, :value => iteration_one.id, :property_definition_ids => [iteration_property.id])

      assert_equal iteration_one, build_quick_add_card_via_filters(["[Type][is][Story]", "[Planning iteration][is][(current iteration)]"]).card.cp_planning_iteration
    end
  end

  def test_should_set_date_properties_based_on_filters_using_today
    @project.find_property_definition('start date').card_types = [@type_bug]
    @project.reload
    @type_bug.card_defaults.update_properties('start date' => '04 Feb 2012')
    Clock.fake_now(:year => 2011, :month => 10, :day => 9)

    assert_equal Clock.now.to_date, build_quick_add_card_via_filters(["[Type][is][bug]", "[start date][is][(today)]"]).card.cp_start_date
  end

  def test_should_set_card_relationship_properties_based_on_filters_using_project_variables
    with_three_level_tree_project do |project|
      story_type = project.card_types.find_by_name 'story'
      iteration_type = project.card_types.find_by_name 'iteration'
      iteration_one = project.cards.create!(:name => 'iteration 1',:card_type => iteration_type)
      iteration_two = project.cards.create!(:name => 'iteration 2',:card_type => iteration_type)
      defaults = story_type.card_defaults
      defaults.update_properties('related card' => iteration_one.id)
      card_property = project.find_property_definition('related card')
      create_plv(project, :name => 'some_variable', :data_type => ProjectVariable::CARD_DATA_TYPE, :value => iteration_two.id, :property_definition_ids => [card_property.id])

      quick = build_quick_add_card_via_filters(["[Type][is][Story]", "[related card][is][(some_variable)]"])
      assert_equal iteration_two, quick.card.cp_related_card
    end
  end

  def test_should_set_user_properties_based_on_filters_using_project_variables
    user_property = @project.find_property_definition('dev')
    user_property.card_types = [@type_bug]
    @type_bug.card_defaults.update_properties(:dev => User.find_by_login('member').id)
    plv_user = User.find_by_login('bob')

    create_plv(@project, :name => 'some_variable', :data_type => ProjectVariable::USER_DATA_TYPE, :value => plv_user.id, :property_definition_ids => [user_property.id])
    assert_equal plv_user, build_quick_add_card_via_filters(["[Type][is][bug]", "[dev][is][(some_variable)]"]).card.cp_dev
  end

  def test_should_not_throw_error_when_card_default_is_plv_for_user_property
    user_property = @project.find_property_definition('dev')
    user_property.card_types = [@type_bug]
    plv_user = User.find_by_login('bob')
    create_plv(@project, :name => 'bobby', :data_type => ProjectVariable::USER_DATA_TYPE, :value => plv_user.id, :property_definition_ids => [user_property.id])
    @type_bug.card_defaults.update_properties(:dev => '(bobby)')

    assert_equal plv_user, build_quick_add_card_via_filters(["[Type][is][bug]", "[dev][is not][(not set)]"]).card.cp_dev
  end

  def test_should_set_first_available_value_for_ambiguous_filter_for_enumerated_property
    priority_def = @project.find_property_definition('priority')
    priority_def.card_types = [@type_bug]
    @project.reload
    assert_equal 'low', build_quick_add_card_via_filters(["[Type][is][bug]", "[priority][is less than][high]"]).card.cp_priority
  end

  def test_should_set_first_available_value_for_multiple_accepts_filters_for_enumerated_property
    priority_def = @project.find_property_definition('priority')
    priority_def.card_types = [@type_bug]
    @project.reload
    assert_equal 'low', build_quick_add_card_via_filters(["[Type][is][bug]", "[priority][is][low]", "[priority][is][medium]", "[priority][is][high]"]).card.cp_priority
  end

  def test_should_use_card_defaults_if_it_satisfies_the_ambiguous_filter_for_enumerated_property
    priority_def = @project.find_property_definition('priority')
    priority_def.card_types = [@type_bug]
    @type_bug.card_defaults.update_properties(:priority => 'medium')

    assert_equal 'medium', build_quick_add_card_via_filters(["[Type][is][bug]", "[priority][is less than][high]"]).card.cp_priority
  end

  def test_should_choose_first_value_that_satifies_ambiguous_filter_condition_for_enumerated_property
    priority_def = @project.find_property_definition('priority')
    priority_def.card_types = [@type_bug]
    @project.reload
    assert_equal 'low', build_quick_add_card_via_filters(["[Type][is][bug]", "[priority][is less than][high]", "[priority][is greater than][(not set)]"]).card.cp_priority
  end

  def test_should_set_to_nil_if_no_value_satifies_ambiguous_filter_for_enumerated_property
    priority_def = @project.find_property_definition('priority')
    priority_def.card_types = [@type_bug]
    assert_nil build_quick_add_card_via_filters(["[Type][is][bug]", "[priority][is less than][low]", "[priority][is greater than][medium]"]).card.cp_priority
  end

  def test_should_set_first_available_value_for_ambiguous_filter_for_user_property
    user_property = @project.find_property_definition('dev')
    users = user_property.property_values
    user_property.card_types = [@type_bug]
    @project.reload
    assert_equal users.first.value, build_quick_add_card_via_filters(["[Type][is][bug]", "[dev][is not][(not set)]"]).card.cp_dev
  end

  def test_should_set_first_available_value_for_multiple_ambiguous_filters_for_user_property
    user_property = @project.find_property_definition('dev')
    users = user_property.property_values.to_a
    first_user = users.first.value
    user_property.card_types = [@type_bug]
    @project.reload
    assert_equal users.second.value, build_quick_add_card_via_filters(["[Type][is][bug]", "[dev][is not][(not set)]", "[dev][is not][#{first_user.login}]"]).card.cp_dev
  end

  def test_should_set_to_not_set_if_no_value_satisfies_ambiguous_filters_for_user_property
    user_property = @project.find_property_definition('dev')
    users = user_property.property_values.to_a
    user_property.card_types = [@type_bug]
    filters = users.collect { |user| "[dev][is not][#{user.value.login}]" }
    assert_nil build_quick_add_card_via_filters(filters).card.cp_dev
  end

  def test_should_set_to_default_value_if_default_value_satisfies_ambiguous_filter_for_user_property
    user_property = @project.find_property_definition('dev')
    users = user_property.property_values.to_a.collect(&:value)
    second_user = users.second
    user_property.card_types = [@type_bug]
    @type_bug.card_defaults.update_properties(:dev => second_user.id)
    assert_equal second_user, build_quick_add_card_via_filters(["[Type][is][bug]", "[dev][is not][(not set)]"]).card.cp_dev
  end

  def test_should_set_first_available_value_for_ambiguous_filter_for_date_property
    date_property = @project.find_property_definition('start date')
    date_property.card_types = [@type_bug]
    @project.reload
    Clock.now_is('2011-11-11') do
      filter_date = Date.new(2012, 01, 01)
      assert_equal filter_date.advance(:days => 1), build_quick_add_card_via_filters(["[Type][is][bug]", "[start date][is after][#{filter_date}]"]).card.cp_start_date
    end
  end

  def test_should_not_throw_error_when_default_value_is_not_set_for_date_property
    date_property = @project.find_property_definition('start date')
    date_property.card_types = [@type_bug]
    @type_bug.card_defaults.update_properties(:'start date' => nil)
    @project.reload
    assert_equal @project.today.advance(:days => -1), build_quick_add_card_via_filters(["[Type][is][bug]", "[start date][is not][(today)]"]).card.cp_start_date
  end

  def test_should_not_throw_error_when_default_value_is_plv_for_date_property
    date_property = @project.find_property_definition('start date')
    date_property.card_types = [@type_bug]
    date = Date.new(2012, 01, 01)
    create_plv!(@project, :name => 'Start of Iteration', :data_type => ProjectVariable::DATE_DATA_TYPE, :value => date, :property_definition_ids => [date_property.id])
    @type_bug.card_defaults.update_properties(:'start date' => '(Start of Iteration)')
    @project.reload
    assert_equal date, build_quick_add_card_via_filters(["[Type][is][bug]", "[start date][is not][(today)]"]).card.cp_start_date
  end

  def test_should_set_to_card_default_if_it_satifies_ambiguous_filter_for_date_property
    date_property = @project.find_property_definition('start date')
    date_property.card_types = [@type_bug]
    filter_date = Date.new(2012, 01, 01)
    card_default = Date.new(2011, 01, 01)
    @type_bug.card_defaults.update_properties(:'start date' => card_default)
    assert_equal card_default, build_quick_add_card_via_filters(["[Type][is][bug]", "[start date][is before][#{filter_date}]"]).card.cp_start_date
  end

  def test_should_set_to_today_if_no_card_default_and_today_satisfies_ambiguous_filter_for_date_property
    date_property = @project.find_property_definition('start date')
    date_property.card_types = [@type_bug]
    date_property.save!
    @project.reload
    Clock.now_is(:year => 2011, :month => 12, :day => 1) do |today|
      filter_date = Date.new(2012, 01, 01)
      quick_add = build_quick_add_card_via_filters(["[Type][is][bug]", "[start date][is before][#{filter_date}]"])
      assert_equal today, quick_add.card.cp_start_date
    end
  end

  def test_should_set_to_not_set_if_no_value_satifies_ambiguous_filter_for_date_property
    date_property = @project.find_property_definition('start date')
    date_property.card_types = [@type_bug]
    start_date = Date.new(2011, 01, 01)
    end_date = Date.new(2011, 01, 02)
    assert_nil build_quick_add_card_via_filters(["[Type][is][bug]", "[start date][is before][#{start_date}]", "[start date][is after][#{end_date}]"]).card.cp_start_date
  end

  def test_should_set_first_available_value_for_ambiguous_filter_for_card_property
    with_card_query_project do |project|
      card_property = project.find_property_definition('related card')
      assert_equal card_property.property_values.collect(&:value).first, build_quick_add_card_via_filters(["[Type][is][card]", "[related card][is not][(not set)]"]).card.cp_related_card
    end
  end

  def test_should_set_first_available_value_for_multiple_ambiguous_filter_for_card_property
    with_card_query_project do |project|
      card_property = project.find_property_definition('related card')
      card_type = project.card_types.find_by_name('Card')
      project.cards.create!(:name => 'card', :card_type_name => 'Card')
      values = card_property.property_values.collect(&:value)
      first_card, second_card = values.first, values.second
      assert_equal second_card, build_quick_add_card_via_filters(["[Type][is][card]", "[related card][is not][(not set)]", "[related card][is not][#{first_card.number}]"]).card.cp_related_card
    end
  end

  def test_should_set_to_card_default_value_for_ambiguous_filter_for_card_property
    with_card_query_project do |project|
      card_property = project.find_property_definition('related card')
      project.cards.create!(:name => 'card', :card_type_name => 'Card')
      second_card = card_property.property_values.collect(&:value).second
      project.card_types.find_by_name('Card').card_defaults.update_properties(:'related card' => second_card.id)

      assert_equal second_card, build_quick_add_card_via_filters(["[Type][is][card]", "[related card][is not][(not set)]"]).card.cp_related_card
    end
  end

  def test_should_set_first_available_value_for_ambiguous_filter_for_tree_property
    with_three_level_tree_project do |project|
      iteration_1 = project.cards.find_by_name('iteration1')
      assert_equal iteration_1, build_quick_add_card_via_filters(["[Type][is][Story]", "[Planning iteration][is not][(not set)]"]).card.cp_planning_iteration
    end
  end

  def test_should_set_first_available_value_for_multiple_ambiguous_filter_for_tree_property
    with_three_level_tree_project do |project|
      type_story = project.card_types.find_by_name('story')
      iteration_1 = project.cards.find_by_name('iteration1')
      iteration_2 = project.cards.find_by_name('iteration2')
      assert_equal iteration_2, build_quick_add_card_via_filters(["[Type][is][Story]", "[Planning iteration][is not][(not set)]", "[Planning iteration][is not][#{iteration_1.number}]"]).card.cp_planning_iteration
    end
  end

  def test_should_set_default_value_if_it_satisfies_the_ambiguous_filter_for_tree_property
    with_three_level_tree_project do |project|
      type_story = project.card_types.find_by_name('story')
      iteration_1 = project.cards.find_by_name('iteration1')
      iteration_2 = project.cards.find_by_name('iteration2')
      type_story.card_defaults.update_properties('planning iteration' => iteration_2.id)
      assert_equal iteration_2, build_quick_add_card_via_filters(["[Type][is][Story]", "[Planning iteration][is not][(not set)]"]).card.cp_planning_iteration
    end
  end

  def test_should_ignore_unrelated_properties_with_card_type_for_the_card
    with_three_level_tree_project do |project|
      type_bug = project.card_types.create!(:name => 'bug')
      type_iteration = project.card_types.find_by_name('iteration')
      iteration_1 = project.cards.find_by_name('iteration1')
      quick_add = build_quick_add_card_via_filters(["[Type][is][bug]"])
      quick_add.update_card_properties("Planning iteration" => "#{iteration_1.number}")

      assert_equal "bug", quick_add.card.card_type_name
      assert_nil quick_add.card.cp_planning_iteration
    end
  end

  def test_card_type_param_should_override_all_in_magic_card
    assert_equal @type_bug, build_quick_add_card_via_filters(["[Type][is][Card]"], :card => {:card_type_name => @type_bug.name }).card.card_type
  end

  def test_card_type_param_should_override_card_properties_param
    @project.card_types.create!(:name => 'story')
    assert_equal @type_bug, build_quick_add_card_via_filters(["[Type][is][Card]"], :card => {:card_type_name => "bug"}, :card_properties => {:Type => 'story'}).card.card_type
  end

  def test_card_type_should_be_set_to_first_card_type_when_no_filter_or_param_values
    assert_equal @project.card_types.first, build_quick_add_card_via_filters([]).card.card_type
  end

  def test_should_ignore_unapplicable_filters
    with_three_level_tree_project do |project|
      type_iteration = project.card_types.find_by_name('iteration')
      iteration_1 = project.cards.find_by_name('iteration1')
      card = build_quick_add_card_via_filters(["[Type][is][Story]", "[Planning iteration][is][#{iteration_1.number}]", "[status][is][open]"], :card => {:card_type_name => "iteration"}).card
      assert_equal "iteration", card.card_type_name
      assert_equal "open", card.cp_status
    end
  end

  def test_card_type_should_be_set_from_session_when_no_filter_or_param_values
    quick = build_quick_add_card_via_filters([], :card_type_from_session => "Card")
    assert_not_equal "Card", @project.card_types.first.name
    assert_equal @project.card_types.find_by_name("Card"), quick.card.card_type
  end

  def test_should_tag_card_when_filter_by_tagged_with
    view = CardListView.find_or_construct(@project, :tagged_with => 'pumpkin, skeleton')
    assert_equal ['pumpkin', 'skeleton'], QuickAddCard.new(view, :use_filters => true).card.tags.collect(&:name).sort
  end

  def test_should_use_tree_filters_to_determine_card_type_if_using_filters
    with_three_level_tree_project do |project|
      tree = project.tree_configurations.first
      view = CardListView.construct_from_params(project, :tree_name => tree.name, :excluded => ["release", "iteration"])
      assert_equal "story", QuickAddCard.new(view, :use_filters => true).card.card_type.name.downcase
    end
  end

  def test_should_apply_tree_filter_values_to_properties
    with_three_level_tree_project do |project|
      tree = project.tree_configurations.first
      view = CardListView.construct_from_params(project, :tree_name => tree.name,
                                                         :excluded     => ["release", "iteration"],
                                                         :tf_release   => [],
                                                         :tf_iteration => ["[status][is][open]"],
                                                         :tf_story     => ["[size][is][1]"])

      card = QuickAddCard.new(view, :use_filters => true).card
      assert_equal "1", card.cp_size
      assert_nil card.cp_status
    end
  end

  def test_should_apply_tree_filter_values_to_card_relationship_properties
    with_three_level_tree_project do |project|
      tree = project.tree_configurations.first

      iteration_type = project.card_types.find_by_name 'iteration'
      iteration_two = project.cards.create!(:name => 'iteration 2',:card_type => iteration_type)
      release1 = project.cards.find_by_name("release1")

      view = CardListView.construct_from_params(project, :tree_name => tree.name,
                                                         :excluded     => ["release", "iteration"],
                                                         :tf_release   => ["[planning release][is][#{release1.number}]"],
                                                         :tf_iteration => ["[status][is][open]"],
                                                         :tf_story     => ["[size][is][1]", "[related card][is][#{iteration_two.number}]"])
      card = QuickAddCard.new(view, :use_filters => true).card
      assert_equal "1", card.cp_size
      assert_equal iteration_two, card.cp_related_card
      assert_equal release1, card.cp_planning_release
      assert_nil card.cp_status
    end
  end

  def test_should_apply_tree_filter_values_to_tree_relationship_properties
    with_three_level_tree_project do |project|
      tree = project.tree_configurations.first
      iteration_type = project.card_types.find_by_name 'iteration'
      iteration_two = project.cards.create!(:name => 'iteration 2',:card_type => iteration_type)

      view = CardListView.construct_from_params(project, :tree_name => tree.name,
                                                         :excluded     => ["release", "iteration"],
                                                         :tf_release   => [],
                                                         :tf_iteration => ["[planning iteration][is][#{iteration_two.number}]"],
                                                         :tf_story     => [])
      assert_equal iteration_two, QuickAddCard.new(view, :use_filters => true).card.cp_planning_iteration
    end
  end

  def test_should_apply_ambiguous_tree_filter_values_when_tree_selected
    with_three_level_tree_project do |project|
      tree = project.tree_configurations.first
      iteration_type = project.card_types.find_by_name 'iteration'
      iteration_one  = project.cards.find_by_name('iteration1')
      iteration_two  = project.cards.find_by_name('iteration2')

      view = CardListView.construct_from_params(project, :tree_name => tree.name,
                                                         :excluded     => ["release", "iteration"],
                                                         :tf_release   => [],
                                                         :tf_iteration => ["[planning iteration][is][#{iteration_one.number}]", "[planning iteration][is][#{iteration_two.number}]"],
                                                         :tf_story     => [])
      assert_equal iteration_one, QuickAddCard.new(view, :use_filters => true).card.cp_planning_iteration

      view = CardListView.construct_from_params(project, :tree_name => tree.name,
                                                         :excluded     => ["release", "iteration"],
                                                         :tf_release   => [],
                                                         :tf_iteration => ["[planning iteration][is not][#{iteration_one.number}]"],
                                                         :tf_story     => [])
      assert_equal iteration_two, QuickAddCard.new(view, :use_filters => true).card.cp_planning_iteration
    end
  end

  def test_should_not_resolve_tree_relationship_values_that_are_implied_when_tree_selected
    with_three_level_tree_project do |project|
      tree = project.tree_configurations.first
      iteration_type = project.card_types.find_by_name 'iteration'
      size_prop      = project.find_property_definition("size")
      iteration_one  = project.cards.find_by_name('iteration1')
      release_one    = project.cards.find_by_name('release1')
      size_prop.card_types << iteration_type
      iteration_one.update_properties :size => 4
      iteration_one.save!
      view = CardListView.construct_from_params(project, :tree_name => tree.name,
                                                         :excluded     => ["release", "iteration"],
                                                         :tf_release   => ["[planning release][is][#{release_one.number}]"],
                                                         :tf_iteration => ["[size][is][4]"],
                                                         :tf_story     => [])
      assert_equal release_one, QuickAddCard.new(view, :use_filters => true).card.cp_planning_release
      assert_nil QuickAddCard.new(view, :use_filters => true).card.cp_planning_iteration
    end
  end

end
