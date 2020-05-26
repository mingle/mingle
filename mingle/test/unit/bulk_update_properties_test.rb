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
class BulkUpdatePropertiesTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    @project = card_selection_project
    @project.activate
    @cards = @project.cards
    login_as_member
  end

  def test_update_properties_applies_system_generated_comment_to_versions
    updater = Bulk::BulkUpdateProperties.new(@project, CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name})"))
    updater.update_properties({'Iteration' => '2'}, :comment => nil, :system_generated_comment => "this is my system generated comment")

    @cards.each {|c| assert_equal "this is my system generated comment", c.versions.last.system_generated_comment }
  end

  def test_change_version_option
    card = @cards.first
    number_of_versions = card.versions.size
    last_card_version = card.versions.last.version

    assert_nil card.cp_iteration
    assert_nil card.versions.last.cp_iteration

    updater = Bulk::BulkUpdateProperties.new(@project, CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name})"))
    updater.update_properties({'Iteration' => '2'}, :change_version => last_card_version)
    card.reload

    assert_equal number_of_versions, card.versions.size
    assert_equal last_card_version, card.versions.last.version
    assert_equal '2', card.cp_iteration
    assert_equal '2', card.versions.last.cp_iteration
  end

  def test_update_properties_can_be_instructed_to_increment_caching_stamp_on_rows_that_get_updated
    card = @cards.first
    original_caching_stamp = card.caching_stamp
    updater = Bulk::BulkUpdateProperties.new @project, CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name})")
    updater.update_properties({'Iteration' => '2'})
    assert_equal original_caching_stamp, card.reload.caching_stamp

    updater.update_properties({'Iteration' => '3'}, :increment_caching_stamp => true)
    assert_not_equal original_caching_stamp, card.reload.caching_stamp
  end

  # it was a big performance gain to avoid using all_property_definitions when calling update_properties from compute_aggregate_request.rb
  def test_all_property_definitions_is_not_called_when_options_match_the_ones_compute_aggregate_request_uses
    @project.instance_eval do
      def all_property_definitions
        if @calls
          @calls += 1
        else
          @calls = 1
        end
        super
      end

      def get_number_of_calls
        @calls
      end
    end

    updater = Bulk::BulkUpdateProperties.new(@project, CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name})"))
    updater.update_properties({'Iteration' => '2'}, {:bypass_update_aggregates => true,
                                                     :bypass_versioning => true,
                                                     :bypass_update_properties_validation => true
                                                    })

    assert_nil @project.get_number_of_calls
  end

  # bug 7019
  def test_update_properties_should_compute_formulas_that_add_a_date_property_to_a_numeric_property_with_decimal_values
    with_new_project do |project|
      property_num = setup_numeric_property_definition('num', [1])
      property_date = setup_date_property_definition('date')
      property_formula = setup_formula_property_definition('formula', 'date + num')

      card = project.cards.create!(:name => 'card', :card_type_name => 'Card', :cp_num => 1, :cp_date => '07 Sep 2001')
      assert_equal "08 Sep 2001", property_formula.value(card)

      updater = Bulk::BulkUpdateProperties.new(project, CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name})"))
      updater.update_properties('num' => '2.00')

      assert_equal "09 Sep 2001", property_formula.value(card.reload)
    end
  end

  def test_formula_property_definitions_to_update_are_the_ones_on_the_card_types_of_selected_cards
    with_new_project do |project|
      type_card = project.card_types.first
      type_bug = project.card_types.create!(:name => 'bug')

      num = setup_numeric_property_definition('num', [1, 2])
      card_formula = setup_formula_property_definition('card formula', '2 + 3')
      bug_formula = setup_formula_property_definition('bug formula', '2 + 3')

      type_card.property_definitions = [num, card_formula]
      type_bug.property_definitions = [num, bug_formula]
      [type_card, type_bug].each(&:save!)

      card = project.cards.create!(:name => 'card', :card_type_name => 'Card')
      bug = project.cards.create!(:name => 'bug', :card_type_name => 'bug')

      affected_formula_properties = Bulk::FormulaPropertiesToUpdate.new(project, Bulk::PropertyAndValues.new(project, :num => 1), CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name} WHERE LOWER(card_type_name) = 'card')"))
      assert_equal ['card formula'], affected_formula_properties.property_definitions.map(&:name).sort

      affected_formula_properties = Bulk::FormulaPropertiesToUpdate.new(project, Bulk::PropertyAndValues.new(project, :num => 1), CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name})"))
      assert_equal ['bug formula', 'card formula'], affected_formula_properties.property_definitions.map(&:name).sort
    end
  end

  def test_formula_property_definitions_to_update_are_determined_upon_creation_of_object
    with_new_project do |project|
      type_card = project.card_types.first
      type_bug = project.card_types.create!(:name => 'bug')

      num = setup_numeric_property_definition('num', [1, 2])
      card_formula = setup_formula_property_definition('card formula', '2 + 3')

      type_card.property_definitions = [num, card_formula]
      type_bug.property_definitions = [num]
      [type_card, type_bug].each(&:save!)

      card = project.cards.create!(:name => 'card', :card_type_name => 'Card')

      # affected formula at this point should be 'card formula', as it is on type card
      affected_formula_properties = Bulk::FormulaPropertiesToUpdate.new(project, Bulk::PropertyAndValues.new(project, :num => 1), CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name})"))

      # change card type of card_formula so that, if we determined affected formula properties afterwards, there would be none
      card_formula.card_types = [type_bug]
      card_formula.save!

      assert_equal ['card formula'], affected_formula_properties.property_definitions.map(&:name)
    end
  end

  # bug 7033
  def test_if_only_bulk_updating_aggregates_then_only_recompute_formulas_that_use_this_aggregate
    with_new_project do |project|
      @type_release, @type_iteration, @type_story = init_planning_tree_types
      @card_tree = create_three_level_tree
      init_three_level_tree(@card_tree.configuration)
      aggregate_property_definition = setup_aggregate_property_definition('aggregate', AggregateType::COUNT, nil, @card_tree.configuration.id, @type_release.id, @type_iteration)
      @card_tree.configuration.reload

      formula = setup_formula_property_definition('formula', "'#{aggregate_property_definition.name}' + 1")
      formula.card_types = [@type_release]
      formula.save!

      formula_not_using_aggregate = setup_formula_property_definition('formula not using aggregate', "2 + 1")
      formula_not_using_aggregate.card_types = [@type_release]
      formula_not_using_aggregate.save!

      aggregate_property_definition.update_cards

      @release_card = project.cards.find_by_name('release1')
      properties_to_update = Bulk::PropertyAndValues.new(project, :aggregate => '10')
      affected_formula_properties = Bulk::FormulaPropertiesToUpdate.new(project, properties_to_update, CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name} WHERE id = #{@release_card.id})"))
      assert_equal ['formula'], affected_formula_properties.property_definitions.map(&:name)
    end
  end

  # bug 7254
  def test_can_bulk_update_a_date_property_to_TODAY_when_used_in_a_formula
    with_new_project do |project|
      tomorrow = Date.today + 1

      cp_started_on = setup_date_property_definition('started on')
      cp_ended_on = setup_date_property_definition('ended on')
      cp_formula = setup_formula_property_definition('formula', "'ended on' - 'started on'")

      card = project.cards.create!(:name => 'card', :card_type_name => 'Card')
      cp_ended_on.update_card(card, tomorrow)
      card.save!

      updater = Bulk::BulkUpdateProperties.new(project, CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name})"))
      updater.update_properties('started on' => PropertyType::DateType::TODAY)

      assert_equal 1, cp_formula.value(card.reload)
    end
  end

  # bug 8042
  def test_can_bulk_update_a_date_property_that_is_used_in_a_formula
    with_new_project do |project|
      cp_started_on = setup_date_property_definition('started on')
      cp_formula = setup_formula_property_definition('formula', "'started on' + 1")

      card = project.cards.create!(:name => 'card', :card_type_name => 'Card')

      updater = Bulk::BulkUpdateProperties.new(project, CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name})"))
      updater.update_properties('started on' => "10 Nov 2009")

      assert_equal "11 Nov 2009", cp_formula.value(card.reload)
    end
  end

  def test_date_formula_properties_are_computed_with_correct_rounding_when_involving_decimal_numeric_primitives
    with_new_project do |project|
      cp_start_date = setup_date_property_definition('start date')

      cp_formula_add_and_round_down = setup_formula_property_definition('f1', "'start date' + 2.1")
      cp_formula_add_and_round_up = setup_formula_property_definition('f2', "2.6 + 'start date'")
      cp_formula_subtract_and_round_down = setup_formula_property_definition('f3', "'start date' - 2.1")
      cp_formula_subtract_and_round_up = setup_formula_property_definition('f4', "'start date' - 2.6")

      card = project.cards.create!(:name => 'card', :card_type_name => 'Card')

      updater = Bulk::BulkUpdateProperties.new(project, CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name})"))
      updater.update_properties('start date' => "20 Dec 2009")

      assert_equal "22 Dec 2009", cp_formula_add_and_round_down.value(card.reload)
      assert_equal "23 Dec 2009", cp_formula_add_and_round_up.value(card)
      assert_equal "18 Dec 2009", cp_formula_subtract_and_round_down.value(card)
      assert_equal "17 Dec 2009", cp_formula_subtract_and_round_up.value(card)
    end
  end

  def test_date_formula_properties_are_computed_with_correct_rounding_when_involving_decimal_numeric_properties
    with_new_project do |project|
      cp_start_date = setup_date_property_definition('start date')
      cp_size = setup_managed_number_list_definition('size', [1, 2, 3])

      cp_formula_add = setup_formula_property_definition('f1', "'start date' + size")
      cp_formula_reverse_add = setup_formula_property_definition('f2', "size + 'start date'")
      cp_formula_subtract = setup_formula_property_definition('f3', "'start date' - size")

      card_one = project.cards.create!(:name => 'card', :card_type_name => 'Card', :cp_size => '2.1')
      card_two = project.cards.create!(:name => 'card', :card_type_name => 'Card', :cp_size => '2.6')

      updater = Bulk::BulkUpdateProperties.new(project, CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name})"))
      updater.update_properties('start date' => "20 Dec 2009")

      assert_equal "22 Dec 2009", cp_formula_add.value(card_one.reload)
      assert_equal "23 Dec 2009", cp_formula_add.value(card_two.reload)
      assert_equal "22 Dec 2009", cp_formula_reverse_add.value(card_one)
      assert_equal "23 Dec 2009", cp_formula_reverse_add.value(card_two)
      assert_equal "18 Dec 2009", cp_formula_subtract.value(card_one)
      assert_equal "17 Dec 2009", cp_formula_subtract.value(card_two)
    end
  end

  def test_date_formula_properties_are_computed_with_correct_rounding_when_involving_expressions_that_result_in_decimal_value
    with_new_project do |project|
      cp_start_date = setup_date_property_definition('start date')
      cp_size = setup_managed_number_list_definition('size', [1, 2, 3])
      cp_estimate = setup_managed_number_list_definition('estimate', [1, 2, 3])

      card = project.cards.create!(:name => 'card', :card_type_name => 'Card', :cp_size => '5', :cp_estimate => '2.32')

      cp_f1 = setup_formula_property_definition('f1', "'start date' + (size / 2.5)")
      cp_f2 = setup_formula_property_definition('f2', "'start date' - (size / 2.5)")
      cp_f3 = setup_formula_property_definition('f3', "(size / estimate) + 'start date'") # for our card, 5 / 2.32 = 2.15517, which rounds down to 2
      cp_f4 = setup_formula_property_definition('f4', "'start date' - (size / estimate)") # for our card, 5 / 2.32 = 2.15517, which rounds down to 2
      cp_f5 = setup_formula_property_definition('f5', "'start date' + (estimate * 2)")    # for our card, 2.32 * 2 = 4.64, which rounds to 5
      cp_f6 = setup_formula_property_definition('f6', "'start date' - (estimate * 2)")    # for our card, 2.32 * 2 = 4.64, which rounds to 5

      updater = Bulk::BulkUpdateProperties.new(project, CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name})"))
      updater.update_properties('start date' => "20 Dec 2009")
      card.reload

      assert_equal "22 Dec 2009", cp_f1.value(card)
      assert_equal "18 Dec 2009", cp_f2.value(card)
      assert_equal "22 Dec 2009", cp_f3.value(card)
      assert_equal "18 Dec 2009", cp_f4.value(card)
      assert_equal "25 Dec 2009", cp_f5.value(card)
      assert_equal "15 Dec 2009", cp_f6.value(card)
    end
  end

  def test_can_bulk_update_a_date_property
    with_new_project do |project|
      cp_somedate = setup_date_property_definition('somedate')

      card_no_change = project.cards.create!(:name => 'card no change', :card_type_name => 'Card', :cp_somedate => '10 Nov 2009')
      card_change = project.cards.create!(:name => 'card change', :card_type_name => 'Card')

      updater = Bulk::BulkUpdateProperties.new(project, CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name})"))
      updater.update_properties('somedate' => "10 Nov 2009")

      assert_equal "10 Nov 2009", cp_somedate.value(card_no_change.reload).strftime("%d %b %Y")
      assert_equal "10 Nov 2009", cp_somedate.value(card_change.reload).strftime("%d %b %Y")

      assert_equal 1, card_no_change.version
      assert_equal 2, card_change.version

      assert_equal 1, card_no_change.versions.count
      assert_equal 2, card_change.versions.count
    end
  end

  def test_property_and_values_should_tell_us_properties_being_set_to_nil
    property_and_values = Bulk::PropertyAndValues.new(@project, :status => nil, :priority => 'high')
    assert_equal ['Status'], property_and_values.property_definitions_being_set_to_nil.map(&:name)
  end

  def test_property_and_values_will_ignore_mixed_values
    property_and_values = Bulk::PropertyAndValues.new(@project, :status => nil, :priority => CardSelection::MIXED_VALUE)
    assert_equal ['Status'], property_and_values.property_definitions.map(&:name)
  end

  def test_property_and_values_accepts_both_property_definitions_and_names_as_keys
    pd_status = @project.find_property_definition('status')

    property_and_values = Bulk::PropertyAndValues.new(@project, :status => 'open')
    assert_equal ['Status'], property_and_values.property_definitions.map(&:name)

    property_and_values = Bulk::PropertyAndValues.new(@project, pd_status => 'open')
    assert_equal ['Status'], property_and_values.property_definitions.map(&:name)
  end

  def test_property_and_values_should_tell_us_when_it_only_involves_aggregates
    with_three_level_tree_project do |project|
      property_and_values = Bulk::PropertyAndValues.new(@project, :'Sum of size' => 10)
      assert property_and_values.only_involving_aggregates?

      property_and_values = Bulk::PropertyAndValues.new(@project, :'Sum of size' => 10, :status => 'open')
      assert !property_and_values.only_involving_aggregates?
    end
  end

  def test_property_and_values_should_create_map_from_column_names_to_sql
    property_and_values = Bulk::PropertyAndValues.new(@project, :status => 'open')
    assert_equal({ 'cp_status' => SqlHelper.sanitize_sql("?", 'open') }, property_and_values.as_setters)
  end

  # bug 8204 - note that this test was only failing on postgresql 8.3.x, not postgresql 8.2.x
  def test_can_bulk_update_a_date_to_nil_when_it_is_used_in_a_formula_with_a_numeric_property
    with_new_project do |project|
      cp_start_date = setup_date_property_definition('start date')
      cp_size = setup_numeric_property_definition('size', [1, 2, 3])
      cp_plus_formula = setup_formula_property_definition('plus formula', '"start date" + size')
      cp_reverse_plus_formula = setup_formula_property_definition('reverse plus formula', 'size + "start date"')
      cp_minus_formula = setup_formula_property_definition('minus formula', '"start date" - size')
      cp_plus_scalar_formula = setup_formula_property_definition('plus scalar formula', '"start date" + 2')

      card = project.cards.create!(:name => 'some card', :card_type_name => 'Card')
      cp_start_date.update_card(card, '10 Dec 2009')
      cp_size.update_card(card, 2)
      card.save!

      assert_equal '12 Dec 2009', cp_plus_formula.value(card)
      assert_equal '12 Dec 2009', cp_reverse_plus_formula.value(card)
      assert_equal '08 Dec 2009', cp_minus_formula.value(card)
      assert_equal '12 Dec 2009', cp_plus_scalar_formula.value(card)

      updater = Bulk::BulkUpdateProperties.new(project, CardIdCriteria.new("IN (SELECT id FROM #{Card.quoted_table_name})"))
      updater.update_properties('start date' => nil)

      assert_nil cp_plus_formula.value(card.reload)
      assert_nil cp_reverse_plus_formula.value(card)
      assert_nil cp_minus_formula.value(card)
      assert_nil cp_plus_scalar_formula.value(card)
    end
  end
end
