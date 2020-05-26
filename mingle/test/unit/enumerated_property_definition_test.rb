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
require 'card_query'

class EnumeratedPropertyDefinitionTest < ActiveSupport::TestCase

  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def test_contains_value_should_compare_by_display_value_even_with_numeric_properties
    release = @project.find_property_definition('release')
    assert release.contains_value?('1')
    assert release.contains_value?('1.00') #changing this - why is this so?, this causes #4084
    assert !release.contains_value?('64')
  end

  def test_contains_value_is_case_insensitive_for_non_numeric_properties
    status = @project.find_property_definition('status')
    assert status.contains_value?('fixed')
    assert status.contains_value?('fIxEd')
    assert !status.contains_value?('neutered')
  end

  def test_validate_card_should_use_existin_enumeration_value_when_numeric_values_are_the_same
    release = @project.find_property_definition('release')
    card = create_card!(:name => 'name', :release => '1.0')
    assert_equal '1', card.cp_release
  end

  def test_validate_card_should_pass_for_numeric_enumerations_when_adding_a_new_number_that_is_equal_to_and_formatted_the_same_as_another_number_in_enumeration
    release = @project.find_property_definition('release')
    card = create_card!(:name => 'name', :release => '1')
    assert card.errors.empty?
    card.cp_release = '1'
    release.validate_card(card)
    assert card.errors.empty?
  end

  def test_validate_card_should_pass_for_text_enumerations_even_if_case_differences_when_inline_editing_is_supported
    priority = @project.find_property_definition('Priority')
    card = create_card!(:name => 'name', :priority => 'low')
    assert card.errors.empty?
    card.cp_priority = 'lOw'
    priority.validate_card(card)
    assert card.errors.empty?
  end

  def test_should_be_able_to_update_a_card_using_a_number_with_numeric_property_definitions
    # this is mostly to accomodate existing tests, but also makes enumerated property definitions a little more robust.
    card = @project.cards.create!(:name => 'name', :card_type_name => 'card', :cp_release => '1')
    assert_equal '1', card.cp_release
  end

  def test_validate_should_fail_for_numeric_enumerations_when_a_non_numeric_value_is_used
    release = @project.find_property_definition('release')
    card = create_card!(:name => 'name', :Release => '1')
    assert card.errors.empty?
    card.cp_release = 'a'
    release.validate_card(card)
    assert !card.errors.empty?
  end

  def test_name_values
    @project.precision = 3
    iteration = @project.find_property_definition('Iteration')
    iteration.create_enumeration_value!(:value => '09')
    assert_equal [['1', '1'], ['2', '2'], ['09', '09']], iteration.name_values

    release = @project.find_property_definition('Release')
    release.create_enumeration_value!(:value => '09')
    assert_equal [['1', '1'], ['2', '2'], ['9', '9']], release.name_values
  end

  def test_should_not_allow_inline_values_beginning_and_ending_with_parenthesis
    status = @project.find_property_definition('status')
    card = create_card!(:name => 'jimmy walker', :Status => 'open')
    assert card.errors.empty?
    card.cp_status = '(dyno-mite)'
    status.validate_card(card)
    assert !card.errors.empty?

    card = create_card!(:name => 'timmy walker', :Status => 'open')
    card.cp_status = Transition::USER_INPUT_OPTIONAL
    status.validate_card(card)
    assert_equal ["Status: #{'(user input - optional)'.bold} is an invalid value. Value cannot both start with '(' and end with ')' unless it is an existing project variable which is available for this property."], card.errors.full_messages
  end

  def test_the_order_of_numeric_enumeration_values
    with_new_project do |project|
      size = setup_numeric_property_definition('size', ['3', '4.6', '4.55'])
      assert_equal ['3', '4.55', '4.6'], size.enumeration_values.collect(&:value)

      estimate = setup_numeric_property_definition('estimate', ['11', '4.6', '4.55','20', '2', '3.0','100', '101.00'])
      assert_equal ['2', '3.0', '4.55', '4.6', '11', '20', '100', '101.00'], estimate.enumeration_values.collect(&:value)
    end
  end

  def test_should_compare_numeric_properties_on_numeric_value_not_string_when_validating_existing_values_for_numeric_propertis
    with_new_project do |project|
      setup_property_definitions('size' => ['.3', '.6', '.9'])
      size = project.find_property_definition('size')
      size.update_attributes(:is_numeric => true, :restricted => true) #doing this like this to simulate how the migration would update 1.1 properties
      size.reload

      assert_equal ['.3', '.6', '.9'], size.enumeration_values.collect(&:value)
      card_one = project.cards.create(:name => 'one', :card_type_name => 'card', :cp_size => '0.6')
      assert card_one.errors.empty?
    end
  end

  def test_should_be_natural_numeric_ordering_for_numeric_enum_property
    release = @project.find_property_definition('Release')
    assert_equal "#{Card.quoted_table_name}.#{@project.connection.quote_column_name(release.column_name)}", release.quoted_comparison_column
    assert_equal 1, release.comparison_value(1)
    assert_equal 11111, release.comparison_value(11111)
  end

  def test_message_for_value_contrained
    release = OpenStruct.new({:name => 'release', :allowed_values => ['1', '2', '3'], :project => @project})
    assert_include "restricted to #{1.bold}, #{2.bold}, and #{3.bold}", EnumeratedPropertyDefinition::ValueRestrictedException.new('4', release).message

    release.allowed_values = []
    assert_include "restricted to #{'NULL'.bold}", EnumeratedPropertyDefinition::ValueRestrictedException.new('4', release).message
  end

  def test_find_enumeration_value_should_effected_by_project_precision_when_it_is_numeric_property_definition
    release = @project.find_property_definition('Release')
    release.create_enumeration_value(:value => "2.1")
    assert_equal "2.1", release.find_enumeration_value('2.1').value
    assert_equal "2.1", release.find_enumeration_value('2.10').value
    assert_equal "2.1", release.find_enumeration_value('2.095').value
  end

  def test_find_enumeration_value_should_not_effected_by_project_precision_when_it_is_text_property_definition
    iteration = @project.find_property_definition('iteration')
    iteration.create_enumeration_value(:value => "2.1")
    iteration.create_enumeration_value(:value => "2.10")
    assert_equal "2.10", iteration.find_enumeration_value('2.10').value
    assert_equal "2.1", iteration.find_enumeration_value('2.1').value
  end

  def test_value_not_copiable_when_target_property_is_locked_and_does_not_contain_card_value
    source_status, card_to_copy = nil, nil
    source_project = with_new_project do |source|
      source_status = setup_property_definitions(:status => ['fixed']).first
      card_to_copy = create_card! :name => 'card_to_copy', :status => 'fixed'
    end

    with_new_project do |target|
      target_status = setup_property_definitions(:status => ['open', 'closed']).first
      target_status.restricted = true
      target_status.save!
      assert_not source_status.value_copiable?(card_to_copy, target_status)
    end
  end

  def test_value_copiable_when_target_property_is_locked_and_does_contain_card_value
    source_status, card_to_copy = nil, nil
    source_project = with_new_project do |source|
      source_status = setup_property_definitions(:status => ['open']).first
      card_to_copy = create_card! :name => 'card_to_copy', :status => 'open'
    end
    with_new_project do |target|
      target_status = setup_property_definitions(:status => ['open', 'closed']).first
      target_status.restricted = true
      target_status.save!
      assert source_status.value_copiable?(card_to_copy, target_status)
    end
  end

  def test_value_copiable_when_target_property_is_not_locked
    source_status, card_to_copy = nil, nil
    source_project = with_new_project do |source|
      source_status = setup_property_definitions(:status => ['fixed']).first
      card_to_copy = create_card! :name => 'card_to_copy', :status => 'fixed'
    end
    with_new_project do |target|
      target_status = setup_property_definitions(:status => ['open', 'closed']).first
      assert source_status.value_copiable?(card_to_copy, target_status)
    end
  end

  def test_value_copiable_when_user_is_project_admin_even_if_target_property_is_locked_and_does_not_contain_card_value
    source_status, card_to_copy = nil, nil
    source_project = with_new_project do |source|
      source_status = setup_property_definitions(:status => ['fixed']).first
      card_to_copy = create_card! :name => 'card_to_copy', :status => 'fixed'
    end
    with_new_project do |target|
      target_status = setup_property_definitions(:status => ['open', 'closed']).first
      target_status.restricted = true
      target_status.save!
      target.add_member(User.current, :project_admin)
      assert source_status.value_copiable?(card_to_copy, target_status)
    end
  end

  def test_rename_value_updates_existing_value
    with_new_project do |project|
      prop = setup_property_definitions('office temperature' => ['cold', 'colder']).first
      prop.save!
      chilly_value = prop.rename_value('cold', 'chilly')
      assert chilly_value.errors.none?
      assert_equal ['chilly', 'colder'], prop.reload.values.map(&:name)
    end
  end

  def test_rename_value_does_not_try_to_naturally_order
    with_new_project do |project|
      prop = setup_property_definitions(:grades => ['A', 'B', 'C']).first
      prop.save!
      renamed_value = prop.rename_value('B', 'D')
      assert renamed_value.errors.none?
      assert_equal ['A', 'D', 'C'], prop.reload.values.map(&:name)
    end
  end

  def test_rename_value_that_does_not_exist_returns_object_with_errors
    with_new_project do |project|
      prop = setup_property_definitions(:grades => ['A', 'B', 'C']).first
      prop.save!
      renamed_value = prop.rename_value('Z', 'Q')
      assert renamed_value.errors.any?
      assert_equal ['A', 'B', 'C'], prop.reload.values.map(&:name)
    end
  end


end
