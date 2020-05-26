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

class FormulaPropertyDefinitionTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    @project = create_project
    @project.activate
    login_as_member
    Clock.fake_now(:year => 2003, :month => 10, :day => 4)
  end

  def teardown
    Clock.reset_fake
  end

  def test_should_not_allow_creation_or_update_of_multiple_formula_properties_with_the_same_name
    one_third = setup_formula_property_definition('one third', '1/3')
    two_third = setup_formula_property_definition('two third', '2/3')
    fake_one_third = create_formula_property_definition(@project, 'one third', '1/3')
    fake_one_third.save

    assert_equal 'Name has already been taken', fake_one_third.errors.full_messages.join

    two_third.name = 'one third'
    two_third.save

    assert_equal 'Name has already been taken', two_third.errors.full_messages.join
  end

  def test_should_round_decimals_to_project_precision
    card = @project.cards.create!(:name => 'Card Two', :card_type_name => @project.card_types.first.name)
    one_eighth = setup_formula_property_definition('one eighth', '1/8')
    one_eighth.update_all_cards
    one_third = setup_formula_property_definition('one third', '1/3')
    one_third.update_all_cards
    half = setup_formula_property_definition('half', '1/2')
    half.update_all_cards

    assert_equal 0.13, one_eighth.value(card.reload)
    assert_equal 0.33, one_third.value(card.reload)
    assert_equal 0.5, half.value(card.reload)
  end

  def test_should_store_results_of_calculation_done_in_sql_with_project_precision_number_of_decimal_digits_at_most
    size = setup_numeric_property_definition('size', [1, 2, 3])
    card = @project.cards.create!(:name => 'Card Two', :card_type_name => @project.card_types.first.name)
    two_thirds = setup_formula_property_definition('two thirds', '2 / 3')
    two_thirds.update_all_cards
    two_times_size = setup_formula_property_definition('two times size', '2 * size')
    two_times_size.update_all_cards

    assert_equal 2, @project.precision
    assert_equal ["0.67"], two_thirds.values
    assert_in_delta 0.67, two_thirds.value(card.reload), 0.001 #errors may exist past the decimal precision we care about. viz. 3

    @project.update_attributes(:precision => 4)
    assert_equal ["0.6700"], two_thirds.values
    assert_in_delta 0.67, two_thirds.value(card.reload), 0.001 #errors may exist past the decimal precision at time of calculation. viz. 3

    @project.update_attributes(:precision => 1)
    assert_equal ["0.7"], two_thirds.values
    assert_in_delta 0.7, two_thirds.value(card.reload), 0.001 #errors may exist past the decimal precision at time of calculation. viz. 3

    @project.update_attributes(:precision => 0)
    assert_equal ["1"], two_thirds.values
    assert_in_delta 1, two_thirds.value(card.reload), 0.001 #errors may exist past the decimal precision at time of calculation. viz. 3

    @project.update_attributes(:precision => 1)
    assert_equal ["1.0"], two_thirds.values
    assert_in_delta 1, two_thirds.value(card.reload), 0.001 #errors may exist past the decimal precision at time of calculation. viz. 3
  end

  def test_should_store_results_of_calculation_done_in_ruby_with_project_precision_number_of_decimal_digits_at_most
    two_thirds = setup_formula_property_definition('two thirds', '2 / 3')
    @project.reload
    card = @project.cards.create!(:name => 'Card Two', :card_type_name => @project.card_types.first.name)

    assert_equal 2, @project.precision
    assert_equal ["0.67"], two_thirds.values
    assert_in_delta 0.67, two_thirds.value(card.reload), 0.001 #errors may exist past the decimal precision we care about. viz. 3

    @project.update_attributes(:precision => 4)
    assert_equal ["0.6700"], two_thirds.values

    @project.update_attributes(:precision => 0)
    assert_equal ["1"], two_thirds.values
    assert_in_delta 1, two_thirds.value(card.reload), 0.001 #errors may exist past the decimal precision at time of calculation. viz. 3

    @project.update_attributes(:precision => 1)
    assert_equal ["1.0"], two_thirds.values
    assert_in_delta 1.0, two_thirds.value(card.reload), 0.001 #errors may exist past the decimal precision at time of calculation. viz. 3
  end

  def test_should_be_able_to_set_no_card_types_for_a_formula_property_definition
    no_type = create_formula_property_definition(@project, 'no types', '2')
    no_type.save

    assert no_type.save!
  end

  def test_update_all_cards
    create_cards @project, 3

    @project.cards.all? {|card| assert_equal 1, card.version}

    formula_property = setup_formula_property_definition('formula', '2 + 3')
    formula_property.update_all_cards

    @project.cards.reload.each { |card| assert_equal 5, formula_property.value(card) }
    @project.cards.each { |card| assert_equal 2, card.versions.reload.size }
  end

  def test_update_all_cards_works_using_formulae_with_property_names
    create_cards @project, 3

    setup_numeric_text_property_definition('release')

    @project.cards.each {|card| card.cp_release = card.number.to_s; card.save!}

    formula_property = setup_formula_property_definition('formula', '2 + release')
    formula_property.update_all_cards

    @project.cards.reload.each { |card| assert_equal((2 + card.number), formula_property.value(card)) }
  end

  def test_update_all_cards_treats_division_by_zero_as_as_null
    create_cards @project, 3

    formula_property = setup_formula_property_definition('formula', '3 / 0')
    formula_property.update_all_cards

    @project.cards.reload.each { |card| assert_nil card.cp_formula }
  end

  def test_update_all_cards_handles_fractions_properly
    create_cards @project, 3

    formula_property = setup_formula_property_definition('formula', '1 / 2')
    formula_property.update_all_cards

    assert_equal 0.5, formula_property.value(@project.cards.first)
  end

  def test_update_all_cards_works_with_complex_formulae_involving_numeric_and_date_properties
    setup_date_property_definition('date')
    setup_numeric_text_property_definition('numeric free')
    setup_numeric_property_definition('numeric list', [])

    card = @project.cards.create!(:name => 'card one', :card_type_name => @project.card_types.first.name, :cp_date => Clock.today, :cp_numeric_free => '2', :cp_numeric_list => '5')

    assert_equal 1, card.version

    formula_property = setup_formula_property_definition('complex', "(('numeric free' + 'date') - ('date' + 'numeric list'))")
    formula_property.update_all_cards

    assert_equal(-3, formula_property.value(card.reload))
    assert_equal 2, card.versions.reload.size
  end

  def test_updating_null_is_zero_should_trigger_bulk_update_for_all_affected_cards
    setup_numeric_text_property_definition('estimate')
    formula_property = setup_formula_property_definition('padded estimate', 'estimate * 2')
    card = @project.cards.create!(:name => 'card one', :card_type_name => @project.card_types.first.name, :cp_estimate => nil)
    assert_equal nil, formula_property.value(card)
    formula_property.update_attributes!(:null_is_zero => true)
    assert_equal 0, formula_property.value(card.reload)
  end

  def test_should_save_formula_columns_as_null_when_a_divide_by_zero_error_occours_during_formula_evaluation
    formula_property = setup_formula_property_definition('formula', '3 / 0')
    create_cards @project, 1

    assert_nil @project.cards.first.cp_formula
  end

  def test_should_save_formula_columns_as_null_when_a_multiply_by_nil_occurs_during_formula_evaluation
    setup_numeric_text_property_definition('release')

    formula_property = setup_formula_property_definition('formula', '3 * release')
    create_cards @project, 1

    assert_nil @project.cards.first.cp_formula
  end

  def test_should_save_formula_columns_as_null_when_a_divide_by_nil_occurs_during_formula_evaluation
    setup_numeric_text_property_definition('release')

    formula_property = setup_formula_property_definition('formula', '3 / release')
    create_cards @project, 1

    assert_nil @project.cards.first.cp_formula
  end

  def test_should_not_accept_a_formula_that_is_not_well_formed
    setup_numeric_text_property_definition('release')

    formula_property_1 = create_formula_property_definition(@project, 'formula_1', '3 % release')
    formula_property_2 = create_formula_property_definition(@project, 'formula_2', '(3 / release')
    formula_property_3 = create_formula_property_definition(@project, 'formula_3', '(3 / release))')
    formula_property_4 = create_formula_property_definition(@project, 'formula_4', '3 / 2.4f3')

    [formula_property_1, formula_property_2, formula_property_3, formula_property_4].each do |prop_def|
      assert !prop_def.valid?
      assert prop_def.errors.full_messages.any? {|error| error =~ /^The formula is not well formed/}
    end
  end

  def test_should_only_allow_numeric_property_definitions_to_be_used_in_contructing_formula_property_definitions
    setup_numeric_text_property_definition('release')
    setup_text_property_definition('comment')

    formula_property = create_formula_property_definition(@project, 'formula_1', 'release + comment')

    assert !formula_property.valid?
    assert_equal ["Property #{'comment'.bold} is not numeric."], formula_property.errors.full_messages
  end

  def test_should_handle_multiple_word_property_definition_names_without_quotes_gracefully
    setup_numeric_text_property_definition("your mom's release")
    setup_numeric_text_property_definition("your release")

    formula_property = create_formula_property_definition(@project, 'formula_1', "1 + your mom's release")
    formula_property_2 = create_formula_property_definition(@project, 'formula_2', "1 + \"your mom's release\"")
    formula_property_3 = create_formula_property_definition(@project, 'formula_3', "1 + 'your release'")


    assert !formula_property.valid?
    assert_equal ["The formula is not well formed. Unexpected characters encountered: 's release..."], formula_property.errors.full_messages

    assert formula_property_2.valid?
    assert formula_property_3.valid?
  end

  def test_should_only_allow_property_definitions_from_a_single_card_type_to_be_used_in_constructing_formulas
    release = setup_numeric_text_property_definition('release')
    comment = setup_numeric_text_property_definition('comment')

    formula_property = setup_formula_property_definition('formula_1', 'ReLeAsE + CoMmEnT')

    story_type = @project.card_types.create! :name => "Story"
    bug_type = @project.card_types.create! :name => "Bug"

    formula_property.card_types = [story_type]
    story_type.add_property_definition(release)
    bug_type.add_property_definition(comment)

    assert !formula_property.valid?
    assert formula_property.errors.full_messages.any? {|error| error =~ /^The component property should be available to all card types that formula property is available to/}
  end

  def test_formula_property_definition_with_no_card_types_should_be_valid
    release = setup_numeric_text_property_definition('size')
    formula_property = @project.create_formula_property_definition!(:name => 'formula', :formula => 'size * 2')

    assert formula_property.valid?
  end

  def test_formula_property_cannot_have_card_type_that_component_does_not_have
    release = setup_numeric_text_property_definition('release')
    comment = setup_numeric_text_property_definition('comment')

    formula_property = setup_formula_property_definition('formula_1', 'release + comment')

    story_type = @project.card_types.create! :name => "Story"
    bug_type = @project.card_types.create! :name => "Bug"

    story_type.add_property_definition(release)
    story_type.add_property_definition(comment)
    bug_type.add_property_definition(comment)

    formula_property.card_types = [story_type, bug_type]

    assert !formula_property.valid?
    assert formula_property.errors.full_messages.any? {|error| error =~ /^The component property should be available to all card types that formula property is available to/}
  end

  def test_formula_should_be_invalid_if_use_created_on
    assert_raise ActiveRecord::RecordInvalid do
      setup_formula_property_definition('formula_1', "'created on' + 1")
    end
  end

  def test_should_allow_hidden_property_definitions_to_be_used_in_constructing_formulas
    release = setup_numeric_text_property_definition('release')
    release.hidden = true
    release.save!

    formula_property = setup_formula_property_definition('formula_1', 'release + 1')
    assert formula_property.valid?
  end

  def test_should_show_errors_for_all_relevant_involved_properties_when_validation_fails
    release = setup_text_property_definition('release')
    comment = setup_text_property_definition('comment')

    formula_property = create_formula_property_definition(@project, 'formula_1', 'release + comment')

    assert !formula_property.valid?
    assert_equal ["Properties #{'release'.bold} and #{'comment'.bold} are not numeric."], formula_property.errors.full_messages
  end

  def test_should_update_formulae_when_component_properties_are_renamed
    release = setup_numeric_text_property_definition('release')
    other_release = setup_numeric_text_property_definition('other release')
    next_release = setup_formula_property_definition('next release', "release + 1 + 'other release'")

    release.name = 'version'

    next_release = @project.find_property_definition('next release')
    assert_equal "(version + 1 + 'other release')", next_release.formula.to_s
  end

  def test_should_generate_versions_with_system_generated_comments_explaining_changes_in_formula_when_a_formula_changes
    release = setup_numeric_text_property_definition('release')
    next_release = setup_formula_property_definition('next release', "release + 1")

    card_one = @project.cards.create!(:name => 'Card One', :card_type_name => @project.card_types.first.name, :cp_release => '41')
    assert_equal 42, next_release.value(card_one)

    next_release.change_formula_to('release + 8')

    assert_equal 49, next_release.value(card_one.reload)
    assert_equal "next release changed from release + 1 to release + 8", card_one.versions.last.system_generated_comment
  end

  def test_should_generate_versions_even_when_formula_is_hidden
    release = setup_numeric_text_property_definition('release')
    next_release = setup_formula_property_definition('next release', "release + 1")

    next_release.hidden = true
    next_release.save!

    card_one = @project.cards.create!(:name => 'Card One', :card_type_name => @project.card_types.first.name, :cp_release => '41')
    assert_equal 42, next_release.value(card_one)

    assert_equal "42",  card_one.versions.last.cp_next_release
  end

  def test_should_not_generate_versions_unless_formula_change_will_impact_formula_value_on_cards
    release = setup_numeric_text_property_definition('release')
    next_release = setup_formula_property_definition('next release', "release * 3 - 1")

    card_one = @project.cards.create!(:name => 'Card One', :card_type_name => @project.card_types.first.name, :cp_release => '2')
    card_two = @project.cards.create!(:name => 'Card Two', :card_type_name => @project.card_types.first.name, :cp_release => '3')
    assert_equal 5, next_release.value(card_one)
    assert_equal 8, next_release.value(card_two)

    next_release.change_formula_to('release * 2.5')
    assert_equal 5, next_release.value(card_one.reload)
    assert_equal 7.5, next_release.value(card_two.reload)
    assert_equal 1, card_one.reload.version
    assert_equal 2, card_two.reload.version
    assert_equal 1, card_one.versions.size
    assert_equal 2, card_two.versions.size
  end

  # bug 3057
  def test_should_not_create_card_version_when_formula_property_created_and_value_on_card_is_not_set
    type_card = @project.card_types.find_by_name('Card')
    size = setup_numeric_property_definition('size', [1, 2, 3])
    card = @project.cards.create!(:name => 'card one', :card_type => type_card, :cp_size => nil)
    card2 = @project.cards.create!(:name => 'card two', :card_type => type_card, :cp_size => '2')

    formula = setup_formula_property_definition('size times four', 'size * 4')
    formula.update_all_cards

    assert_equal 1, card.reload.version
    assert_equal 1, card.versions.size
    assert_equal 2, card2.reload.version
    assert_equal 2, card2.versions.size
  end

  def test_should_use_numeric_sort_when_listing_cards_with_formula_values_in_card_list_view
    release = setup_numeric_text_property_definition('release')
    negated_release = setup_formula_property_definition('negated release', "- release")

    card_one = @project.cards.create!(:name => 'Card One', :card_type_name => @project.card_types.first.name, :cp_release => '1')
    card_two = @project.cards.create!(:name => 'Card Two', :card_type_name => @project.card_types.first.name, :cp_release => '2')
    card_three = @project.cards.create!(:name => 'Card Three', :card_type_name => @project.card_types.first.name, :cp_release => '10')
    card_four = @project.cards.create!(:name => 'Card Frou', :card_type_name => @project.card_types.first.name, :cp_release => '20')

    view = CardListView.find_or_construct(@project, :columns => 'number,name,release,next release', :sort => 'release', :order => 'asc')
    assert_equal [card_one, card_two, card_three, card_four],  view.cards

    view = CardListView.find_or_construct(@project, :columns => 'number,name,release,next release', :sort => 'negated release', :order => 'asc')
    assert_equal [card_four, card_three, card_two, card_one],  view.cards

    view = CardListView.find_or_construct(@project, :columns => 'number,name,release,next release', :filters => ['[negated release][is greater than][-10]'])
    view = CardListView.find_or_construct(@project, :columns => 'number,name,release,next release', :filters => ['[negated release][is less than][-2]'])
    assert_equal [4,3],  view.card_numbers
  end

  def test_should_return_list_of_sanitized_values
    size = setup_numeric_text_property_definition('size')
    half_size = setup_formula_property_definition('half size', "0.5 * size")

    card_one = @project.cards.create!(:name => 'Card One', :card_type_name => @project.card_types.first.name, :cp_size => '1')
    card_two = @project.cards.create!(:name => 'Card Two', :card_type_name => @project.card_types.first.name, :cp_size => '2')
    card_three = @project.cards.create!(:name => 'Card Three', :card_type_name => @project.card_types.first.name)
    card_four = @project.cards.create!(:name => 'Card Frou', :card_type_name => @project.card_types.first.name, :cp_size => '-1.1')
    assert_equal ["-0.55", "0.5", "1"], half_size.values.sort
  end

  def test_should_fail_gracefully_when_changing_formula_value_to_a_non_parsable_value
    release = setup_numeric_text_property_definition('release')
    text = setup_text_property_definition('text')
    negated_release = setup_formula_property_definition('negated release', "- release")

    negated_release.change_formula_to('text')
    assert_match(/Property #{'text'.bold} is not numeric/, negated_release.errors.full_messages.join)
  end

  def test_should_fail_gracefully_when_changing_formula_value_to_use_a_non_numeric_property
    #expect to see some stack trace from racc on stdout
    release = setup_numeric_text_property_definition('release')
    negated_release = setup_formula_property_definition('negated release', "- release")

    negated_release.change_formula_to('+(+) release')
    assert_match(/The formula is not well formed/, negated_release.errors.full_messages.join)
  end

  def test_should_only_update_formulae_relevant_to_current_card_type_when_saving
    release = setup_numeric_text_property_definition('Release')
    next_release = setup_formula_property_definition('Next Release', 'Release + 1')
    previous_release = setup_formula_property_definition('Previous Release', 'Release - 1')


    bug_type = @project.card_types.create!(:name => 'Bug')
    story_type = @project.card_types.create!(:name => 'Story')
    @project.card_types.find_by_name('Card').destroy

    bug_type.property_definitions = [release, previous_release]
    bug_type.save!

    story_type.property_definitions = [release, next_release]
    story_type.save!

    bug = @project.cards.create!(:name => 'Next Release Advisory', :card_type_name => 'Bug', :cp_release => '2')
    story = @project.cards.create!(:name => 'Next Release Advisory', :card_type_name => 'Story', :cp_release => '2')

    next_release.change_formula_to('Release + 100')
    assert_equal story.reload.find_version(2).cp_previous_release, story.reload.find_version(1).cp_previous_release
  end

  def test_should_be_able_to_use_date_properties_in_formulas
    setup_date_property_definition("your mom's release date")
    formula_property = create_formula_property_definition(@project, 'formula_1', "\"your mom's release date\" + 1")

    assert formula_property.valid?
  end

  def test_should_be_able_to_add_scalars_to_date_properties_in_formulas
    @project.update_attributes(:date_format => Date::DAY_LONG_MONTH_YEAR)
    momma = setup_date_property_definition("your mom's release date")
    formula_property = setup_formula_property_definition('formula_1', "\"your mom's release date\" + 1")
    formula_property.project.reload

    card = create_card!(:name => 'card one', :card_type => @project.card_types.first)
    momma.update_card(card, '2006-10-02')
    card.save!
    card.reload

    assert_equal '03 Oct 2006', formula_property.value(card)
  end

  def test_should_be_able_to_add_scalars_to_date_properties_using_sql_update
    @project.update_attributes(:date_format => Date::DAY_LONG_MONTH_YEAR)
    momma = setup_date_property_definition("your mom's release date")

    card = create_card!(:name => 'card one', :card_type => @project.card_types.first)
    momma.update_card(card, '2006-10-02')
    card.save!

    formula_property = setup_formula_property_definition('formula_1', "\"your mom's release date\" + 1")
    formula_property.update_all_cards

    assert_equal '03 Oct 2006', formula_property.value(card.reload)
  end

  def test_validate_creates_appropriate_error_message_for_an_invalid_operation
    setup_date_property_definition 'start date'
    formula_property = create_formula_property_definition(@project, 'formula', "2 - 'start date'")
    formula_property.validate

    assert_equal ["The expression #{'2 - \'start date\''.bold} is invalid because a date (#{'\'start date\''.bold}) cannot be subtracted from a number (#{2.bold}). The supported operation is addition."], formula_property.errors.full_messages
  end

  def test_formula_that_evaluates_to_a_date_but_is_used_in_an_aggregate_property_is_not_valid
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      formula_property = setup_formula_property_definition('formula def', '1 + 2')
      type_story.add_property_definition(formula_property)
      type_story.save!

      iteration_size = setup_aggregate_property_definition('size',
                                                            AggregateType::SUM,
                                                            formula_property,
                                                            configuration.id,
                                                            type_iteration.id,
                                                            AggregateScope::ALL_DESCENDANTS)

      iteration_size = setup_aggregate_property_definition('avg',
                                                            AggregateType::AVG,
                                                            formula_property,
                                                            configuration.id,
                                                            type_iteration.id,
                                                            AggregateScope::ALL_DESCENDANTS)

      somedate = setup_date_property_definition 'somedate'
      formula_property.formula = "somedate + 1"
      formula_property.validate

      assert_equal ["#{'formula def'.bold} cannot have a formula that results in a date, as it is being used in the following aggregate properties: #{'avg'.bold}, #{'size'.bold}"], formula_property.errors.full_messages
    end
  end

  def test_uses_one_of_method
    start_date = setup_date_property_definition 'start date'
    end_date = setup_date_property_definition 'end date'
    formula_property = setup_formula_property_definition('formula', "2 + 'start date'")

    assert formula_property.uses_one_of?([end_date, start_date])
  end

  def test_should_reset_card_values_to_null_when_formula_output_type_changes_make_old_card_values_invalid
    start_date = setup_date_property_definition 'start date'
    end_date = setup_date_property_definition 'end date'

    @project.reload
    card_one = @project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp_start_date => Clock.today, :cp_end_date => (Clock.today + 3))
    card_two = @project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp_start_date => Clock.today)

    @project.reload
    formula_property = setup_formula_property_definition('formula', "2 + 'start date'")
    formula_property.update_all_cards
    assert_equal '06 Oct 2003', formula_property.value(card_one.reload)
    assert_equal '06 Oct 2003', formula_property.value(card_two.reload)

    formula_property.change_formula_to("'end date' - 'start date'")
    assert_equal 3, formula_property.value(card_one.reload)
    assert_equal nil, formula_property.value(card_two.reload)
  end

  def test_change_formula_should_support_bracket
    start_date = setup_date_property_definition 'start date'
    end_date = setup_date_property_definition 'end date'

    @project.reload
    card_one = @project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp_start_date => Clock.today, :cp_end_date => (Clock.today + 3))
    card_two = @project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp_start_date => Clock.today)

    @project.reload
    formula_property = setup_formula_property_definition('formula', "'end date' - 'start date'")
    card_one.card_type.reload

    formula_property.update_all_cards
    assert_equal 3, formula_property.value(card_one.reload)
    assert_equal nil, formula_property.value(card_two.reload)

    assert formula_property.change_formula_to("'end date' + ('end date' - 'start date')")
    assert_equal '10 Oct 2003', formula_property.value(card_one.reload)
    assert_equal nil, formula_property.value(card_two.reload)

    @project.all_property_definitions.reload

    end_date.update_card(card_one, Clock.today + 4)
    card_one.save!
    assert_equal '12 Oct 2003', formula_property.value(card_one.reload)
  end

  def test_changing_output_type_of_one_formula_property_does_not_impact_another
    start_date = setup_date_property_definition 'start date'
    end_date = setup_date_property_definition 'end date'
    fixed_cost = setup_numeric_text_property_definition 'fixed cost'
    working_days = setup_formula_property_definition('working days', "'end date' - 'start date'")
    effort = setup_formula_property_definition('effort', "'fixed cost' + ('end date' - 'start date')")

    @project.reload
    card_one = @project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp_start_date => Clock.today, :cp_end_date => (Clock.today + 3), :cp_fixed_cost => '3')
    card_two = @project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp_start_date => Clock.today - 1, :cp_end_date => (Clock.today + 2))

    assert_equal 3, working_days.value(card_one.reload)
    assert_equal 6, effort.value(card_one.reload)

    assert_equal 3, working_days.value(card_two.reload)
    assert_equal nil, effort.value(card_two.reload)

    effort.change_formula_to("2 + 'start date'")
    assert_equal 3, working_days.value(card_one.reload)
    assert_equal '06 Oct 2003', effort.value(card_one.reload)

    assert_equal 3, working_days.value(card_two.reload)
    assert_equal '05 Oct 2003', effort.value(card_two.reload)
  end

  #bug 3016
  def test_should_create_card_history_when_nothing_changed_on_card
    release = setup_numeric_text_property_definition('Release')
    next_release = setup_formula_property_definition('Next Release', 'Release + 1')

    story_type = @project.card_types.create!(:name => 'Story')
    @project.card_types.find_by_name('Card').destroy

    story_type.property_definitions = [release, next_release]
    story_type.save!

    story = @project.cards.create!(:name => 'Next Release Advisory', :card_type_name => 'Story', :cp_release => '2')
    story.cp_release = '5'
    story.save!

    assert_equal 2, story.version

    @project.all_property_definitions.reload
    next_release.change_formula_to("Release + 2")
    @project.all_property_definitions.reload

    story.reload
    assert_equal 3, story.version

    reload_story = @project.cards.find_by_name(story.name)
    reload_story.cp_release = '5'
    reload_story.save!
    assert_equal 3, story.version
  end

  # bug 2969 and 2976
  def test_change_in_formula_recomputes_values_even_when_component_property_is_not_set
    size = setup_numeric_property_definition('size', [1, 2, 3])
    size_times_four = setup_formula_property_definition('size times four', '3 + 2')

    card_one = @project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp_size => '1')
    card_two = @project.cards.create!(:name => 'card two', :card_type_name => 'Card', :cp_size => nil)

    assert_equal 5, size_times_four.value(card_one)
    assert_equal 5, size_times_four.value(card_two)

    size_times_four.change_formula_to('size * 4')

    assert_equal 4, size_times_four.value(card_one.reload)
    assert_equal nil, size_times_four.value(card_two.reload)
  end

  def test_formula_property_definitions_with_null_is_zero_set_replace_numeric_values_of_null_with_zero
    size = setup_numeric_property_definition('size', [1, 2, 3])
    size_plus_one_formula = setup_formula_property_definition('size plus one', 'size + 1')
    size_plus_one_formula.update_attributes(:null_is_zero => true)
    @project.reload
    card = @project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp_size => nil)
    assert_equal 1, size_plus_one_formula.value(card)
  end

  def test_changing_nulls_as_zeros_should_only_create_versions_for_affected_cards
    size = setup_numeric_property_definition('size', [1, 2, 3])
    size_plus_one_formula = setup_formula_property_definition('size plus one', 'size + 1')
    @project.reload

    card_with_not_set_size = @project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp_size => nil)
    card_with_size = @project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp_size => 1)
    size_plus_one_formula.update_attributes(:null_is_zero => true)
    assert_equal 2, size_plus_one_formula.value(card_with_size.reload)

    assert_equal "(not set) changed from being evaluated as (not set) to 0 for size plus one.", card_with_not_set_size.versions.last.system_generated_comment
    assert_not_equal "(not set) changed from being evaluated as (not set) to 0 for size plus one.", card_with_size.versions.last.system_generated_comment
  end

  # bug 12220 Fred Bang is not happy
  def test_changing_nulls_as_zero_and_property_def_name_should_afftect_card
    size = setup_numeric_property_definition('size', [1, 2, 3])
    size_plus_one_formula = setup_formula_property_definition('size plus one', 'size + 1')
    size_plus_one_formula.update_attributes(:null_is_zero => false)
    @project.reload
    card = @project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp_size => nil)
    assert_equal nil, size_plus_one_formula.value(card.reload)
    size_plus_one_formula.update_attributes(:name => 'size plus 1', :null_is_zero => true)
    assert_equal 1, size_plus_one_formula.value(card.reload)
  end

  def test_non_numeric_formulae_ignore_null_is_zero_property_definitions
    @project.update_attributes(:date_format => Date::DAY_LONG_MONTH_YEAR)
    momma_prop =setup_date_property_definition("your mom's release date")
    mommas_formula = setup_formula_property_definition('formula_1', "\"your mom's release date\" + 1")
    mommas_formula.update_attributes(:null_is_zero => true)
    @project.reload
    card = @project.cards.create!(:name => 'card one', :card_type_name => 'Card')
    card.update_properties(momma_prop => nil)
    assert_equal nil, card.reload.cp_formula_1
  end

  def test_numeric_plus_date_property_respect_null_is_zero
    @project.update_attributes(:date_format => Date::DAY_LONG_MONTH_YEAR)
    date_prop =setup_date_property_definition("date")
    numeric_prop = setup_numeric_property_definition('size', [1, 2, 3])
    formula = setup_formula_property_definition('formula_1', %Q{"date" + "size"})
    formula.update_attributes(:null_is_zero => true)
    @project.reload
    card = @project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp_date =>Clock.now, :cp_size => nil)
    assert_equal "2003-10-04", card.reload.cp_formula_1
  end

  def test_update_null_is_zero_should_raise_error_except_on_formula_property_definitions
    date_prop = setup_date_property_definition("due date")
    date_prop.update_attributes(:null_is_zero => true)
    assert_match /is only valid for a formula/, date_prop.errors.full_messages.join
    assert !date_prop.reload.null_is_zero?
  end

  # bug 3191
  def test_addition_of_card_type_to_property_definition_should_compute_formula_values_for_new_type
    size = setup_numeric_property_definition('size', [1, 2, 3])
    size_times_four = setup_formula_property_definition('size times four', 'size * 4')

    card_type = @project.card_types.find_by_name('Card')
    bug_type = @project.card_types.create!(:name => 'bug')
    bug_type.property_definitions = [size]
    bug_type.save!

    bug_one = @project.cards.create!(:name => 'bug one', :card_type_name => 'bug', :cp_size => '1')
    size_times_four.card_types = [card_type, bug_type]
    assert_equal 4, size_times_four.value(bug_one.reload)
  end

  # bug 3191
  def test_addition_of_property_definition_to_card_type_should_compute_formula_values_for_new_type
    size = setup_numeric_property_definition('size', [1, 2, 3])
    size_times_four = setup_formula_property_definition('size times four', 'size * 4')

    card_type = @project.card_types.find_by_name('Card')
    bug_type = @project.card_types.create!(:name => 'bug')
    bug_type.property_definitions = [size]
    bug_type.save!

    bug_one = @project.cards.create!(:name => 'bug one', :card_type_name => 'bug', :cp_size => '1')
    bug_type.add_property_definition(size_times_four)
    assert_equal 4, size_times_four.value(bug_one.reload)
  end

  # bug 3034
  def test_can_add_negative_number_to_a_date_property
    @project.update_attributes(:date_format => Date::DAY_LONG_MONTH_YEAR)
    start_date = setup_date_property_definition("start_date")
    formula_property = setup_formula_property_definition('formula_1', "start_date + (-2)")

    formula_property.project.reload

    card = create_card!(:name => 'card one', :card_type => @project.card_types.first)
    start_date.update_card(card, '2006-10-03')
    card.save!
    card.reload
    assert_equal '01 Oct 2006', formula_property.value(card)
  end

  # bug3372
  def test_init_value_for_card_selection
    start_on = setup_date_property_definition('start on')
    date_formula_property = setup_formula_property_definition('date formula', "'start on' + 2")
    card = create_card!(:name => 'I am card')
    start_on.update_card(card, '2008-06-03')
    card.save!
    card.reload

    card_selection = CardSelection.new(@project, [card])
    assert_equal ["05 Jun 2008", "2008-06-05"], card_selection.value_for(date_formula_property)
  end

  # bug 3039
  def test_rename_property_to_have_a_single_quote_will_put_double_quotes_around_it_in_formula
    size = setup_numeric_property_definition("size", [1, 2, 3])
    card = @project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp_size => '2')
    formula_property = setup_formula_property_definition('formula', "size + 3")

    size.name = "'size'"
    size.save!

    assert_equal "\"'size'\" + 3", formula_property.reload.attributes['formula']
  end

  # bug 3039
  def test_rename_property_to_have_a_parenthesis_will_put_quotes_around_it_in_formula
    size = setup_numeric_property_definition("size", [1, 2, 3])
    card = @project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp_size => '2')
    formula_property = setup_formula_property_definition('formula', "size + 3")

    size.name = "(size)"
    size.save!

    assert_equal "'(size)' + 3", formula_property.reload.attributes['formula']
  end

  # bug 4620
  def test_rename_property_to_a_number_will_put_quotes_around_it_in_formula
    size = setup_numeric_property_definition("size", [1, 2, 3])
    card = @project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp_size => '2')
    formula_property = setup_formula_property_definition('formula', "size + 3")

    formula_property.update_all_cards
    assert_equal 5, formula_property.value(card.reload)

    size.name = "100"
    size.save!
    @project.reload

    assert_equal "'100' + 3", formula_property.reload.attributes['formula']
    assert_equal 5, formula_property.value(card.reload)
  end

  # bug 4527 and 4600
  def test_rename_property_to_have_mathematical_characters_will_put_single_quotes_around_it_in_formula
    size = setup_numeric_property_definition("size", [1, 2, 3])
    card = @project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp_size => '2')
    formula_property = setup_formula_property_definition('formula', "size + 3")

    size.name = 'size/estimate'
    size.save!
    assert_equal "'size/estimate' + 3", formula_property.reload.attributes['formula']

    size.name = "'size/estimate'"
    size.save!
    assert_equal "\"'size/estimate'\" + 3", formula_property.reload.attributes['formula']

    size.name = "hi+estimate"
    size.save!
    assert_equal "'hi+estimate' + 3", formula_property.reload.attributes['formula']

    size.name = "hi-estimate"
    size.save!
    assert_equal "'hi-estimate' + 3", formula_property.reload.attributes['formula']

    size.name = "hi*estimate"
    size.save!
    assert_equal "'hi*estimate' + 3", formula_property.reload.attributes['formula']

    size.name = "hi(estimate"
    size.save!
    assert_equal "'hi(estimate' + 3", formula_property.reload.attributes['formula']

    size.name = "hi)estimate"
    size.save!
    assert_equal "'hi)estimate' + 3", formula_property.reload.attributes['formula']
  end

  # bug 4621
  def test_rename_property_to_have_both_single_quotes_will_escape_those_quotes_in_the_formula
    size = setup_numeric_property_definition("size", [1, 2, 3])
    girth = setup_numeric_property_definition("girth", [1, 2, 3])
    weight = setup_numeric_property_definition("weight", [1, 2, 3])

    card = @project.cards.create!(:name => 'card one', :card_type_name => 'Card', :cp_size => '2')
    size_formula = setup_formula_property_definition('size formula', "size + 3")
    girth_formula = setup_formula_property_definition('girth formula', %{'girth' + 5})
    weight_formula = setup_formula_property_definition('weight formula', %{weight + 6})

    size.name = %{size'hellothere}
    size.save!
    assert_equal %{"size'hellothere" + 3}, size_formula.reload.attributes['formula']

    girth.name = %{girth'yeah}
    girth.save!
    assert_equal %{"girth'yeah" + 5}, girth_formula.reload.attributes['formula']

    weight.name = %{we'i ght}
    weight.save!
    assert_equal %{"we'i ght" + 6}, weight_formula.reload.attributes['formula']
  end

  def test_should_return_empty_for_values_if_column_is_missing
    two_thirds = setup_formula_property_definition('two thirds', '2 / 3')
    @project.reload
    card = @project.cards.create!(:name => 'Card Two', :card_type_name => @project.card_types.first.name)

    @project.card_schema.remove_column('cp_two_thirds')
    assert_equal [], two_thirds.values
  end

  def test_should_record_dependant_formulas_on_aggregate_when_save_formula
    @type_release, @type_iteration, @type_story = init_planning_tree_types
    @card_tree = create_three_level_tree
    init_three_level_tree(@card_tree.configuration)
    aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::COUNT, nil, @card_tree.configuration.id, @type_release.id, @type_iteration)
    @card_tree.configuration.reload
    john_formula = setup_formula_property_definition('john', "'#{aggregate_property_definition.name}' + 1")
    chester_formula = setup_formula_property_definition('chester', "2 + '#{aggregate_property_definition.name}'")

    assert_equal [john_formula.id, chester_formula.id].sort, aggregate_property_definition.reload.dependant_formulas.sort
  end

  def test_should_record_dependant_formulas_on_aggregate_when_save_formula_without_duplicates
    @type_release, @type_iteration, @type_story = init_planning_tree_types
    @card_tree = create_three_level_tree
    init_three_level_tree(@card_tree.configuration)
    aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::COUNT, nil, @card_tree.configuration.id, @type_release.id, @type_iteration)
    @card_tree.configuration.reload
    john_formula = setup_formula_property_definition('john', "'#{aggregate_property_definition.name}' + 1")
    john_formula.card_types = [@type_release]
    john_formula.save!

    assert_equal [john_formula.id], aggregate_property_definition.reload.dependant_formulas
  end

  def test_should_remove_dependant_formulas_on_aggregate_when_formulas_no_longer_have_that_aggregate
    @type_release, @type_iteration, @type_story = init_planning_tree_types
    @card_tree = create_three_level_tree
    init_three_level_tree(@card_tree.configuration)
    aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::COUNT, nil, @card_tree.configuration.id, @type_release.id, @type_iteration)
    @card_tree.configuration.reload
    john_formula = setup_formula_property_definition('john', "'#{aggregate_property_definition.name}' + 1")
    chester_formula = setup_formula_property_definition('chester', "2 + '#{aggregate_property_definition.name}'")

    chester_formula.formula = "2 + 1"
    chester_formula.save!

    assert_equal [john_formula.id], aggregate_property_definition.reload.dependant_formulas
  end

  def test_should_remove_dependant_formulas_on_aggregate_when_formula_is_deleted
    @type_release, @type_iteration, @type_story = init_planning_tree_types
    @card_tree = create_three_level_tree
    init_three_level_tree(@card_tree.configuration)
    aggregate_property_definition = setup_aggregate_property_definition('aggregate name', AggregateType::COUNT, nil, @card_tree.configuration.id, @type_release.id, @type_iteration)
    @card_tree.configuration.reload
    john_formula = setup_formula_property_definition('john', "'#{aggregate_property_definition.name}' + 1")
    chester_formula = setup_formula_property_definition('chester', "2 + '#{aggregate_property_definition.name}'")

    chester_formula.destroy

    assert_equal [john_formula.id], aggregate_property_definition.reload.dependant_formulas
  end

  def test_affected_formulas_when_disassociate_card_types
    with_new_project do |project|
      estimate = setup_numeric_property_definition('estimate', [1,4,8])
      type_story = project.card_types.create(:name => "Story")
      type_card = project.card_types.find_by_name("card")
      estimate.card_types = [type_card, type_story]
      estimate.save!

      double_estimate = setup_formula_property_definition('double estimate', "estimate * 2")
      double_estimate.card_types = [type_story]
      double_estimate.save!
      assert_equal [], estimate.affected_formulas_when_disassociate_card_types([type_card])
      assert_equal [double_estimate], estimate.affected_formulas_when_disassociate_card_types([type_story])
    end
  end

  def test_property_values_description_should_be_formula
    one_third = setup_formula_property_definition('one third', '1/3')
    assert_equal "Formula", one_third.property_values_description
  end

  def test_should_be_treated_as_date_property_when_generate_query_sql_when_calculated_type_is_date
    setup_date_property_definition("release_date")
    setup_date_property_definition("start_date")

    assert_false setup_formula_property_definition('one third', '1/3').date?
    assert setup_formula_property_definition("release_release_date", 'release_date + 15').date?
    assert_false setup_formula_property_definition("dayused", 'release_date - start_date').date?
  end

  private

  def create_formula_property_definition(project, name, formula)
    FormulaPropertyDefinition.new(:project_id => project.id, :name => name, :formula => formula)
  end

end
