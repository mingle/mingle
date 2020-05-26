# -*- coding: utf-8 -*-

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
require "rexml/document"

class PropertyDefinitionTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  def setup
    @project = first_project
    @project.activate
    @member = login_as_member
  end

  def teardown
    @project.deactivate
  end

  def test_get_card_number_as_property_definition
    assert @project.find_property_definition('number')
  end

  def test_type_should_be_predefined
    assert PropertyDefinition.predefined?(Project.card_type_definition.name)
    assert_equal Project.card_type_definition, PredefinedPropertyDefinitions.find(@project, Project.card_type_definition.name)
  end

  def test_should_limit_column_name_by_mingle_column_name_max_len
    pd = @project.all_property_definitions.create_text_list_property_definition(:name => 'the len of name is more than mingle column name max len')
    assert pd.errors.any?
    assert_equal "is too long (maximum is #{PropertyDefinition::COLUMN_NAME_MAX_LEN} characters)", pd.errors.on('name')
  end

  def test_should_not_allow_card_schema_invalid_sql_names
    (PredefinedPropertyDefinitions::TYPES.keys + ['created by', 'modified by', 'created+by', 'created-by', 'modified.by']).each do |name|
      pd = @project.all_property_definitions.create_text_list_property_definition(:name => name)
      assert pd.errors.any?, "created #{name}"
    end
  end

  def test_should_allow_names_that_are_only_different_with_underscore
    pd = @project.all_property_definitions.create_text_list_property_definition(:name => 'owner dev')
    assert pd.errors.empty?
    pd = @project.all_property_definitions.create_text_list_property_definition(:name => 'owner_dev')
    assert pd.errors.empty?

    pd = @project.all_property_definitions.create_text_list_property_definition(:name => 'owner qa')
    assert pd.errors.empty?
    pd = @project.all_property_definitions.create_text_list_property_definition(:name => 'owner_qa')
    assert pd.errors.empty?
  end

  def test_should_not_allow_square_brackets
    error_msg = "should not contain '&', '=', '#', '\"', ';', '[' and ']' characters"

    pd = @project.all_property_definitions.create_text_list_property_definition(:name => '&')
    assert_equal error_msg, pd.errors.on('name')
    pd = @project.all_property_definitions.create_text_list_property_definition(:name => '=')
    assert_equal error_msg, pd.errors.on('name')
    pd = @project.all_property_definitions.create_text_list_property_definition(:name => '[')
    assert_equal error_msg, pd.errors.on('name')
    pd = @project.all_property_definitions.create_text_list_property_definition(:name => ']')
    assert_equal error_msg, pd.errors.on('name')
    pd = @project.all_property_definitions.create_text_list_property_definition(:name => 'na[me')
    assert_equal error_msg, pd.errors.on('name')
    pd = @project.all_property_definitions.create_text_list_property_definition(:name => '[name]')
    assert_equal error_msg, pd.errors.on('name')
    pd = @project.all_property_definitions.create_text_list_property_definition(:name => 'na]me')
    assert_equal error_msg, pd.errors.on('name')
    pd = @project.all_property_definitions.create_text_list_property_definition(:name => 'Release #')
    assert_equal error_msg, pd.errors.on('name')
    pd = @project.all_property_definitions.create_text_list_property_definition(:name => 'foo"bar')
    assert_equal error_msg, pd.errors.on('name')
    pd = @project.all_property_definitions.create_text_list_property_definition(:name => 'foo;bar')
    assert_equal error_msg, pd.errors.on('name')
  end

  def test_should_not_allow_underscore_as_name
    p = @project.all_property_definitions.create_text_list_property_definition(:name => '_')
    assert p.errors.any?
    assert_equal "cannot be '_'", p.errors.on('name')
  end

  def test_should_be_invalid_ruby_name_when_user_property_name_is_blank
    pd = @project.all_property_definitions.create_user_property_definition(:name => '')
    assert pd.errors.any?
    assert_equal "can't be blank", pd.errors.on('name')

    pd = @project.all_property_definitions.create_user_property_definition(:name => nil)
    assert pd.errors.any?
    assert_equal "can't be blank", pd.errors.on('name')
  end

  def test_name_should_be_just_other_language_character
    pd_type = @project.all_property_definitions.create_text_list_property_definition(:name => '类型')
    assert pd_type.errors.empty?
    assert_equal "cp_1", pd_type.column_name
  end

  def test_auto_generate_name_should_know_exist_column_name
    with_new_project do |project|
      project.all_property_definitions.create_text_list_property_definition(:name => '2')
      assert_equal "cp_1", project.all_property_definitions.create_text_list_property_definition(:name => '类型').column_name
      assert_equal "cp_3", project.all_property_definitions.create_text_list_property_definition(:name => '优先级').column_name
    end
  end

  # Bug 3929
  def test_name_should_be_english_and_chinese_character
    with_new_project do |project|
      pd_type = project.all_property_definitions.create_text_list_property_definition(:name => 'infoq_新闻稿')
      assert pd_type.errors.empty?
      assert_equal "cp_1", pd_type.column_name
    end
  end

  def test_ruby_name_should_be_different_for_card_property_definition_or_user_definition
    with_new_project do |project|
      status = setup_text_property_definition('状态')
      owner = setup_user_definition('负责人')
      assert status.ruby_name != owner.ruby_name
    end
  end

  def test_name_should_not_be_same_with_the_tree_name
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      property = project.all_property_definitions.create_text_list_property_definition(:name => configuration.name)
      assert property.errors.any?
    end
  end

  def test_value_for_card_should_return_enum_values_value
    stage = @project.find_property_definition('stage')
    card  = create_card!(:name => 'card1', :stage => '25')
    assert_equal '25', stage.value(card)
    assert_equal stage.property_value_from_db('25'), card.property_value(stage)
  end

  def test_can_create_property_named_number_name_or_description
    with_new_project do |project|
      ['Number', 'Name', 'Description', 'Type'].each do |name|
        pd = project.all_property_definitions.create_text_list_property_definition(:name => name)
        assert pd.errors.any?, "create prop_def with name #{name} should not be allowed "
        assert_equal "#{name.bold} is a reserved property name", pd.errors.on('name')
      end
    end
  end

  def test_column_name_should_always_have_prefixed
    with_new_project do |project|
      assert_equal 'cp_status', project.all_property_definitions.create!(:name => 'Status').column_name
      assert_equal 'cp_44', project.all_property_definitions.create!(:name => '44').column_name
    end
  end

  def test_cant_create_property_with_invalid_characters_in_column_name
    assert !@project.all_property_definitions.create(:name => 'Type', :column_name => '#').valid?
  end

  def test_column_name_automatically_gets_downcased
    with_new_project do |project|
      assert_equal 'cp_blah', project.create_text_list_definition!(:name => 'BlAh').column_name
    end
  end

  def test_value?
    with_first_project do |project|
      card = create_card!(:name => 'my card', :status => 'open')
      assert project.find_property_definition('status').value?(card)
      assert !project.find_property_definition('priority').value?(card)
    end
  end

  def test_numeric?
    with_project_without_cards do |project|
      assert !project.find_property_definition('status').numeric?
      assert_sort_equal ["new", "old", "open", "fixed", "limbo", "in progress", "closed"],
        project.find_property_definition('status').non_numeric_values.collect(&:value)
    end
  end

  def test_reorder
    with_new_project do |project|
      setup_property_definitions :stage => []
      stage = project.find_property_definition('stage')
      stage1 = stage.create_enumeration_value!(:value => '1')
      stage4 = stage.create_enumeration_value!(:value => '4')
      # use different type creating to make sure the auto reorder is robust
      stage3 = EnumerationValue.new(:value => '3', :property_definition_id  => stage.id)
      stage3.save!
      stage_property_def = project.find_property_definition('stage')
      assert_equal ['1', '3', '4'], stage_property_def.reload.enumeration_values.collect(&:value)
      stage_property_def.reorder([stage3, stage1, stage4])
      assert_equal ['3', '1', '4'], stage_property_def.reload.enumeration_values.collect(&:value)
      stage_property_def.reorder([stage4.id, stage1.id, stage3.id]){|enum|enum.id}
      assert_equal ['4', '1', '3'], stage_property_def.reload.enumeration_values.collect(&:value)
    end
  end

  def test_reorder_subset_column
    with_new_project do |project|
      status = setup_property_definitions(:status => []).first
      new = status.create_enumeration_value!(:value => 'New')
      in_progress = status.create_enumeration_value!(:value => 'In progress')
      testing = status.create_enumeration_value!(:value => 'Testing')
      done = status.create_enumeration_value!(:value => 'Done')

      #make sure its in the order expected
      status.reorder([new, in_progress, testing, done])
      status.reorder([new, done, testing])
      assert_equal ['New', 'In progress', 'Done', 'Testing'], status.reload.enumeration_values.collect(&:value)
      status.reorder([done, new, testing])
      assert_equal ['In progress', 'Done', 'New', 'Testing'], status.reload.enumeration_values.collect(&:value)
      assert_equal [1, 2, 3, 4], status.reload.enumeration_values.collect(&:position)
    end
  end

  def test_validate_card
    @project.find_property_definition('status').enumeration_values.each{|ev| ev.destroy}
    card =create_card!(:name => 'first card')
    status_property_def = @project.find_property_definition('status')
    status_property_def.update_attributes(:restricted => true)

    status_property_def.update_card(card, nil)
    status_property_def.validate_card(card)
    assert_equal 0, card.errors.length

    status_property_def.update_card(card, 'new')
    status_property_def.validate_card(card)
    assert_equal 1, card.errors.length
    assert_equal "#{'Status'.bold} does not have any defined values", card.errors.full_messages[0]

    status_property_def.create_enumeration_value!(:value => 'new')
    status_property_def.create_enumeration_value!(:value => 'complete')

    card = @project.cards.find(card.id)
    status_property_def.reload.validate_card(card)
    assert_equal 0, card.errors.length

    status_property_def.update_card(card, 'old')
    status_property_def.reload.validate_card(card)
    assert_equal 1, card.errors.length
    assert_equal "#{'Status'.bold} is restricted to #{'complete'.bold} and #{'new'.bold}", card.errors.full_messages[0]
  end

  def test_color
    status_property_def = @project.find_property_definition('status')
    status_property_def.find_enumeration_value('new').update_attribute :color, '#DDD'
    status_property_def.find_enumeration_value('open').update_attribute :color, '#FFF'

    card = create_card!(:name => 'color me', :status => 'closed')
    status_property_def.update_card(card, 'new')
    assert_equal '#DDD', status_property_def.color(card)
    status_property_def.update_card(card, 'open')
    assert_equal '#FFF', status_property_def.color(card)
  end

  def test_card_count_for_enumeration_values
    with_first_project do |project|
      create_card!(:name => 'card 1', :status => 'new', :priority => 'high')
      create_card!(:name => 'card 2', :status => 'new', :priority => 'urgent')
      create_card!(:name => 'card 3', :status => 'old', :priority => 'urgent')

      status = project.find_property_definition('status')
      assert_equal 2, status.card_count_for('new')
      assert_equal 1, status.card_count_for('old')

      priority = project.find_property_definition('priority')
      assert_equal 2, priority.card_count_for('urgent')
      assert_equal 1, priority.card_count_for('high')
    end
  end

  def test_card_count_for_tree_property
    with_three_level_tree_project do |project|
      release1 = project.cards.find_by_name('release1')
      condition = CardQuery.parse("SELECT name WHERE 'Planning release'=release1")
      assert_equal 4, project.find_property_definition('Planning release').card_count_for(release1.id, condition)
    end
  end

  def test_card_count_when_project_has_no_cards
    with_new_project do |project|
      setup_property_definitions :status => ['new', 'old']
      status = project.find_property_definition('status')
      assert_equal 0, status.card_count_for('new')
      assert_equal 0, status.card_count_for('old')
    end
  end

  def test_property_definition_should_not_be_found_after_hiding
    material = @project.find_property_definition('material')
    assert !material.hidden?
    material.update_attribute(:hidden, true)
    assert material.hidden?
    assert_nil @project.reload.find_property_definition_or_nil('material')
  end


  def test_udpate_name_updates_saved_views
    with_new_project do |project|
      setup_property_definitions :feeture => ['cards', 'api'], :status => []
      grid_view = CardListView.find_or_construct(project, :tagged_with => 'rss', :filters => ['[feeture][is][api]'], :group_by => 'feeture', :color_by => 'feeture', :style => 'grid')
      grid_view.name = 'API Stories'
      grid_view.save!

      list_view = CardListView.find_or_construct(project, :sort => 'status', :columns => 'feeture, status', :style => 'list')
      list_view.name = 'API Stories 2'
      list_view.save!

      project.reload

      misspelled_property = project.find_property_definition('feeture')
      misspelled_property.update_attribute :name, 'feature'
      project.reload

      grid_view = CardListView.find_or_construct(project, :view => 'API Stories')
      assert_equal ['rss'], grid_view.tagged_with
      assert_equal(['[feature][is][api]'], grid_view.filters.to_params)
      assert_equal({:lane => 'feature'}, grid_view.to_params[:group_by])
      assert_equal 'feature', grid_view.to_params[:color_by]

      list_view = CardListView.find_or_construct(project, :view => 'API Stories 2')
      assert_equal 'status', list_view.sort
      assert_equal 'asc', list_view.order
    end
  end

  def test_should_be_able_to_tell_cards_count_usage
    material = @project.reload.find_property_definition('material')
    create_card!(:name => "first card", :material => 'gold')
    create_card!(:name => "second card", :material => 'sand')
    assert_equal 2, material.card_count
    dev = @project.reload.find_property_definition('dev')
    create_card!(:name => 'third card', :dev => User.find_by_login("first").id)
    assert_equal 1, dev.card_count
  end

  def test_should_be_able_to_tell_transition_usage
    with_new_project do |project|
      setup_property_definitions :material => ['gold', 'mud']
      setup_user_definition 'developer'
      project.add_member(User.find_by_login('first'))
      developer = project.reload.find_property_definition('developer')
      material = project.reload.find_property_definition('material')
      create_transition(project, "make golden", :set_properties => {:material => 'gold'})
      create_transition(project, "make it disappear", :set_properties => {:material => nil })
      create_transition(project, "gift to first user", :required_properties => {:material => 'gold'}, :set_properties => {:developer => "#{project.users.first.id}"})
      assert_equal 3, material.transitions.size
      assert_equal 1, developer.transitions.size
    end
  end

  def test_find_all_should_return_hidden_properties_in_project_scope
    with_new_project do |project|
      setup_property_definitions :status => [], :iteration => []
      project.find_property_definition('status').update_attributes(:hidden => true)
      project.all_property_definitions.reload
      project.reload
      assert_equal 1, project.property_definitions.size
      assert_equal 2, project.property_definitions_with_hidden.size
      assert !project.property_definitions_with_hidden.collect(&:name).include?('material')
    end
  end

  def test_name_and_descriptions_should_be_stripped_once_written
    with_new_project do |project|
      setup_property_definitions :material => []
      material = project.find_property_definition('material')
      # also strips double spaces
      material.name = ' loads of  material   '
      assert_equal "loads of material", material.name
      assert_not_nil project.find_property_definition_or_nil("      loads         of material    ")
    end
  end

  def test_can_create_multiple_property_definitions_that_look_similar
    with_new_project do |project|
      project.create_text_list_definition!(:name => "story status")
      project.reload
      project.create_text_list_definition!(:name => "story_status")
      project.reload
      assert project.find_property_definition_or_nil('story status')
      assert_equal 'cp_story_status', project.find_property_definition_or_nil('story status').column_name
      assert project.find_property_definition_or_nil('story_status')
      assert_equal 'cp_story_status_1', project.find_property_definition_or_nil('story_status').column_name
    end
  end

  def test_properties_should_return_all_enumerated_values
    with_new_project do |project|
      setup_property_definitions :material => ['sand', 'gold', 'wood']
      assert_equal ['sand', 'gold', 'wood'], project.find_property_definition('material').property_values.collect(&:display_value)
    end
  end

  def test_should_not_support_inline_creating_when_restricted
    status_property_def = @project.find_property_definition('status')
    assert status_property_def.support_inline_creating?
    status_property_def.update_attributes(:restricted => true)
    assert !status_property_def.support_inline_creating?
  end

  def test_cannot_create_user_property_with_same_name_as_hidden_enum_property
    with_new_project do |project|
      owner = project.create_text_list_definition!(:name => 'owner')
      owner.update_attribute(:hidden, true)
      prop_def = project.property_definitions_with_hidden.create_user_property_definition(:name => 'owner')
      assert_equal ["Name has already been taken"], prop_def.errors.full_messages
    end
  end

  def test_cannot_rename_user_property_to_name_of_hidden_enum
    with_new_project do |project|
      owner = project.create_text_list_definition!(:name => 'owner')
      owner.update_attribute(:hidden, true)
      prop_def = project.property_definitions_with_hidden.create_user_property_definition(:name => 'developer')
      assert prop_def.errors.empty?
      prop_def.update_attributes(:name => 'owner')
      assert_equal ["Name has already been taken"], prop_def.errors.full_messages
    end
  end

  def test_only_see_one_error_when_creating_property_with_duplicate_name
    with_new_project do |project|
      owner = project.create_text_list_definition!(:name => 'owner')
      prop_def = project.property_definitions_with_hidden.create_text_list_property_definition(:name => 'owner')
      assert_equal ["Name has already been taken"], prop_def.errors.full_messages
    end
  end

  def test_destroy_enum_prop_def_after_created_it
    with_new_project do |project|
      setup_property_definitions :status => ['new', 'open', 'close']

      status = project.find_property_definition :status
      status.destroy

      project.reload

      assert_equal 0, project.property_definitions_with_hidden.size
      assert_equal 0, EnumerationValue.find_all_by_property_definition_id(status.id).size
      assert !Card.column_names.include?(status.column_name)
      assert !Card::Version.column_names.include?(status.column_name)
    end
  end

  def test_destroy_user_prop_def_after_created_it
    first_user = User.find_by_login('first')
    create_project(:users => [first_user]) do |project|
      setup_user_definition 'dev'

      status = project.find_property_definition :dev
      status.destroy

      project.reload

      assert_equal 0, project.property_definitions_with_hidden.size
      assert_equal [first_user], project.users

      assert !Card.column_names.include?(status.column_name)
      assert !Card::Version.column_names.include?(status.column_name)
    end
  end

  def test_should_have_locking_available_only_for_finite_valued_property_definitions
    assert EnumeratedPropertyDefinition.new(:name => 'status').lockable?
    assert !UserPropertyDefinition.new(:name => 'dev').lockable?
    assert !TextPropertyDefinition.new(:name => 'id').lockable?
    assert !DatePropertyDefinition.new(:name => 'started on').lockable?
  end

  def test_aliased_card_types_assignment_works
    release =  @project.find_property_definition('release')
    story = @project.card_types.create!(:name => 'story')
    bug = @project.card_types.create!(:name => 'bug')
    release.card_types = [story, bug]
    @project.reload
    assert_equal ['bug', 'story'], release.reload.card_types.collect(&:name).sort
  end

  def test_not_applicable_values_removed_when_card_types_deleted
    story = @project.card_types.create!(:name => 'story')
    bug = @project.card_types.create!(:name => 'bug')
    issue = @project.card_types.create!(:name => 'issue')
    assert_not_applicable_values_removed_when_card_types_deleted([story, bug, issue], [story])
    assert_not_applicable_values_removed_when_card_types_deleted([story, bug], [])
    assert_not_applicable_values_removed_when_card_types_deleted([story, bug, issue], [story, bug])
    assert_not_applicable_values_removed_when_card_types_deleted([story], [])
  end

  def assert_not_applicable_values_removed_when_card_types_deleted(initial_card_types, new_card_types)
    @project.reload
    release =  @project.find_property_definition('release')
    release.card_types = initial_card_types
    def release.remove_not_applicable_card_values(*args)
      @values_removed = true
    end
    release.card_types = new_card_types
    assert release.instance_variable_get(:@values_removed)
  end

  def test_not_applicable_values_not_removed_when_card_types_not_deleted
    story = @project.card_types.create!(:name => 'story')
    bug = @project.card_types.create!(:name => 'bug')
    issue = @project.card_types.create!(:name => 'issue')
    assert_not_applicable_values_not_removed_when_card_types_not_deleted([],[])
    assert_not_applicable_values_not_removed_when_card_types_not_deleted([story],[story])
    assert_not_applicable_values_not_removed_when_card_types_not_deleted([story],[story, bug])
    assert_not_applicable_values_not_removed_when_card_types_not_deleted([story, bug],[story, bug])
    assert_not_applicable_values_not_removed_when_card_types_not_deleted([story, bug],[story, bug, issue])
  end

  def assert_not_applicable_values_not_removed_when_card_types_not_deleted(initial_card_types, new_card_types)
    @project.reload
    release =  @project.find_property_definition('release')
    release.card_types = initial_card_types
    def release.remove_not_applicable_card_values(*args)
      fail("should not remove not applicable values")
    end
    release.card_types = new_card_types
  end

  def test_read_only_team_member_should_not_be_able_to_add_new_value
    status = @project.find_property_definition('status')
    read_only_user = create_user! :login => 'readonly'
    @project.add_member(read_only_user, :readonly_member)
    login('readonly')
    assert_false status.support_inline_creating?
  end

  def test_project_admin_should_be_able_to_add_new_value_when_the_property_definition_was_locked
    status = @project.find_property_definition('status')
    status.update_attribute(:restricted, true)
    assert !status.support_inline_creating?
    login_as_proj_admin
    assert status.support_inline_creating?
    card = create_card!(:name => 'I am card')
    status.update_card(card, 'new status value')
    card.save!
    assert_equal 'new status value', card.reload.cp_status
  end

  def test_empty_history_subscription_should_not_prevent_property_defintion_rename_from_succeeding
    with_new_project do |project|
      setup_property_definitions :Material => ['gold', 'mud'], :Iteration => ['1', '2'], :Status => ['fixed', 'closed']
      input_params = HistoryFilterParams.new({})
      project.add_member(User.find_by_login('first'))
      history_subscription = project.create_history_subscription(project.users.first, input_params.serialize)
      status = project.find_property_definition('Status')
      status.name = 'Steve'
      status.save!
      assert project.find_property_definition('Steve')
    end
  end

  def test_history_subscriptions_should_be_updated_when_property_is_renamed
    with_new_project do |project|
      setup_property_definitions :Material => ['gold', 'mud'], :Iteration => ['1', '2'], :Status => ['fixed', 'closed']
      hash_params = {'involved_filter_properties' => {'Material' => 'gold', 'Status' => 'fixed',  'Iteration' => '1'},
                     'acquired_filter_properties' => {'Material' => 'mud',  'Status' => 'closed', 'Iteration' => '2'},
                     'involved_filter_tags' => 'apple',
                     'acquired_filter_tags' => 'orange'}
      input_params = HistoryFilterParams.new(hash_params)
      project.add_member(User.find_by_login('first'))
      history_subscription = project.create_history_subscription(project.users.first, input_params.serialize)
      status = project.find_property_definition('Status')
      status.name = 'Steve'
      status.save!

      history_subscription.reload
      params = history_subscription.to_history_filter_params
      # verify that Status params were renamed to Steve
      assert_equal 'fixed', params.involved_filter_properties['Steve']
      assert_equal 'closed', params.acquired_filter_properties['Steve']
      # verify that all other params were not messed up.
      assert_equal 'gold', params.involved_filter_properties['Material']
      assert_equal '1', params.involved_filter_properties['Iteration']
      assert_equal 'mud', params.acquired_filter_properties['Material']
      assert_equal '2', params.acquired_filter_properties['Iteration']
      assert_equal ['apple'], params.involved_filter_tags
      assert_equal ['orange'], params.acquired_filter_tags
    end
  end

  def test_history_subscriptions_should_be_removed_when_property_is_removed
    with_new_project do |project|
      setup_property_definitions :Status => ['fixed', 'closed']
      project.add_member(User.find_by_login('first'))
      involved_history_subscription = project.create_history_subscription(project.users.first, 'involved_filter_properties[Status]=fixed')
      acquired_history_subscription = project.create_history_subscription(project.users.first, 'acquired_filter_properties[Status]=closed')
      assert project.history_subscriptions.any? {|history_subscription| history_subscription == involved_history_subscription}
      assert project.history_subscriptions.any? {|history_subscription| history_subscription == acquired_history_subscription}
      status = project.find_property_definition('Status')
      status.destroy

      assert !project.history_subscriptions.any? {|history_subscription| history_subscription == involved_history_subscription}
      assert !project.history_subscriptions.any? {|history_subscription| history_subscription == acquired_history_subscription}
    end
  end

  # Bug 7385
  def test_history_subscriptions_should_delete_history_subscriptions_when_a_card_type_is_disassociated_with_a_property
    with_new_project do |project|
      user = User.find_by_login('first')
      project.add_member(user)
      cp_status = setup_managed_text_definition 'status', %w{open closed}
      story_type = setup_card_type(project, 'story', :properties => ['status'])

      project.create_history_subscription(user, "involved_filter_properties[Type]=story&involved_filter_properties[status]=closed")
      project.create_history_subscription(user, "acquired_filter_properties[Type]=story&acquired_filter_properties[status]=closed")

      cp_status.update_attribute :card_types, cp_status.card_types - [story_type]

      history_subscriptions = project.reload.history_subscriptions
      assert_equal 0, history_subscriptions.size
    end
  end

  def test_removing_card_types_deletes_any_transitions_using_those_card_types
    create_project.with_active_project do |project|
      setup_property_definitions(:status => ['new', 'open'])

      story = setup_card_type(project, 'story', :properties => ['status'])
      bug = setup_card_type(project, 'bug', :properties => ['status'])
      issue = setup_card_type(project, 'issue', :properties => ['status'])

      open_story = create_transition(project, 'open story', :card_type => story, :set_properties => {:status => 'open'})
      open_bug = create_transition(project, 'open bug', :card_type => bug, :set_properties => {:status => 'open'})
      open_issue = create_transition(project, 'open issue', :card_type => issue, :set_properties => {:status => 'open'})

      status = project.find_property_definition('status')
      status.card_types = [issue]
      story.save!

      assert_equal ['open issue'], project.reload.transitions.collect(&:name).sort
    end
  end

  def test_removing_card_types_also_removes_those_card_types_from_formulas_using_the_property
    create_project.with_active_project do |project|
      size = setup_numeric_property_definition('size', [1, 2, 3])
      iteration = setup_numeric_property_definition('iteration', [1, 2, 3])

      size_times_iteration = setup_formula_property_definition('size times iteration', 'size * iteration')
      unrelated = setup_formula_property_definition('unrelated', '1 + 2')

      story = setup_card_type(project, 'story', :properties => ['size', 'iteration', 'size times iteration', 'unrelated'])
      bug = setup_card_type(project, 'bug', :properties => ['size', 'iteration', 'size times iteration', 'unrelated'])
      issue = setup_card_type(project, 'issue', :properties => ['size', 'iteration', 'size times iteration', 'unrelated'])

      size.card_types = [issue]

      assert_equal ["issue"], size_times_iteration.card_types.collect(&:name)
      assert_equal ["Card", "bug", "issue", "story"], unrelated.card_types.collect(&:name).sort
    end
  end

  def test_should_not_change_the_order_of_card_type_property_when_updating_card_types_of_property_def
    create_project.with_active_project do |project|
      setup_property_definitions(:status => ['new', 'open'], :iteration => [1, 2], :release => [1, 2])

      story = setup_card_type(project, 'story', :properties => ['status', 'iteration', 'release'])

      status = project.find_property_definition('status')
      status.card_types = [story]

      story.save!

      assert_equal ['status', 'iteration', 'release'], story.reload.property_definitions.collect(&:name)
    end
  end

  def test_should_not_save_formula_if_property_definition_is_not_a_formula_type
    create_project.with_active_project do |project|
      setup_property_definitions(:status => ['new', 'open'])
      formula_definition = setup_formula_property_definition('formula', '2 + 2')

      status = project.find_property_definition('status')

      status.formula = '2 + 2'
      formula_definition.formula = '5 + 3'

      status.save!
      formula_definition.save!

      assert_nil status.reload.formula
      assert_equal '5 + 3', formula_definition.attributes['formula']
    end
  end

  def test_destroy_managed_enum_property_should_also_remove_its_card_defaults_references
    create_project.with_active_project do |project|
      status = setup_property_definitions(:status => ['new', 'open']).first
      card_type = project.card_types.first
      card_type.card_defaults.update_properties([['status', 'new']])
      status.destroy
      assert_equal [], card_type.card_defaults.actions
    end
  end

  def test_destroy_managed_numeric_property_should_also_remove_its_card_defaults_references
    create_project.with_active_project do |project|
      estimate = setup_managed_number_list_definition('estimate', [1, 2])
      card_type = project.card_types.first
      card_type.card_defaults.update_properties([['estimate', '1']])
      estimate.destroy
      assert_equal [], card_type.card_defaults.actions
    end
  end

  def test_destroy_unmanaged_numeric_property_should_also_remove_its_card_defaults_references
    create_project.with_active_project do |project|
      estimate = setup_numeric_text_property_definition('estimate')
      card_type = project.card_types.first
      card_type.card_defaults.update_properties([['estimate', 1]])
      estimate.destroy
      assert_equal [], card_type.card_defaults.actions
    end
  end

  def test_update_attributes_on_removing_card_types_should_also_remove_its_card_defaults_references
    create_project.with_active_project do |project|
      card_type = project.card_types.first
      status_property_definition = setup_property_definitions(:status => ['new']).first
      status_property_definition.card_types = [card_type]
      card_type.card_defaults.update_properties([['status', 'new']])
      status_property_definition.update_attributes(:name => 'status', :card_types => [])
      assert_equal [], status_property_definition.reload.card_types
      assert_equal [], card_type.card_defaults.actions
    end
  end

  # bug 3721
  def test_should_not_add_new_card_default_actions_on_enumerated_property_delete
    create_project.with_active_project do |project|
      setup_property_definitions(:status => ['new', 'open'], :iteration => [1, 2], :release => [1, 2])
      status = project.find_property_definition('status')
      status_id = status.id
      bug = project.card_types.create!(:name => 'bug')
      bug.property_definitions = [status]
      @card_type = project.card_types.first
      @card_type.card_defaults.update_properties([['status', 'new']])
      project.find_property_definition('status').destroy
      assert_equal [], @card_type.card_defaults.actions
      assert !bug.card_defaults.actions.any?{ |action| action.property_definition_id == status_id }
    end
  end

  def test_managable_numeric_property_definition_should_format_as_project_precision
    create_project.with_active_project do |project|
      assert_equal 2, project.precision
      setup_numeric_property_definition('size', ['2', '4.0'])
      size = project.find_property_definition('size')
      assert_raise ActiveRecord::RecordInvalid do
        EnumerationValue.create!(:property_definition => size, :value => '3.999')
      end
      assert_equal ['2', '4.0'], size.reload.enumeration_values.collect(&:value)
      card = create_card!(:name => 'I am card')
      size.update_card(card, '3.999')
      card.save!
      assert_equal ['2', '4.0'], size.reload.enumeration_values.collect(&:value)
      assert_equal '4.0', card.reload.cp_size
      EnumerationValue.create!(:property_definition => size, :value => '3.99')
      assert_equal ['2', '3.99', '4.0'], size.reload.enumeration_values.collect(&:value).sort
      EnumerationValue.create!(:property_definition => size, :value => '7.999')
      assert_equal ['2', '3.99', '4.0', '8.00'], size.reload.enumeration_values.collect(&:value).sort
    end
  end

  def test_find_numeric_property_definition_value_should_format_by_precision
      create_project.with_active_project do |project|
        setup_numeric_property_definition('size', ['3', '4.0', '9.99'])
        size = project.find_property_definition('size')
        assert_equal '3', size.find_enumeration_value('2.999').value
        assert_equal nil, size.find_enumeration_value('9.999')
      end
  end

  def test_changed
    with_new_project do |project|
      login_as_member
      setup_property_definitions :status => ['new', 'old']
      status = project.find_property_definition('status')

      card1 = create_card!(:name => 'card one')
      card2 = create_card!(:name => 'card two')

      status.update_card(card1, 'old')
      status.update_card(card2, 'new')
      card1.save!
      card2.save!

      assert status.different?(card1, card2)

      status.update_card(card2, 'old')
      card2.save!

      assert !status.different?(card1, card2)
    end
  end

  def test_should_delete_project_variable_related_after_destroy
    with_new_project do |project|
      pd = setup_text_property_definition('owner dev')
      create_plv!(project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => 'wpc', :property_definition_ids =>[ pd.id ] )
      assert !VariableBinding.find_all_by_property_definition_id(pd.id).empty?
      pd.destroy
      assert VariableBinding.find_all_by_property_definition_id(pd.id).empty?
    end
  end

  def test_cannot_change_card_types_on_a_property_if_they_make_aggregate_invalid
    with_new_project do |project|
      tree_config = project.tree_configurations.create!(:name => 'Planning')
      type_release, type_iteration, type_story = init_planning_tree_types
      tree_config.update_card_types({
        type_release => {:position => 0, :relationship_name => 'release'},
        type_iteration => {:position => 1, :relationship_name => 'iteration'},
        type_story => {:position => 2}
      })

      size = setup_numeric_text_property_definition('size')
      size.card_types = [type_story]
      size.save!

      some_agg = setup_aggregate_property_definition('some agg',
                                                      AggregateType::SUM,
                                                      size,
                                                      tree_config.id,
                                                      type_iteration.id,
                                                      type_story)

      assert_raise(RuntimeError) do
        size.card_types = [type_release]
      end
    end
  end

  def test_renaming_property_will_rename_it_in_aggregate_mql_condition
    with_new_project do |project|
      tree_config = project.tree_configurations.create!(:name => 'Planning')
      type_release, type_iteration, type_story = init_planning_tree_types
      tree_config.update_card_types({
        type_release => {:position => 0, :relationship_name => 'release'},
        type_iteration => {:position => 1, :relationship_name => 'iteration'},
        type_story => {:position => 2}
      })

      size = setup_numeric_text_property_definition('size')
      size.card_types = [type_story]
      size.save!

      some_agg = setup_aggregate_property_definition('count of stories',
                                                      AggregateType::COUNT,
                                                      nil,
                                                      tree_config.id,
                                                      type_release.id,
                                                      type_story)

      some_agg.aggregate_condition = "size > 3"
      some_agg.save!
      project.all_property_definitions.reload

      size.name = 'tengu'
      size.save!

      assert_equal "tengu > 3", some_agg.reload.aggregate_condition
    end
  end

  def test_renaming_property_will_not_rename_usage_in_invalid_mql_condition
    with_new_project do |project|
      tree_config = project.tree_configurations.create!(:name => 'Planning')
      type_release, type_iteration, type_story = init_planning_tree_types
      tree_config.update_card_types({
        type_release => {:position => 0, :relationship_name => 'release'},
        type_iteration => {:position => 1, :relationship_name => 'iteration'},
        type_story => {:position => 2}
      })

      size = setup_numeric_text_property_definition('size')
      size.card_types = [type_story]
      size.save!

      width = setup_numeric_text_property_definition('width')
      width.card_types = [type_story]
      width.save!

      some_agg = setup_aggregate_property_definition('count of stories',
                                                      AggregateType::COUNT,
                                                      nil,
                                                      tree_config.id,
                                                      type_release.id,
                                                      type_story)

      some_agg.aggregate_condition = "size > 3 AND width = 4"
      some_agg.save!
      project.all_property_definitions.reload

      width.destroy
      size.name = 'tengu'
      size.save!

      assert_equal "size > 3 AND width = 4", some_agg.reload.aggregate_condition
    end
  end

  def test_support_filter_returns_true_for_the_following_property_definitions
    [EnumeratedPropertyDefinition.new, UserPropertyDefinition.new].each do |definition|
      assert_equal true, definition.support_filter?
    end
  end

  def test_support_filter_returns_false_for_the_following_property_definitions
    [IntegerPropertyDefinition.new, DatePropertyDefinition.new, TextPropertyDefinition.new, FormulaPropertyDefinition.new, AggregatePropertyDefinition.new, CardPropertyDefinition.new, CardRelationshipPropertyDefinition.new, TreeRelationshipPropertyDefinition.new].each do |definition|
      assert_equal false, definition.support_filter?
    end
  end

  def test_label_value_for_charting_for_user_property
    user_prop_def = UserPropertyDefinition.new(:project => @project)
    assert_nil user_prop_def.label_value_for_charting(nil)
    assert_equal @member.name_and_login, user_prop_def.label_value_for_charting(@member.login)
    assert_equal @project.users.collect(&:name_and_login).sort, user_prop_def.label_values_for_charting
  end

  def test_sort_property_values
    with_first_project do |project|
      dev_prop = project.find_property_definition('dev')
      values = dev_prop.property_values.values

      assert_equal values.collect(&:db_identifier), dev_prop.sort(values.reverse).collect(&:db_identifier)
    end
  end
end
