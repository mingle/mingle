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

#Tags: bulk_update
class CardSelectionTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    login_as_member
    @project = card_selection_project
    @project.activate

    @rss_tag = @project.tags.find_or_create_by_name 'rss'
    @funky_tag = @project.tags.find_or_create_by_name 'funky'
    @cool_tag = @project.tags.find_or_create_by_name 'cool'
    @wild_tag = @project.tags.find_or_create_by_name 'wild'

    @cards = @project.cards
    @card_selection = CardSelection.new(@project.reload, @cards)
  end

  def teardown
    cleanup_repository_drivers_on_failure
    Clock.reset_fake
  end

  def test_property_definitions_only_returns_shared_properties
    with_new_project do |project|
      setup_property_definitions :shared_property => ['new', 'open'], :colour => ['blue', 'green'], :other_property => ['hello', 'goodbye']
      type_1 = project.card_types.create!(:name => 'card_type_for_card_one')
      type_2 = project.card_types.create!(:name => 'card_type_for_card_two')
      project.reload

      card_one = create_card!(:name => 'card_one')
      card_two = create_card!(:name => 'card_two')

      card_one.card_type = type_1
      card_two.card_type = type_2

      shared_property = project.find_property_definition(:shared_property)
      colour_property = project.find_property_definition(:colour)
      other_property = project.find_property_definition(:other_property)

      card_one.card_type.property_definitions = [shared_property, colour_property]
      card_two.card_type.property_definitions = [shared_property, other_property]

      card_one.save!
      card_two.save!

      card_selection = CardSelection.new(project.reload, [card_one, card_two])

      assert_equal [shared_property.name], card_selection.property_definitions.collect(&:name)
    end
  end

  def test_property_definitions_returns_smart_ordered_collection_when_not_all_cards_have_same_card_type
    with_new_project do |project|
      setup_property_definitions :prop10_name => [], :prop2_name => [], :prop12_name => []
      project.reload

      card_one = create_card!(:name => 'card_one')
      card_one.card_type.property_definitions = project.property_definitions
      card_one.save!

      bug_type = setup_card_type(project, 'Bug', :properties => [:prop10_name, :prop2_name, :prop12_name])

      card_two = create_card!(:name => 'card_two', :card_type_name => bug_type.name)
      card_two.card_type.property_definitions = project.property_definitions
      card_two.save!

      card_selection = CardSelection.new(project.reload, [card_one, card_two])

      assert_equal ['prop2_name', 'prop10_name', 'prop12_name'], card_selection.property_definitions.collect(&:name)
    end
  end

  def test_property_definitions_returns_card_type_position_ordered_collection_when_all_cards_have_same_card_type
    with_new_project do |project|
      setup_property_definitions :prop10_name => [], :prop2_name => [], :prop12_name => []
      project.reload

      prop10 = project.find_property_definition(:prop10_name)
      prop2 = project.find_property_definition(:prop2_name)
      prop12 = project.find_property_definition(:prop12_name)

      card_one = create_card!(:name => 'card_one')
      card_one.card_type.property_definitions = [prop10, prop2, prop12]
      card_one.save!

      card_two = create_card!(:name => 'card_two')
      card_two.card_type.property_definitions = [prop10, prop2, prop12]
      card_two.save!

      card_selection = CardSelection.new(project.reload, [card_one, card_two])

      assert_equal ['prop10_name', 'prop2_name', 'prop12_name'], card_selection.property_definitions.collect(&:name)
    end
  end

  def test_property_definitions_returns_appropriate_relationships_for_types_of_cards_selected
    with_three_level_tree_project do |project|
      release_type, iteration_type, story_type = find_planning_tree_types

      story1 = project.cards.find_by_name('story1')
      story2 = project.cards.find_by_name('story2')
      iteration2 = project.cards.find_by_name('iteration2')

      iteration_not_on_tree = project.cards.create!(:name => 'not on tree', :card_type => iteration_type)

      card_selection = CardSelection.new(project.reload, [story1, iteration_not_on_tree])
      assert_equal ["Planning release", 'status'], card_selection.property_definitions.collect(&:name).smart_sort

      card_selection = CardSelection.new(project, [story1, story2])
      assert_equal ['owner', "Planning iteration", "Planning release", 'related card', 'size', 'status'], card_selection.property_definitions.collect(&:name).smart_sort
    end
  end

  def test_should_allow_creation_of_numerically_same_values_using_bulk_edit_if_unmanaged
    with_new_project do |project|
      any_num = setup_numeric_text_property_definition('any num')
      project.cards.create!(:name => 'card one', :card_type => project.card_types.first, :cp_any_num => '2.00')
      bulk_card = project.cards.create!(:name => 'card two', :card_type => project.card_types.first)

      CardSelection.new(project.reload, [bulk_card]).update_properties('any num' => '2')
      assert_equal '2', any_num.value(bulk_card.reload)
      assert_equal ['2.00', '2'].sort, any_num.values.sort
    end
  end

  def test_empty_selection
    assert_equal 0, CardSelection.new(@project.reload, []).count
    assert !CardSelection.new(@project.reload, []).include?(@cards[0])
  end

  def test_include_should_limit_to_the_cards_selected
    @card_selection = CardSelection.new(@project, [@cards[0], @cards[1]])
    assert @card_selection.include?(@cards[0])
    assert !@card_selection.include?(@cards[2])
  end

  def test_update_for_cards_should_shrink_the_selection_according_to_collection_passed_in
    assert_equal 3, @card_selection.count
    @card_selection.update_from([@cards[0], @cards[1]])
    assert_equal 2, @card_selection.count
    assert !@card_selection.include?(@cards[2])
  end

  def test_update_from_method_will_change_selection_to_be_only_matching_cards
    create_project do |project|
      card_one = create_card!(:name => 'card one')
      card_two = create_card!(:name => 'card two')
      card_three = create_card!(:name => 'card three')
      card_four = create_card!(:name => 'card four')

      @cards = project.cards
      @card_selection = CardSelection.new(@project.reload, [card_one, card_two, card_three])

      assert_equal 3, @card_selection.count
      @card_selection.update_from([card_two, card_three, card_four])
      assert_equal 2, @card_selection.count
      assert !@card_selection.include?(card_four)
      assert !@card_selection.include?(card_one)
    end
  end

  def test_update_from_does_not_include_cards_when_no_cards_passed_in
    assert_equal @cards.size, @card_selection.count
    @card_selection.update_from([])
    assert_equal 0, @card_selection.count
  end

  def test_initial_value_for_property
    iteration = @project.find_property_definition('iteration')
    assert_equal([PropertyValue::NOT_SET, nil], @card_selection.value_for(iteration))
    @cards.each {|card| card.update_attribute(:cp_iteration, '1') }
    iteration_1  = @project.find_enumeration_value('iteration', '1')
    assert_equal(['1', '1'], @card_selection.value_for(iteration))
    @cards[0].update_attribute(:cp_iteration, '2')
    assert_equal(['(mixed value)', ':mixed_value'], @card_selection.value_for(iteration))
  end

  def test_set_properties_should_check_property_on_all_cards
    @card_selection.update_properties({'Iteration' => nil, 'Status' => 'open'})
    @cards.each{|card| assert_equal('open', card.reload.cp_status)}
    @cards.each{|card| assert_nil(card.reload.cp_iteration)}
  end

  def test_should_set_not_set_as_value_if_no_card_has_a_value_for_a_text_property
    assert_equal PropertyValue::NOT_SET, @card_selection.display_value_for(@project.find_property_definition('id'))
  end

  def test_set_properties_should_update_text_properties_without_looking_up_existing_values
    @cards[0].update_attributes('cp_id' => 'myName')
    @cards[1].update_attributes('cp_id' => 'MyName')

    @card_selection.update_properties('id' => 'Myname')
    assert_equal 'Myname', @cards[0].reload.cp_id
    assert_equal 'Myname', @cards[1].reload.cp_id

    assert_equal 'Myname', *@card_selection.value_for(@project.find_property_definition('id')).uniq
  end

  def test_should_set_dates_for_empty_date_properties
    assert_equal PropertyValue::NOT_SET, @card_selection.display_value_for(@project.find_property_definition('start date'))
    @cards[0].update_attribute(:cp_start_date, Date.parse('2007-12-10'))
    assert_equal ':mixed_value', @card_selection.value_for(@project.find_property_definition('start date')).last
  end

  def test_update_properties_should_skip_mixed_values
    @cards[0].update_attribute(:cp_iteration, '2')
    @cards[1].update_attribute(:cp_iteration, '1')
    @card_selection.update_properties({'iteration' => ':mixed_value', 'status' => 'open'})
    assert_equal('2', @cards[0].reload.cp_iteration)
    assert_equal('1', @cards[1].reload.cp_iteration)
    assert_nil(@cards[2].reload.cp_iteration)
  end

  def test_should_update_properties_correctly_even_when_property_name_case_is_wrong
    @cards[0].update_attribute(:cp_iteration, '2')
    @cards[1].update_attribute(:cp_iteration, '1')

    card_0_version_before_update = @cards[0].reload.version
    card_1_version_before_update = @cards[1].reload.version

    @card_selection.update_properties('iteration' => '2')
    @cards[0..1].each { |card| assert_equal("2", card.reload.cp_iteration) }

    assert_equal card_0_version_before_update, @cards[0].version
    assert_equal card_1_version_before_update + 1, @cards[1].version
  end

  def test_update_properties_treat_blank_value_as_nil
    @card_selection.update_properties({'Iteration' => '', 'Status' => ':mixed_value'})
    @cards.each{|card| assert_nil(card.reload.cp_iteration)}
  end

  def test_update_properties_handles_project_variables_with_unset_card_type_value
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      card_1 = project.cards.create!(:name => 'card 1', :description => "", :card_type => type_story)
      card_2 = project.cards.create!(:name => 'card 2', :description => "", :card_type => type_iteration)

      pd = project.find_property_definition('planning iteration')
      plv = create_plv!(project, :name => 'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_iteration, :property_definition_ids =>[pd.id])
      plv.save!
      pd.reload

      card_1.update_properties(pd => card_2.id)
      assert_equal card_2, card_1.property_value(pd).value

      CardSelection.new(project, [card_1]).update_property(pd.name, plv.display_name)
      card_1.reload

      assert_nil card_1.property_value(pd).value
    end
  end

  def test_update_properties_can_handle_empty_property_list
    @card_selection.update_properties({})
    assert_equal 0, @card_selection.errors.size
  end

  def test_update_properties_works_when_view_is_passed_in
    status_property = @project.property_definitions.detect{|pd|pd.name == 'Status'}
    @project.cards.each {|card| status_property.update_card(card, 'open')}

    params = {:project_id => @project.identifier, :all_cards_selected => "true", :selected_cards => "1", :action => "bulk_set_properties",
              :controller => "cards", :properties => {"status"=>"open", "Type"=>"Card"}, :page => "1"}
    @view = CardListView.find_or_construct(@project, params)

    @card_selection = CardSelection.new(@project, @view)
    @card_selection.update_properties({'Status' => 'closed'})

    cards = @view.cards
    assert_equal ['closed'], cards.collect(&:cp_status).uniq
  end

  def test_update_properties_works_properly_with_formula_properties
    with_new_project do |project|
      setup_numeric_text_property_definition('release')
      next_release = setup_formula_property_definition('next release', 'release + 1')

      card_1 = create_card!(:name => 'card one', :card_type => project.card_types.first, :release => '1')

      @card_selection = CardSelection.new(project, [card_1])
      @card_selection.update_properties('release' => '3')

      assert_equal 4, next_release.value(card_1.reload)
      assert_equal 2, card_1.version
      assert_equal 4, next_release.value(card_1.versions.last)
    end
  end

  # bug 3709
  def test_update_properties_does_not_update_formula_columns_for_cards_not_of_valid_type
    with_new_project do |project|
      release = setup_numeric_text_property_definition('release')
      next_release = setup_formula_property_definition('next release', 'release + 1')
      prev_release = setup_formula_property_definition('prev release', 'release - 1')

      type_story = project.card_types.create!(:name => "stor'y")
      type_story.property_definitions = [release, next_release]
      type_defect = project.card_types.create!(:name => 'defect')
      type_defect.property_definitions = [release, prev_release]

      story1 = project.cards.create!(:name => 'story1', :card_type => type_story)
      defect1 = project.cards.create!(:name => 'defect1', :card_type => type_defect)

      @card_selection = CardSelection.new(project, [story1, defect1])
      @card_selection.update_properties('release' => '3')

      assert_equal 4, next_release.value(story1.reload.versions.last)
      assert_nil prev_release.value(story1.versions.last)
      assert_nil next_release.value(defect1.reload.versions.last)
      assert_equal 2, prev_release.value(defect1.versions.last)

      assert_equal 4, next_release.value(story1)
      assert_nil next_release.value(defect1)
      assert_nil prev_release.value(story1)
      assert_equal 2, prev_release.value(defect1)
    end
  end

  # Bug 7608
  def test_update_should_allow_managed_numeric_properties_used_in_formulas_to_be_not_set
    with_new_project do |project|
      setup_managed_number_list_definitions 'number1' => [1, 2, 3], 'number2' => [1, 2, 3]
      setup_formula_property_definition 'number1_minus_number2', 'number1 - number2'

      card_no_numbers_set                      = project.cards.create!(:name => 'card_no_numbers_set',                      :card_type_name => 'Card')
      card_only_number1_set                    = project.cards.create!(:name => 'card_only_number1_set',                    :card_type_name => 'Card', :cp_number1 => '2')
      card_only_number2_set                    = project.cards.create!(:name => 'card_only_number2_set',                    :card_type_name => 'Card',                     :cp_number2 => '2')
      card_both_number1_and_number2_set_first  = project.cards.create!(:name => 'card_both_number1_and_number2_set_first',  :card_type_name => 'Card', :cp_number1 => '2', :cp_number2 => '2')
      card_both_number1_and_number2_set_second = project.cards.create!(:name => 'card_both_number1_and_number2_set_second', :card_type_name => 'Card', :cp_number1 => '2', :cp_number2 => '2')

      card_selection = CardSelection.new(project, [card_no_numbers_set, card_only_number1_set, card_both_number1_and_number2_set_first])
      card_selection.update_property('number1', '')

      assert_nil card_no_numbers_set.reload.cp_number1
      assert_nil card_no_numbers_set.cp_number1_minus_number2
      assert_nil card_only_number1_set.reload.cp_number1
      assert_nil card_only_number1_set.cp_number1_minus_number2
      assert_nil card_both_number1_and_number2_set_first.reload.cp_number1
      assert_nil card_both_number1_and_number2_set_first.cp_number1_minus_number2

      card_selection = CardSelection.new(project, [card_no_numbers_set, card_only_number2_set, card_both_number1_and_number2_set_second])
      card_selection.update_property('number2', '')

      assert_nil card_no_numbers_set.reload.cp_number2
      assert_nil card_no_numbers_set.cp_number1_minus_number2
      assert_nil card_only_number2_set.reload.cp_number2
      assert_nil card_only_number2_set.cp_number1_minus_number2
      assert_nil card_both_number1_and_number2_set_second.reload.cp_number2
      assert_nil card_both_number1_and_number2_set_second.cp_number1_minus_number2
    end
  end

  # Bug 7608
  def test_update_should_allow_unmanaged_numeric_properties_used_in_formulas_to_be_not_set
    with_new_project do |project|
      setup_allow_any_number_property_definitions 'anynumber1', 'anynumber2'
      setup_formula_property_definition 'anynumber1_minus_anynumber2', 'anynumber1 - anynumber2'

      card_no_numbers_set                            = project.cards.create!(:name => 'card_no_numbers_set',                            :card_type_name => 'Card')
      card_only_anynumber1_set                       = project.cards.create!(:name => 'card_only_anynumber1_set',                       :card_type_name => 'Card', :cp_anynumber1 => '2')
      card_only_anynumber2_set                       = project.cards.create!(:name => 'card_only_anynumber2_set',                       :card_type_name => 'Card',                        :cp_anynumber2 => '2')
      card_both_anynumber1_and_anynumber2_set_first  = project.cards.create!(:name => 'card_both_anynumber1_and_anynumber2_set_first',  :card_type_name => 'Card', :cp_anynumber1 => '2', :cp_anynumber2 => '2')
      card_both_anynumber1_and_anynumber2_set_second = project.cards.create!(:name => 'card_both_anynumber1_and_anynumber2_set_second', :card_type_name => 'Card', :cp_anynumber1 => '2', :cp_anynumber2 => '2')

      card_selection = CardSelection.new(project, [card_no_numbers_set, card_only_anynumber1_set, card_both_anynumber1_and_anynumber2_set_first])
      card_selection.update_property('anynumber1', '')

      assert_nil card_no_numbers_set.reload.cp_anynumber1
      assert_nil card_no_numbers_set.cp_anynumber1_minus_anynumber2
      assert_nil card_only_anynumber1_set.reload.cp_anynumber1
      assert_nil card_only_anynumber1_set.cp_anynumber1_minus_anynumber2
      assert_nil card_both_anynumber1_and_anynumber2_set_first.reload.cp_anynumber1
      assert_nil card_both_anynumber1_and_anynumber2_set_first.cp_anynumber1_minus_anynumber2

      card_selection = CardSelection.new(project, [card_no_numbers_set, card_only_anynumber2_set, card_both_anynumber1_and_anynumber2_set_second])
      card_selection.update_property('anynumber2', '')

      assert_nil card_no_numbers_set.reload.cp_anynumber2
      assert_nil card_no_numbers_set.cp_anynumber1_minus_anynumber2
      assert_nil card_only_anynumber2_set.reload.cp_anynumber2
      assert_nil card_only_anynumber2_set.cp_anynumber1_minus_anynumber2
      assert_nil card_both_anynumber1_and_anynumber2_set_second.reload.cp_anynumber2
      assert_nil card_both_anynumber1_and_anynumber2_set_second.cp_anynumber1_minus_anynumber2
    end
  end

  # Bug 7608
  def test_update_should_allow_dates_used_in_formulas_to_be_not_set
    with_new_project do |project|
      setup_date_property_definitions 'date1', 'date2'
      setup_formula_property_definition 'date1_minus_date2', 'date1 - date2'

      card_no_dates_set                    = project.cards.create!(:name => 'card_no_dates_set',                    :card_type_name => 'Card')
      card_only_date1_set                  = project.cards.create!(:name => 'card_only_date1_set',                  :card_type_name => 'Card', :cp_date1 => '2009-08-03')
      card_only_date2_set                  = project.cards.create!(:name => 'card_only_date2_set',                  :card_type_name => 'Card',                            :cp_date2 => '2009-08-02')
      card_both_date1_and_date2_set_first  = project.cards.create!(:name => 'card_both_date1_and_date2_set_first',  :card_type_name => 'Card', :cp_date1 => '2009-08-03', :cp_date2 => '2009-08-02')
      card_both_date1_and_date2_set_second = project.cards.create!(:name => 'card_both_date1_and_date2_set_second', :card_type_name => 'Card', :cp_date1 => '2009-08-03', :cp_date2 => '2009-08-02')

      card_selection = CardSelection.new(project, [card_no_dates_set, card_only_date1_set, card_both_date1_and_date2_set_first])
      card_selection.update_property('date1', '')

      assert_nil card_no_dates_set.reload.cp_date1
      assert_nil card_no_dates_set.cp_date1_minus_date2
      assert_nil card_only_date1_set.reload.cp_date1
      assert_nil card_only_date1_set.cp_date1_minus_date2
      assert_nil card_both_date1_and_date2_set_first.reload.cp_date1
      assert_nil card_both_date1_and_date2_set_first.cp_date1_minus_date2

      card_selection = CardSelection.new(project, [card_no_dates_set, card_only_date2_set, card_both_date1_and_date2_set_second])
      card_selection.update_property('date2', '')

      assert_nil card_no_dates_set.reload.cp_date2
      assert_nil card_no_dates_set.cp_date1_minus_date2
      assert_nil card_only_date2_set.reload.cp_date2
      assert_nil card_only_date2_set.cp_date1_minus_date2
      assert_nil card_both_date1_and_date2_set_second.reload.cp_date2
      assert_nil card_both_date1_and_date2_set_second.cp_date1_minus_date2
    end
  end

  def assert_changed_fields(versioned, *field_names)
    changes = versioned.versions.reload.last.changes
    assert_equal field_names.size, changes.size
    field_names.each do |field_name|
      assert changes.any? { |change| change.field == field_name }
    end
  end

  def assert_no_changed_fields(versioned, *field_names)
    changes = versioned.versions.reload.last.changes
    field_names.each do |field_name|
      assert !changes.any? { |change| change.field == field_name }
    end
  end

  def test_update_properties_works_properly_with_formula_properties_even_after_calling_update_from
    create_project.with_active_project do |project|
      setup_numeric_text_property_definition('release')
      next_release = setup_formula_property_definition('next release', 'release + 1')

      card_1 = create_card!(:name => 'card one', :card_type => project.card_types.first, :release => '1')
      card_2 = create_card!(:name => 'card two', :card_type => project.card_types.first, :release => '1')

      @card_selection = CardSelection.new(project, [card_1, card_2])
      @card_selection.update_from([card_1])
      @card_selection.update_properties('release' => '3')

      assert_equal 4, next_release.value(card_1.reload)
      assert_equal 2, card_1.version
      assert_equal 4, next_release.value(card_1.versions.last)
    end
  end

  def test_set_multipule_property_should_create_single_event_for_card_changed
    old_version_count = @cards[0].versions.size
    @card_selection.update_properties({'Iteration' => '1', 'Status' => 'open'})
    assert_equal old_version_count + 1, @cards[0].reload.versions.size
  end

  def test_update_properties_should_update_version_for_cards
    card_1 = @project.cards[0]
    card_2 = @project.cards[1]
    @card_selection = CardSelection.new(@project, [card_1,card_2])
    @card_selection.update_properties('Status' => 'open')
    assert_equal card_1.version + 1 , @project.cards.find(card_1.id).version
    assert_equal card_2.version + 1 , @project.cards.find(card_2.id).version
  end

  def test_update_properties_should_not_change_updated_at_when_property_does_not_change
    card_1 = @project.cards[0]
    card_1.update_attributes(:cp_status => 'open')
    login_as_proj_admin
    Clock.fake_now(:year => 2008, :month => 4, :day => 5)

    original_updated_at = card_1.reload.updated_at
    original_modified_by_user_id = card_1.modified_by_user_id

    assert_equal User.find_by_email('member@email.com').id, original_modified_by_user_id

    @card_selection = CardSelection.new(@project, [card_1])
    @card_selection.update_properties('Status' => 'open')

    assert_equal original_modified_by_user_id, card_1.reload.modified_by_user_id
    assert_equal original_updated_at, card_1.reload.updated_at
  end

  def test_update_properties_should_not_update_version_for_cards_when_property_does_not_change
    card_1 = @project.cards[0]
    card_2 = @project.cards[1]

    card_1.update_properties('Status' => 'open')
    card_2.update_properties('Status' => 'closed')

    card_1.save!
    card_2.save!

    original_card_1_version = card_1.version

    @card_selection = CardSelection.new(@project, [card_1, card_2])
    @card_selection.update_properties('Status' => 'open')
    assert_equal original_card_1_version, card_1.reload.version
    assert_equal card_2.version + 1, card_2.reload.version
  end

  def test_update_properties_should_not_copy_card_into_versions_table_when_property_does_not_change
    last_value = Sequence.find('card_version_id_sequence').current

    card_1 = @project.cards[0]
    card_2 = @project.cards[1]

    card_1.update_properties('Status' => 'open')
    card_2.update_properties('Status' => 'closed')
    card_1.save!
    card_2.save!

    original_card_1_last_version_id = card_1.reload.versions.last.id
    original_card_2_last_version_id = card_2.reload.versions.last.id

    @card_selection = CardSelection.new(@project, [card_1, card_2])
    @card_selection.update_properties('Status' => 'open')

    assert_equal original_card_1_last_version_id, card_1.reload.versions.last.id
    assert_not_equal original_card_2_last_version_id, card_2.reload.versions.last.id
  end

  # bug 2303
  def test_update_properties_creates_a_version_with_the_new_card_type_name
    setup_card_type(@project, 'Bug', :properties => ['Status'])

    card_1 = @project.cards[0]
    card_1.update_properties('Status' => 'open')
    card_1.save!

    @card_selection = CardSelection.new(@project, [card_1])
    @card_selection.update_properties({'Type' => 'Bug', 'Status' => 'closed'})

    assert_equal 'closed', card_1.reload.versions.last.cp_status
    assert_equal 'Bug', card_1.reload.versions.last.card_type_name
  end

  def test_update_properties_should_increase_sequence_by_correct_value
    sequence = Sequence.find('card_version_id_sequence')
    last_value = sequence.current

    cards = [@project.cards[0], @project.cards[1]]
    @card_selection = CardSelection.new(@project, cards)
    @card_selection.update_properties('Status' => 'open')

    sequence = Sequence.find('card_version_id_sequence')
    assert_equal last_value + cards.size, sequence.current
  end

  def test_update_properties_should_generate_card_version_id_by_sequence
    last_value = Sequence.find('card_version_id_sequence').current

    card_1 = @project.cards[0]
    card_2 = @project.cards[1]
    @card_selection = CardSelection.new(@project, [card_1, card_2])
    @card_selection.update_properties('Status' => 'open')

    generated_card_version_ids = [last_value + 1, last_value + 2]
    assert generated_card_version_ids.include?(card_1.reload.versions.last.id)
    assert generated_card_version_ids.include?(card_2.reload.versions.last.id)
  end

  def test_update_properties_should_update_modified_by_user_id_and_updated_at_for_cards
    login_as_proj_admin
    Clock.fake_now(:year => 2008, :month => 4, :day => 5)
    card_1 = @project.cards[0]
    assert_equal User.find_by_email('member@email.com').id, card_1.modified_by_user_id
    @card_selection = CardSelection.new(@project, [card_1])
    @card_selection.update_properties('Status' => 'open')
    assert_equal User.current.id, card_1.reload.modified_by_user_id
    assert_equal Clock.now, card_1.reload.updated_at
  end

  def test_update_properties_should_allow_multiple_updates_without_temporary_table_staying_around
    card_1 = @project.cards[0]
    @card_selection = CardSelection.new(@project, [card_1])
    @card_selection.update_properties('Status' => 'open')
    assert @card_selection.errors.empty?
    @card_selection.update_properties('Status' => 'closed')
    assert @card_selection.errors.empty?
  end

  def test_update_properties_should_return_false_if_update_failed
    @card_selection.update_properties({'Iteration' => '1', 'Status' => ''})
    assert @card_selection.errors.empty?
    @card_selection.update_properties({'owner' => 'some cracker id', 'Status' => 'open'})
    assert_equal ["owner:  #{'some cracker id'.bold} is not a valid user"], @card_selection.errors
  end

  def test_error_messages_for_update_should_be_uniq
    assert !@card_selection.update_properties({'owner' => 'some cracker id'})
    assert_equal 1, @card_selection.errors.size
  end

  def test_tags_common_to_all
    @cards[0].tag_with(['rss', 'funky', 'wild'])
    @cards[1].tag_with(['rss', 'wild'])
    @cards[2].tag_with(['rss', 'wild', 'cool'])
    assert_equal [@rss_tag, @wild_tag].collect{|tag| tag.id}, @card_selection.tags_common_to_all.collect{|tag| tag.id}
  end

  def test_tags_common_to_all_when_none_in_common
    @cards[0].tag_with(['rss'])
    @cards[1].tag_with(['wild'])
    @cards[2].tag_with(['funky', 'cool'])
    assert_equal [], @card_selection.tags_common_to_all
  end

  def test_tags_common_to_all_when_no_cards_in_selection
    @view = view_with_no_cards_selected
    @card_selection = CardSelection.new(@project, @view)
    assert_equal [], @card_selection.tags_common_to_all
  end

  #bug 1072
  def test_tags_common_to_all_should_be_sort_by_name_ignore_case
    @cards[0].tag_with(['a tag', 'rss', 'NEW Stuff'])
    @cards[1].tag_with(['a tag', 'rss', 'NEW Stuff'])
    @cards[2].tag_with(['a tag', 'rss', 'NEW Stuff'])
    assert_equal ['a tag', 'NEW Stuff', 'rss'], @card_selection.tags_common_to_all.collect(&:name)
  end

  #bug 1072
  def test_tags_common_to_some_should_be_sort_by_name_ignore_case
    @cards[0].tag_with(['a tag'])
    @cards[1].tag_with(['NEW Stuff'])
    @cards[2].tag_with(['rss'])
    assert_equal ['a tag', 'NEW Stuff', 'rss'], @card_selection.tags_common_to_some.collect(&:name)
  end

  def test_when_no_cards
     card_selection = CardSelection.new(@project, [])
     assert_equal [], @card_selection.tags_common_to_all
     assert_equal [], @card_selection.tags_common_to_some

     card_selection = CardSelection.new(@project, '')
     assert_equal [], @card_selection.tags_common_to_all
     assert_equal [], @card_selection.tags_common_to_some

     card_selection = CardSelection.new(@project, nil)
     assert_equal [], @card_selection.tags_common_to_all
     assert_equal [], @card_selection.tags_common_to_some
  end

  def test_tags_common_to_some
    @cards[0].tag_with(['rss', 'funky', 'wild'])
    @cards[1].tag_with(['rss', 'wild'])
    @cards[2].tag_with(['wild', 'funky'])
    assert_equal [@funky_tag, @rss_tag].collect{|tag| tag.id}, @card_selection.tags_common_to_some.collect{|tag| tag.id}
  end

  def test_remove_tag
    @cards[0].tag_with(['rss', 'funky', 'wild'])
    @cards[1].tag_with(['rss', 'wild'])
    @cards[2].tag_with(['rss', 'wild', 'cool'])

    @card_selection.remove_tag(@project.tags.create!(:name => 'foo').name)
    assert_equal 'funky rss wild', @cards[0].reload.tag_list
    assert_equal 'rss wild', @cards[1].reload.tag_list
    assert_equal 'cool rss wild', @cards[2].reload.tag_list

    @card_selection.remove_tag(@rss_tag.name)
    assert_equal 'funky wild', @cards[0].reload.tag_list
    assert_equal 'wild', @cards[1].reload.tag_list
    assert_equal 'cool wild', @cards[2].reload.tag_list

    @card_selection.remove_tag(@funky_tag.name)
    assert_equal 'wild', @cards[0].reload.tag_list
    assert_equal 'wild', @cards[1].reload.tag_list
    assert_equal 'cool wild', @cards[2].reload.tag_list

    @card_selection.remove_tag(@wild_tag.name)
    assert_equal '', @cards[0].reload.tag_list
    assert_equal '', @cards[1].reload.tag_list
    assert_equal 'cool', @cards[2].reload.tag_list

    @card_selection.remove_tag(@cool_tag.name)
    assert_equal '', @cards[0].reload.tag_list
    assert_equal '', @cards[1].reload.tag_list
    assert_equal '', @cards[2].reload.tag_list

    @card_selection.remove_tag(@project.tags.create!(:name => 'more funkiness').name)
    assert_equal '', @cards[0].reload.tag_list
    assert_equal '', @cards[1].reload.tag_list
    assert_equal '', @cards[2].reload.tag_list
  end

  def test_remove_tag_with_update_from
    @cards[0].tag_with(['rss', 'funky', 'wild'])
    @cards[1].tag_with(['rss', 'wild'])
    @cards[2].tag_with(['rss', 'wild', 'cool'])
    @card_selection.update_from([@cards[0], @cards[1]])
    assert @card_selection.remove_tag('rss')

    assert_equal 'funky wild', @cards[0].reload.tag_list
    assert_equal 'wild', @cards[1].reload.tag_list
    assert_equal 'cool rss wild', @cards[2].reload.tag_list
  end

  # Bug 6436 - Untagging on a filtered list of tagged cards fail on MySQL
  def test_remove_tag_on_multiple_pages_of_cards
    @cards[0].tag_with(['rss'])
    @cards[1].tag_with(['rss'])
    view = @project.card_list_views.construct_from_params(@project, :tagged_with => "rss")
    @card_selection = CardSelection.new(@project.reload, view)
    assert_equal true, @card_selection.remove_tag(@rss_tag.name)
    assert_equal false, @cards[0].reload.tagged_with?(@rss_tag)
    assert_equal false, @cards[1].reload.tagged_with?(@rss_tag)

    @no_card_matched = @project.tags.find_or_create_by_name 'no_card_matched'
    view = @project.card_list_views.construct_from_params(@project, :tagged_with => "no_card_matched")
    @card_selection = CardSelection.new(@project.reload, view)
    assert_equal true, @card_selection.remove_tag(@no_card_matched.name)
    assert_equal false, @cards[0].reload.tagged_with?(@no_card_matched)
    assert_equal false, @cards[1].reload.tagged_with?(@no_card_matched)
  end

  def test_tag_with
    @cards[0].tag_with(['rss', 'funky', 'wild'])
    @cards[1].tag_with(['rss', 'wild'])
    @cards[2].tag_with(['rss', 'wild', 'cool'])

    original_version_sizes = @cards.collect{|c| c.reload.versions.size}

    assert @card_selection.tag_with('foo')

    assert_equal 'foo funky rss wild', @cards[0].reload.tag_list
    assert_equal 'foo rss wild', @cards[1].reload.tag_list
    assert_equal 'cool foo rss wild', @cards[2].reload.tag_list

    assert_equal original_version_sizes[0] + 1, @cards[0].versions.size
    assert_equal original_version_sizes[1] + 1, @cards[1].versions.size
    assert_equal original_version_sizes[2] + 1, @cards[2].versions.size
  end

  def test_tag_with_works_with_update_from
    @cards[0].tag_with(['rss', 'funky', 'wild'])
    @cards[1].tag_with(['rss', 'wild'])
    @cards[2].tag_with(['rss', 'wild', 'cool'])
    @card_selection.update_from([@cards[0], @cards[1]])
    assert @card_selection.tag_with('foo')

    assert_equal 'foo funky rss wild', @cards[0].reload.tag_list
    assert_equal 'foo rss wild', @cards[1].reload.tag_list
    assert_equal 'cool rss wild', @cards[2].reload.tag_list
  end


  def test_tag_with_should_work_with_all_cards_selected
    @view = view_with_all_cards_selected
    @card_selection = CardSelection.new(@project, @view)

    @card_selection.tag_with('funky')

    assert_equal 'funky', @cards[0].reload.tag_list
    assert_equal 'funky', @cards[1].reload.tag_list
    assert_equal 'funky', @cards[2].reload.tag_list
  end

  def test_tag_with_creates_taggings_for_its_versions
    @card_selection.tag_with('ratchet')
    last_version = @cards[0].reload.versions.last
    assert last_version.tags.collect(&:name).include?('ratchet')
  end


  def test_tag_with_does_not_create_duplicate_taggings
    @cards[0].tag_with(['ratchet'])
    @card_selection.tag_with('ratchet')

    ratchet_tag = @cards[0].tags.find {|tag| tag.name == 'ratchet'}
    taggings = Tagging.find(:all, :conditions => [ "tag_id = ? AND taggable_id = ? AND taggable_type = ?", ratchet_tag.id, @cards[0].id, 'Card' ])
    assert_equal 1, taggings.size
  end

  def test_tags_common_to_methods_work_after_tag_with
    @cards[0].tag_with(['hello'])
    @card_selection.tag_with('ratchet')

    assert_equal ['ratchet'], @card_selection.tags_common_to_all.collect(&:name)
    assert_equal ['hello'], @card_selection.tags_common_to_some.collect(&:name)
  end

  def test_tag_with_should_update_modified_by_user_id_and_updated_at_and_version_for_cards
    original_updated_at = @project.cards[1].updated_at
    original_card_one_version = @project.cards[0].version

    login_as_proj_admin
    Clock.fake_now(:year => 2008, :month => 4, :day => 6)
    card_1 = @project.cards[0]
    assert_equal User.find_by_email('member@email.com').id, card_1.modified_by_user_id
    @card_selection = CardSelection.new(@project, [card_1])
    @card_selection.tag_with(['some_new_tag'])

    assert_equal User.current.id, card_1.reload.modified_by_user_id
    assert_equal Clock.now, card_1.reload.updated_at
    assert_equal original_card_one_version + 1, card_1.reload.version

    assert_equal original_updated_at, @project.cards[1].reload.updated_at
  end

  def test_tagging_with_comma_separated_tags_creates_single_history_event
    @card_selection.tag_with('foo, bar')
    assert_equal 2, @cards[0].reload.versions.count
  end

  def test_remove_tag_produces_history_event
    @cards[0].tag_with(['rss'])
    @cards[0].save!

    @card_selection.remove_tag('rss')
    assert_equal 3, @cards[0].reload.versions.count
  end

  def test_remove_tag_should_update_modified_by_user_id_and_updated_at_and_version_for_cards
    card_1 = @project.cards[0]
    card_1.tag_with('foo')
    original_updated_at = @project.cards[1].updated_at
    original_card_one_version = card_1.version

    login_as_proj_admin
    Clock.fake_now(:year => 2008, :month => 4, :day => 6)
    assert_equal User.find_by_email('member@email.com').id, card_1.modified_by_user_id
    @card_selection = CardSelection.new(@project, [card_1])
    @card_selection.remove_tag('foo')

    card_1 = card_1.reload
    assert_equal User.current.id, card_1.modified_by_user_id
    assert_equal Clock.now, card_1.updated_at
    assert_equal original_card_one_version + 1, card_1.version

    assert_equal original_updated_at, @project.cards[1].reload.updated_at
  end

  def test_construct_with_comma_delimited_ids
    assert_equal [@cards[0], @cards[1]], CardSelection.cards_from(@project, "#{@cards[0].id},#{@cards[1].id}")
    assert_equal [@cards[0], @cards[1]], CardSelection.cards_from(@project, [@cards[0].id , @cards[1].id])
  end

  def test_tags_common_to_all_works
    @cards[0].tag_with(['rss', 'funky', 'wild'])
    @cards[1].tag_with(['rss', 'wild'])
    @card_selection = CardSelection.new(@project, [@cards[0], @cards[1]])
    assert_equal [@rss_tag, @wild_tag].collect(&:id), @card_selection.tags_common_to_all.collect(&:id)
  end

  def test_tags_common_to_some_work_with_update_from
    @cards[0].tag_with(['rss', 'funky', 'wild'])
    @cards[1].tag_with(['rss', 'wild'])
    @cards[2].tag_with(['rss', 'wild', 'xixi'])
    @card_selection = CardSelection.new(@project, [@cards[0], @cards[1], @cards[2]])
    @card_selection.update_from([@cards[0], @cards[1]])
    assert_equal [@funky_tag].collect(&:id), @card_selection.tags_common_to_some.collect(&:id)
  end

  def test_tags_common_to_all_works_after_update_from
    @cards[0].tag_with(['rss', 'funky', 'wild'])
    @cards[1].tag_with(['rss', 'wild'])
    @card_selection = CardSelection.new(@project, [@cards[0], @cards[1]])
    @card_selection.update_from([@cards[1]])
    assert_equal [@rss_tag, @wild_tag].collect(&:id), @card_selection.tags_common_to_all.collect(&:id)
  end

  def test_should_not_notify_count_of_cards_that_were_not_updated_due_to_bad_property_values
    @card_selection.update_properties('start date' => 'jam for sputnik')
    assert_equal "start date: #{'jam for sputnik'.bold} is an invalid date. Enter dates in #{'dd mmm yyyy'.bold} format or enter existing project variable which is available for this property.", @card_selection.errors.join
  end

  def test_tags_common_to_all_and_tags_common_to_some_only_look_at_current_cards_not_versions
    insert_columns = ['taggable_type', 'taggable_id', 'tag_id']
    select_columns = ["'Card::Version'", @cards[0].id, @wild_tag.id]

    if @project.connection.prefetch_primary_key?(Tagging)
      select_columns.unshift(@project.connection.next_id_sql(Tagging.table_name))
      insert_columns.unshift('id')
    end

    @project.connection.execute("INSERT INTO #{Tagging.table_name} (#{insert_columns.join(', ')})
                                 VALUES (#{select_columns.join(', ')})")

    @cards[0].tag_with(['rss', 'funky', 'wild'])
    @cards[1].tag_with(['rss', 'wild'])
    @card_selection = CardSelection.new(@project, [@cards[0], @cards[1]])
    assert_equal [@rss_tag, @wild_tag].collect(&:id), @card_selection.tags_common_to_all.collect(&:id)
    assert_equal [@funky_tag].collect(&:id), @card_selection.tags_common_to_some.collect(&:id)
  end

  def test_count_should_handle_a_selection_with_no_cards
    @card_selection = CardSelection.new(@project, [])
    assert_equal 0, @card_selection.count
  end

  def test_count_should_return_number_of_cards_selected_when_selection_created_with_cards
    assert_equal 3, @card_selection.count
  end

  def test_count_should_return_number_of_cards_selected_when_selection_created_with_view
    params = {:project_id => @project.identifier, :all_cards_selected => "true", :selected_cards => "1", :action => "bulk_set_properties",
              :controller => "cards", :properties => {"status"=>"open", "Type"=>"Card"}, :page => "1"}
    @view = CardListView.find_or_construct(@project, params)
    @card_selection = CardSelection.new(@project, @view)

    assert_equal 3, @card_selection.count
  end

  def test_count_should_be_zero_when_no_cards_in_selection
    view_with_no_cards = view_with_no_cards_selected
    @card_selection = CardSelection.new(@project, view_with_no_cards)
    assert_equal 0, @card_selection.count
  end

  def test_destroy_removes_cards
    @card_selection.destroy
    @cards.each { |card| assert_record_deleted card }
  end

  def test_destroy_works_with_selection_made_from_card_list_view
    view_with_all_cards = view_with_all_cards_selected
    @card_selection = CardSelection.new(@project, view_with_all_cards)
    test_destroy_removes_cards
  end

  def test_destroy_should_keep_versions_taggings
    card = @project.cards.first
    card.tag_with("foo")
    card.save!
    @card_selection.destroy
    assert_equal [], card.versions.last.tags.collect(&:name)
    assert_equal ['foo'], card.versions[-2].tags.collect(&:name)
  end

  def test_destroy_removes_card_taggings
    existing_card_ids = @project.cards.collect(&:id)
    @card_selection.tag_with('Timmy')
    @card_selection.destroy
    assert_equal [], @project.connection.select_all("SELECT * FROM #{Tagging.table_name} WHERE taggable_type = 'Card' AND taggable_id IN (#{existing_card_ids.join(',')})")
  end

  def test_destroy_removes_attachments_and_attachings
    first_card = @project.cards.first
    @project.cards.each do |card|
      card.attach_files(sample_attachment,sample_attachment('1.txt'))
      card.save!
    end

    @card_selection.destroy
    assert_equal [], first_card.attachings.reload
    assert_equal [], first_card.attachments
    assert_equal 2, first_card.versions[-2].attachings.count
    assert_equal 0, first_card.versions[-1].attachings.count
  end

  def test_destroy_removes_history_subscriptions
    @cards[0].add_tag('foo')
    history_params = HistoryFilterParams.new(:card_number => @cards[0].number).serialize
    @project.create_history_subscription(@project.users.first, history_params)
    @card_selection.destroy

    assert_equal [], @project.connection.select_values("SELECT * FROM #{HistorySubscription.table_name} WHERE hashed_filter_params = '#{HistorySubscription.param_hash(history_params)}' AND project_id = #{@project.id}")
  end

  def test_destroy_insert_deletion_versions_and_deletion_event
    login_as_admin
    Clock.fake_now(:year => 2008, :month => 4, :day => 5)
    @card_selection = CardSelection.new(@project, [@cards[0], @cards[1]])
    @card_selection.destroy
    assert_equal @cards[0].id, @cards[0].versions.last.card_id
    assert_equal @cards[0].name, @cards[0].versions.last.name
    assert_equal @cards[0].number, @cards[0].versions.last.number
    assert_equal nil, @cards[0].versions.last.description
    assert_equal User.find_by_login("member").id, @cards[0].versions.last.created_by_user_id
    assert_equal User.find_by_login("admin").id, @cards[0].versions.last.modified_by_user_id
    assert_equal @cards[0].version + 1, @cards[0].versions.last.version
    assert_equal @cards[0].created_at, @cards[0].versions.last.created_at
    assert_equal Clock.now, @cards[0].versions.last.updated_at

    assert_not_nil @cards[0].versions.last.event.target
    assert_equal CardDeletionEvent, @cards[0].versions.last.event.target.class
  end

  def test_should_create_card_deletion_event_pointing_to_last_deletion_version_on_card_destroy
    with_project_without_cards do |project|
      card = create_card!(:name => 'first card', :description => 'hello')
      card.update_attribute(:cp_iteration, 2)
      CardSelection.new(project, [card]).destroy

      project.events.reload

      last_event = project.events[-1]
      assert_equal CardDeletionEvent, last_event.class
      assert_equal card.number, last_event.origin.number
      assert_equal card.name, last_event.origin.name
      assert_equal 3, last_event.origin.version
      assert_equal card.card_type, last_event.origin.card_type
      assert_equal nil, last_event.origin.cp_iteration
      assert_equal nil, last_event.origin.description

      second_event = project.events[-2]

      assert_equal CardVersionEvent, second_event.class
      assert_equal card.number, second_event.origin.number
      assert_equal card.name, second_event.origin.name
      assert_equal 2, second_event.origin.version
      assert_equal card.card_type, second_event.origin.card_type
      assert_equal "2", second_event.origin.cp_iteration
      assert_equal 'hello', second_event.origin.description

      third_event = project.events[-3]
      assert_equal CardVersionEvent, third_event.class
      assert_equal card.number, third_event.origin.number
      assert_equal card.name, third_event.origin.name
      assert_equal 1, third_event.origin.version
      assert_equal card.card_type, third_event.origin.card_type
      assert_equal nil, third_event.origin.cp_iteration
      assert_equal 'hello', second_event.origin.description
    end
  end

  def test_destroy_removes_revision_links
    does_not_work_without_subversion_bindings do
      commit_message = 'story 101 and story 102: something'

      driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
        driver.commit_file_with_comment 'new_file.txt', 'some content', commit_message
      end

      card_101 = create_card!(:number => 101, :name => "test card")
      card_102 = create_card!(:number => 102, :name => "test card")

      original_card_101_revisions = card_101.revisions.size

      configure_subversion_for(@project, {:repository_path => driver.repos_dir})
      @project.update_attributes(:card_keywords => "story")
      recreate_revisions_for(@project)

      @card_selection = CardSelection.new(@project, [card_101])
      @card_selection.destroy

      included_card_id = card_101.id
      excluded_card_id = card_102.id
      assert_equal [], @project.connection.select_values("SELECT * FROM #{CardRevisionLink.table_name} WHERE project_id = #{@project.id} AND card_id = #{included_card_id}")
      assert 0 < @project.connection.select_value("SELECT COUNT(*) FROM #{CardRevisionLink.table_name} WHERE project_id = #{@project.id} AND card_id = #{excluded_card_id}").to_i

      assert_equal 1, card_102.reload.revisions.size
      assert_equal commit_message, card_102.revisions.last.commit_message
    end
  end

  def test_can_pass_in_card_query
    @view = view_with_all_cards_selected
    card_query = @view.as_card_query
    @card_selection = CardSelection.new(@project, card_query)
    assert_equal @cards.size, @card_selection.count
  end

  def test_update_date_properties
    @card_selection.update_properties('start date' => '27 Mar 2007')
    start_at = @project.find_property_definition('start date')
    @cards.each do |card|
      assert_equal '27 Mar 2007', card.reload.display_value(start_at)
    end
  end

  def test_update_date_properties_with_blank_value
    @card_selection.update_properties('start date' => '')
    start_at = @project.find_property_definition('start date')
    assert_equal PropertyValue::NOT_SET, @cards.first.reload.display_value(start_at)
  end

  def test_is_mixed_value
    status = @project.find_property_definition('Status')
    @card_selection.update_properties(:Status => 'open' )
    assert !@card_selection.mixed_value?(status)
    @cards.first.update_attribute(:cp_status, 'close')
    assert @card_selection.mixed_value?(status)
  end

  def test_update_properties_sets_not_applicable_properties_to_nil_when_updating_card_type
    @project.cards.each do |card|
      card.cp_status = 'open'
      card.cp_iteration = '1'
      card.cp_priority = 'high'
      card.save!
    end

    @project.find_property_definition('status').update_attribute(:hidden, true)

    setup_card_type(@project, 'iss\'ue', :properties => ['Priority'])
    @card_selection = CardSelection.new(@project.reload, @cards)

    @card_selection.update_properties('Type' => 'iss\'ue')

    @project.reload
    @project.cards.each do |card|
      assert_equal 'iss\'ue', card.card_type_name
      assert_nil card.cp_status
      assert_nil card.cp_iteration
      assert_equal 'high', card.cp_priority
    end
  end

  def test_changing_card_type_bypasses_property_protection_when_nilling_not_applicable_views
    @project.cards.each do |card|
      card.cp_status = 'open'
      card.save!
    end

    @project.find_property_definition('status').update_attribute(:transition_only, true)

    setup_card_type(@project, 'issue', :properties => ['Priority'])
    @card_selection = CardSelection.new(@project.reload, @cards)

    @card_selection.update_properties('Type' => 'issue')

    @project.reload
    @project.cards.each do |card|
      assert_equal 'issue', card.card_type_name
      assert_nil card.cp_status
    end
  end

  def test_really_select_all_with_filter
    bug_card_type = @project.card_types.create(:name => 'Bug')
    @cards.first.card_type_name = bug_card_type.name
    @cards.first.save!

    params = {:project_id=>@project.identifier, :all_cards_selected=>"true", :filters=>["[Type][is][Bug]"], :page=>"1"}
    @view = CardListView.find_or_construct(@project, params)
    @card_selection = CardSelection.new(@project, @view)
    assert_equal 1, @card_selection.count

    params = {:project_id=>@project.identifier, :all_cards_selected=>"true", :filters=>["[Type][is][Card]"], :page=>"1"}
    @view = CardListView.find_or_construct(@project, params)
    @card_selection = CardSelection.new(@project, @view)
    assert_equal 2, @card_selection.count
  end

  def test_number_list_property_definition_should_format_as_project_precision_when_update_properties
    create_project.with_active_project do |project|
      setup_numeric_property_definition('size', ['2', '4'])
      card = create_card!(:name => 'I am card')
      card_selection = CardSelection.new(project, [card])
      card_selection.update_properties('size' => '3.999')
      assert_equal 2, project.precision
      assert_equal '4', card.reload.cp_size
    end
  end

  def test_any_number_property_definition_should_format_as_project_precision_when_update_properties
    create_project.with_active_project do |project|
      setup_numeric_text_property_definition('size')
      card_1 = create_card!(:name => 'I am card', :size => '4.0')
      card_2 = create_card!(:name => 'I am card')
      card_selection = CardSelection.new(project, [card_2])
      card_selection.update_properties('size' => '3.999')
      assert_equal 2, project.precision
      assert_equal '4.00', card_2.reload.cp_size
    end
  end

  def test_bulk_delete_should_remove_value_but_not_associations_from_card_type_project_variable
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      iteration3 = create_card!(:name => 'iteration3', :card_type => type_iteration)
      iteration4 = create_card!(:name => 'iteration4', :card_type => type_iteration)
      cp_iteration = project.find_property_definition('planning iteration')
      pv_iteration3 = create_plv!(project, :name => 'pv iteration3', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_iteration, :value => iteration3.id, :property_definition_ids => [cp_iteration.id])
      pv_iteration4 = create_plv!(project, :name => 'pv iteration4', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_iteration, :value => iteration4.id, :property_definition_ids => [cp_iteration.id])
      card_selection = CardSelection.new(project, [iteration3, iteration4])
      card_selection.destroy
      pv_iteration3.reload
      pv_iteration4.reload
      assert_equal nil, pv_iteration3.value
      assert_equal [cp_iteration.name], pv_iteration3.property_definitions.collect(&:name)
      assert_equal nil, pv_iteration4.value
      assert_equal [cp_iteration.name], pv_iteration4.property_definitions.collect(&:name)
    end
  end

 def test_should_not_be_allowed_to_change_type_of_a_card_that_is_used_as_a_value_of_a_plv
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      iteration3 = create_card!(:name => 'iteration3', :card_type => type_iteration)
      release1 = project.cards.find_by_name('release1')
      cp_iteration = project.find_property_definition('planning iteration')
      cp_release = project.find_property_definition('planning release')
      pv_iteration3 = create_plv!(project, :name => 'pv iteration3', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_iteration, :value => iteration3.id, :property_definition_ids => [cp_iteration.id])
      pv_release1 = create_plv!(project, :name => 'pv release1', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_release, :value => release1.id, :property_definition_ids => [cp_release.id])
      card_selection = CardSelection.new(project, [iteration3, release1])
      card_selection.update_property('Type', type_release.name)

      assert_equal "Cannot change card type because card ##{iteration3.number} is being used as the value of project variable: #{'(pv iteration3)'.bold}", card_selection.errors.join
    end
  end

  # bug 3904
  def test_should_be_allowed_to_change_type_of_a_card_that_is_not_used_as_a_value_of_a_plv
    with_filtering_tree_project do |project|
      type_release, type_iteration, type_story, type_task, type_minutia = find_five_level_tree_types

      release1 = project.cards.find_by_name('release1')
      release2 = project.cards.find_by_name('release2')
      iteration1 = project.cards.find_by_name('iteration1')
      iteration2 = project.cards.find_by_name('iteration2')
      iteration3 = project.cards.find_by_name('iteration3')
      iteration4 = project.cards.find_by_name('iteration4')

      planning_release = project.find_property_definition('planning release')

      create_plv!(project, :name => 'current release', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_release, :value => release1.id,
                  :property_definition_ids => [planning_release.id])

      # note that release1 isn't in the selection, so this type update should work
      card_selection = CardSelection.new(project, [release2, iteration1, iteration2, iteration3, iteration4])
      card_selection.update_property('Type', type_iteration.name)

      assert_equal [], card_selection.errors
    end
  end

  # bug 3904 message change portion
  def test_plv_usage_messages
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      release1 = project.cards.find_by_name('release1')
      iteration1 = project.cards.find_by_name('iteration1')
      planning_release = project.find_property_definition('planning release')
      planning_iteration = project.find_property_definition('planning iteration')

      create_plv!(project, :name => 'current release', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_release, :value => release1.id,
                  :property_definition_ids => [planning_release.id])
      create_plv!(project, :name => 'other release', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_release, :value => release1.id,
                  :property_definition_ids => [planning_release.id])
      create_plv!(project, :name => 'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_iteration, :value => iteration1.id,
                  :property_definition_ids => [planning_iteration.id])

      card_selection = CardSelection.new(project, [release1])
      card_selection.update_property('Type', type_iteration.name)
      assert_equal "Cannot change card type because card ##{release1.number} is being used as the value of project variables: #{'(current release)'.bold}, #{'(other release)'.bold}", card_selection.errors.join

      card_selection = CardSelection.new(project, [release1, iteration1])
      card_selection.update_property('Type', type_story.name)
      assert_equal "Cannot change card type because some cards are being used as the value of project variables: #{'(current iteration)'.bold}, #{'(current release)'.bold}, #{'(other release)'.bold}", card_selection.errors.join
    end
  end

  def test_should_not_allow_card_type_to_be_changed_for_a_card_that_is_used_as_a_transition_prerequisite_or_action
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types

      iteration3 = create_card!(:name => 'iteration3', :card_type => type_iteration)
      release1 = project.cards.find_by_name('release1')

      oh_yeah = create_transition_without_save(project, 'oh yeah', :set_properties => {'Planning release' => release1.id})
      oh_yeah.save

      oh_no = create_transition_without_save(project, 'oh no!', :set_properties => {'Planning release' => release1.id})
      oh_no.save

      card_selection = CardSelection.new(project, [iteration3, release1])
      card_selection.update_property('Type', type_iteration.name)

      assert_equal ["Cannot change card type because some cards are being used in transitions: #{'oh no!'.bold}, #{'oh yeah'.bold}"], card_selection.errors
    end
  end

  def test_should_allow_changing_a_card_relationship_property_in_bulk_edit
    with_card_query_project do |project|
      card1 = project.cards.create!(:name => 'card one', :card_type_name => 'Card')
      card2 = project.cards.create!(:name => 'card two', :card_type_name => 'Card', :cp_related_card => card1)
      card3 = project.cards.create!(:name => 'card three', :card_type_name => 'Card', :cp_related_card => card2)

      card_selection = CardSelection.new(project, [card1, card2])
      card_selection.update_property('related card', card3.id)

      assert_equal card3, card1.reload.cp_related_card
      assert_equal card3, card2.reload.cp_related_card
    end
  end

  def test_should_create_correct_versions_for_associated_cards_if_a_card_which_is_used_as_value_for_generic_card_property_values_is_deleted
    with_card_query_project do |project|
      card1 = project.cards.create!(:name => 'card one', :card_type_name => 'Card')
      card2 = project.cards.create!(:name => 'card two', :card_type_name => 'Card', :cp_related_card => card1)
      card3 = project.cards.create!(:name => 'card three', :card_type_name => 'Card', :cp_related_card => card2)

      assert_equal 1, card3.version
      CardSelection.new(project, [card1, card2]).destroy
      assert_equal 2, card3.reload.version
    end
  end

  def test_should_clear_card_relationship_properties_associated_with_cards_that_are_deleted
    with_card_query_project do |project|
      card1 = project.cards.create!(:name => 'card one', :card_type_name => 'Card')
      card2 = project.cards.create!(:name => 'card two', :card_type_name => 'Card')
      card3 = project.cards.create!(:name => 'card two', :card_type_name => 'Card')
      card_related_to_card1 = project.cards.create!(:name => 'related to card one'  , :card_type_name => 'Card', :cp_related_card => card1)
      card_related_to_card2 = project.cards.create!(:name => 'related to card two'  , :card_type_name => 'Card', :cp_related_card => card2)
      card_related_to_card3 = project.cards.create!(:name => 'related to card three', :card_type_name => 'Card', :cp_related_card => card3)

      assert_equal(card1, card_related_to_card1.cp_related_card)
      assert_equal(card2, card_related_to_card2.cp_related_card)
      assert_equal(card3, card_related_to_card3.cp_related_card)
      CardSelection.new(project, [card1, card2]).destroy
      [card_related_to_card1, card_related_to_card2, card_related_to_card3].each(&:reload)
      assert_nil(card_related_to_card1.cp_related_card)
      assert_nil(card_related_to_card2.cp_related_card)
      assert_equal(card3, card_related_to_card3.cp_related_card)
    end
  end

  # Bug 5191.
  def test_should_only_clear_the_card_relationship_value_of_the_card_that_is_deleted
    with_new_project do |project|
      setup_card_relationship_property_definition('related card 1')
      setup_card_relationship_property_definition('related card 2')
      related_card_to_destroy, related_card_not_to_destroy, core_card = ['doomed', 'happy', 'core'].collect { |card_name| project.cards.create!(:name => card_name, :card_type_name => 'Card') }
      core_card.cp_related_card_1 = related_card_to_destroy
      core_card.cp_related_card_2 = related_card_not_to_destroy
      core_card.save!

      CardSelection.new(project, [related_card_to_destroy]).destroy
      core_card.reload
      assert_nil(core_card.cp_related_card_1)
      assert_equal(related_card_not_to_destroy, core_card.cp_related_card_2)
    end
  end

  def test_should_clear_card_relationship_properties_with_values_set_to_cards_that_are_deleted
    with_card_query_project do |project|
      card1, card2, card3 = (1..3).collect do |index|
        project.cards.create!(:name => "card #{index}", :card_type_name => 'Card')
      end
      card4 = project.cards.create!(:name => "card 4", :card_type_name => 'Card', :cp_related_card => card1)
      card5 = project.cards.create!(:name => "card 5", :card_type_name => 'Card', :cp_related_card => card2)
      card6 = project.cards.create!(:name => "card 6", :card_type_name => 'Card', :cp_related_card => card3)

      assert_equal(card1, card4.cp_related_card)
      assert_equal(card2, card5.cp_related_card)
      assert_equal(card3, card6.cp_related_card)
      CardSelection.new(project, [card1, card2]).destroy
      assert_nil(card4.reload.cp_related_card)
      assert_nil(card5.reload.cp_related_card)
      assert_equal(card3, card6.reload.cp_related_card)
    end
  end

  def test_should_remove_transitions_associated_with_cards_that_are_deleted
    with_card_query_project do |project|
      card1, card2, card3 = ['card one', 'card two', 'card three'].collect { |card_name| project.cards.create!(:name => card_name, :card_type_name => 'Card') }
      [card1, card2, card3].each do |card|
        create_transition project, "#{card.name} required", :required_properties => {'related card' => card.id}, :set_properties => {:status => 'New'}
        create_transition project, "#{card.name} set"     ,                                                      :set_properties => {'related card' => card.id}
      end

      assert_equal(["card one required", "card one set", "card two required", "card two set", "card three required", "card three set"].sort, project.reload.transitions.collect(&:name).sort)
      CardSelection.new(project, [card1, card2]).destroy
      assert_equal(["card three required", "card three set"].sort, project.reload.transitions.collect(&:name).sort)
    end
  end

  def test_should_remove_card_defaults_associated_with_cards_that_are_deleted
    with_card_query_project do |project|
      card_type = project.card_types.find_by_name('Card')
      default_card = project.cards.create!(:name => 'card one', :card_type => card_type)
      card_defaults = card_type.card_defaults
      card_defaults.update_properties 'related card' => default_card.id, :status => 'New'
      card_defaults.save!

      assert_equal(['related card', 'Status'].sort, card_defaults.actions.collect(&:target_property).collect(&:name).sort)
      CardSelection.new(project, [default_card]).destroy
      assert_equal(['Status'], card_defaults.reload.actions.collect(&:target_property).collect(&:name))
    end
  end

  def test_should_warn_which_transitions_have_card_relationships_that_will_be_deleted
    with_card_query_project do |project|
      card = project.cards.first
      create_transition_without_save(project, 'require first card', :required_properties => {'related card' => card.id}, :set_properties => {'status'       => 'open'  }).save!
      create_transition_without_save(project, 'set first card'    ,                                                      :set_properties => {'related card' => card.id }).save!
      create_transition_without_save(project, 'unrelated'         , :required_properties => {'status'       => 'open' }, :set_properties => {'status'       => 'closed'}).save!

      assert_equal(['require first card', 'set first card', 'unrelated'], project.transitions.collect(&:name).sort)
      warnings = CardSelection.new(project, [card]).warnings
      assert_equal(['require first card', 'set first card'], warnings[:items_that_will_be_deleted][:transitions])
    end
  end

  def test_should_warn_which_transitions_have_tree_relationships_that_will_be_deleted
    with_three_level_tree_project do |project|
      iteration1 = project.cards.find_by_name('iteration1')
      create_transition_without_save(project, 'require iteration1', :required_properties => {'Planning iteration' => iteration1.id}, :set_properties => {'status'       => 'open'  }).save!
      create_transition_without_save(project, 'set iteration1'    ,                                                      :set_properties => {'Planning iteration' => iteration1.id }).save!
      create_transition_without_save(project, 'unrelated'         , :required_properties => {'status'       => 'open' }, :set_properties => {'status'       => 'closed'}).save!
      assert_equal(['require iteration1', 'set iteration1', 'unrelated'], project.transitions.collect(&:name).sort)
      warnings = CardSelection.new(project, [iteration1]).warnings
      assert_equal(['require iteration1', 'set iteration1'], warnings[:items_that_will_be_deleted][:transitions])
    end
  end

  def test_should_warn_which_project_variables_will_have_values_set_to_not_set
    with_three_level_tree_project do |project|
      iteration1, iteration2 = ['iteration1', 'iteration2'].collect { |name| project.cards.find_by_name(name) }
      iteration_type = project.card_types.find_by_name('iteration')
      planning_iteration_property_definition = project.find_property_definition('planning iteration')
      plv_iteration1 = create_plv!(project, :name => 'plv iteration1', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => iteration_type, :value => iteration1.id,
                                  :property_definition_ids => [planning_iteration_property_definition.id])
      plv_iteration2 = create_plv!(project, :name => 'plv iteration2', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => iteration_type, :value => iteration2.id,
                                  :property_definition_ids => [planning_iteration_property_definition.id])
      warnings = CardSelection.new(project, [iteration1, iteration2]).warnings
      assert_equal(['plv iteration1', 'plv iteration2'], warnings[:values_that_will_be_not_set][:project_variables])
    end
  end

  def test_should_warn_which_transitions_will_be_deleted_because_they_are_tied_to_plv_that_has_a_destroyed_card_as_a_value
    with_three_level_tree_project do |project|
      iteration1 = project.cards.find_by_name('iteration1')
      iteration_type = iteration1.card_type
      planning_iteration_property_definition, related_card_property_definition = ['planning iteration', 'related card'].collect { |property_name| project.find_property_definition(property_name) }
      plv = create_plv!(project, :name => 'plv iteration1', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => iteration_type, :value => iteration1.id,
                                 :property_definition_ids => [planning_iteration_property_definition.id, related_card_property_definition.id])

      create_transition_without_save(project, 'require iteration1 for card relationship', :required_properties => {'related card'       => plv.display_name },
                                                                                          :set_properties      => {'status'             => 'open'           }).save!

      create_transition_without_save(project, 'require iteration1 for tree relationship', :required_properties => {'planning iteration' => plv.display_name },
                                                                                          :set_properties      => {'status'             => 'closed'         }).save!

      create_transition_without_save(project, 'set iteration1 for card relationship'    , :set_properties      => {'related card'       => plv.display_name }).save!

      create_transition_without_save(project, 'set iteration1 for tree relationship'    , :set_properties      => {'planning iteration' => plv.display_name }).save!

      create_transition_without_save(project, 'unrelated'                               , :required_properties => {'status'             => 'open'           },
                                                                                          :set_properties      => {'status'             => 'closed'         }).save!

      warnings = CardSelection.new(project, [iteration1]).warnings
      expected_transitions_to_delete = ['require iteration1 for card relationship', 'require iteration1 for tree relationship', 'set iteration1 for card relationship', 'set iteration1 for tree relationship'].sort
      assert_equal(expected_transitions_to_delete, warnings[:items_that_will_be_deleted ][:transitions].sort)
      assert_equal(['plv iteration1'], warnings[:values_that_will_be_not_set][:project_variables])
    end
  end

  def test_should_warn_how_many_cards_will_have_card_relationship_properties_that_will_be_not_set
    with_card_query_project do |project|
      related_card = project.cards.first
      card1, card2 = ['card1', 'card2'].collect do |name|
        create_card!(:name => name).tap do |card|
          card.cp_related_card = related_card
          card.save!
        end
      end

      assert_equal(related_card, card1.cp_related_card)
      assert_equal(related_card, card2.cp_related_card)
      warnings = CardSelection.new(project, [related_card]).warnings
      assert_equal(2, warnings[:card_relationship][:usage_count])
      assert_equal(['related card'], warnings[:card_relationship][:properties])
    end
  end

  def test_not_in_selection
    first_card, second_card, third_card = @cards
    card_selection = CardSelection.new(@project, [first_card, second_card])
    assert [third_card], card_selection.not_in_selection([second_card.id, third_card.id])
    assert [], card_selection.not_in_selection([first_card.id, second_card.id])
    assert [third_card], card_selection.not_in_selection([third_card.id])
  end

  # 4405 sign-off issue with MySql.
  def test_should_be_able_to_show_warning_when_more_than_one_card_relationship_property_exists
    with_new_project do |project|
      setup_card_relationship_property_definition('related card 1')
      setup_card_relationship_property_definition('related card 2')
      card_to_destroy = project.cards.create!(:name => 'doomed', :card_type_name => 'Card')
      card1 = create_card!(:name => 'related through related card 1')
      card1.cp_related_card_1 = card_to_destroy
      card1.save!
      card2 = create_card!(:name => 'related through related card 2')
      card2.cp_related_card_2 = card_to_destroy
      card2.save!

      warnings = CardSelection.new(project, [card_to_destroy]).warnings
      assert_equal(2, warnings[:card_relationship][:usage_count])
      assert_equal(['related card 1', 'related card 2'], warnings[:card_relationship][:properties])
    end
  end

  def test_should_only_warn_about_card_relationship_properties_which_had_cards_associated_to_the_deleted_cards
    with_new_project do |project|
      setup_card_relationship_property_definition('related card 1')
      setup_card_relationship_property_definition('related card 2')
      card_to_destroy = project.cards.create!(:name => 'doomed', :card_type_name => 'Card')
      card1 = create_card!(:name => 'related through related card 1')
      card1.cp_related_card_1 = card_to_destroy
      card1.save!
      card2 = create_card!(:name => 'related through related card 1')
      card2.cp_related_card_1 = card_to_destroy
      card2.save!
      # No cards are related through cp_related_card_2.

      warnings = CardSelection.new(project, [card_to_destroy]).warnings
      assert_equal(2, warnings[:card_relationship][:usage_count])
      assert_equal(['related card 1'], warnings[:card_relationship][:properties])
    end
  end

  def test_should_warn_which_trees_bulk_destroy_belongs_to
    with_three_level_tree_project do |project|
      iteration1 = project.cards.find_by_name('iteration1')

      warnings = CardSelection.new(project, [iteration1]).warnings
      assert_equal(['three level tree'], warnings[:belongs_to_trees])
      assert_equal(2, warnings[:tree_relationship][:usage_count])
      assert_equal(['Planning iteration'], warnings[:tree_relationship][:properties])
    end
  end

  def test_bulk_update_with_no_cards_selected_will_not_change_any_cards
    some_card = @project.cards.first
    assert some_card.cp_status != 'open'

    @card_selection = CardSelection.new(@project, [])
    @card_selection.update_properties('status' => 'open')

    assert some_card.reload.cp_status != 'open'
  end

  # bug 6798
  def test_should_be_allowed_to_change_card_type_of_card_that_is_not_being_used_in_transition
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      iteration1 = project.cards.find_by_name('iteration1')
      story1 = project.cards.find_by_name('story1')

      # it is important to the test that this transition sets a property to a string value (status to open, in this case)
      transition = create_transition(project, 'Add to Iteration 1 and open card', :card_type => type_story, :set_properties => { 'Planning iteration' => iteration1.id, 'status' => 'open' })
      iteration3 = project.cards.create!(:name => 'iteration3', :card_type_name => 'Iteration')

      card_selection = CardSelection.new(project, [iteration3])
      card_selection.update_properties('Type' => 'Story')

      assert_equal [], card_selection.errors
      assert_equal 'Story', iteration3.reload.card_type_name
    end
  end

  # bug 6798
  def test_should_be_allowed_to_change_a_card_type_of_a_card_not_being_used_in_transition_when_plv_is_in_transition
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      cp_iteration = project.find_property_definition('Planning iteration')
      iteration1 = project.cards.find_by_name('iteration1')
      story1 = project.cards.find_by_name('story1')

      current_iteration = create_plv!(project, :name => 'current iteration', :data_type => ProjectVariable::CARD_DATA_TYPE, :card_type => type_iteration, :value => iteration1.id, :property_definition_ids => [cp_iteration.id])

      transition = create_transition(project, 'Add to Iteration 1', :card_type => type_story, :set_properties => { 'Planning iteration' => current_iteration.display_name })
      iteration3 = project.cards.create!(:name => 'iteration3', :card_type_name => 'Iteration')

      card_selection = CardSelection.new(project, [iteration3])
      card_selection.update_properties('Type' => 'Story')

      assert_equal [], card_selection.errors
      assert_equal 'Story', iteration3.reload.card_type_name
    end
  end

  # bug 9205
  def test_bulk_updating_to_non_existent_card_type_produces_nice_error_message
    card = @project.cards.first
    original_card_type_name = card.card_type_name

    card_selection = CardSelection.new(@project, [card])
    card_selection.update_properties('Type' => 'I Do Not Exist')

    assert_equal ["Card type I Do Not Exist does not exist in project #{@project.name}."], card_selection.errors
    assert_equal original_card_type_name, card.reload.card_type_name
  end

  # oracle 11g build ac tests failed by a nested sql, this test reproduced the problem
  def test_oracle11g_build_failure
    with_three_level_tree_project do |project|
      selector = CardSelector.new(project, :context_mql => "")
      filters = selector.to_filter(nil)
      assert_sort_equal ["iteration2", "story1", "story2"], selector.filter_by(filters.as_card_query, :page => 1, :per_page => 3).collect(&:name)
    end
  end

  private

  def view_with_no_cards_selected
    params =  {:project_id => @project.identifier, :tagged_with => "nonexistenttag", :page => "1"}
    CardListView.find_or_construct(@project, params)
  end

  def view_with_all_cards_selected
    params =  {:project_id => @project.identifier, :all_cards_selected => "true", :page => "1"}
    CardListView.find_or_construct(@project, params)
  end

  def cards_in(cards)
    cards.collect(&:id).join(',')
  end

end
