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

class TextPropertyDefinitionTest < ActiveSupport::TestCase  

  def setup
    login_as_member
    @project = create_project
    @project.activate
    @property = setup_text_property_definition('tipi') 
  end

  def test_should_be_able_to_set_a_text_property_on_a_card_without_creating_an_enumerated_value
    card = create_card!(:name => 'card one')
    @property.update_card(card, 'wigwam')
    card.save!
    
    assert_equal 'wigwam', card.cp_tipi
    @project.all_property_definitions.reload
    assert @project.property_definitions.collect(&:name).include?('tipi')
    assert_equal ['wigwam'], @property.values
  end
  
  def test_should_describe_type_as_text
    assert_equal 'Any text', @property.describe_type
  end  
  
  def test_should_have_display_value_identical_to_value_on_card
    card = create_card!(:name => 'card one')
    @project.reload.update_card_schema
    first_card = @project.cards.first
    @property.update_card(first_card, 'wigwam')
    assert_equal 'wigwam', first_card.display_value(@property)
  end  
  
  def test_should_invalidate_cards_if_text_is_too_long
    long_string = (1..122).to_a.collect(&:to_s).join
    card = create_card!(:name => 'card one')
    @property.update_card(card, long_string)
    @property.validate_card(card)
    assert !card.errors.empty?
  end  
  
  def test_should_invalidate_cards_if_text_is_not_numeric_when_property_is_numeric
    estimate = setup_numeric_text_property_definition('estimate')
    card = create_card!(:name => 'card one')
    estimate.update_card(card, 'abc')
    estimate.validate_card(card)
    assert !card.errors.empty?
  end  
  
  def test_should_validate_cards_if_text_is_numeric_when_property_is_numeric
    estimate = setup_numeric_text_property_definition('estimate')
    card = create_card!(:name => 'card one')
    estimate.update_card(card, '10')
    estimate.validate_card(card)
    assert card.errors.empty?
  end  

  def test_should_trim_text_values
    value = "   poodle rocking   "
    card = create_card!(:name => 'card1')
    @property.update_card(card, value)
    assert_equal 'poodle rocking', @property.value(card)
  end
  
  def test_should_not_be_numeric_even_if_all_values_are_numeric_strings_or_null
    values = [nil, '1', '-1', '1.1', '-1.1', '1.', '.1', '', ' ', ' 1.1', '1.1 ', ' 1.1 ']
    
    values.each do |value|
      card = create_card!(:name => 'card')
      @property.update_card(card, value)
      card.save!
    end
    
    assert !@property.numeric?
  end
  
  def test_should_not_be_numeric_if_not_all_values_are_numeric_strings_or_null
    card = create_card!(:name => 'card1')

    assert_not_numeric(card, 'a')
    assert_not_numeric(card, '1a')
    assert_not_numeric(card, '1a0')
    assert_not_numeric(card, '-')
    assert_not_numeric(card, '.')
    assert_not_numeric(card, '-.')
    assert_not_numeric(card, ',')
    assert_not_numeric(card, '1.x')
    assert_not_numeric(card, 'x.1')
    assert_not_numeric(card, '1..')
    assert_not_numeric(card, '..1')    
  end
  
  def test_should_be_able_to_create_equivalent_numeric_values
    any_num = setup_numeric_text_property_definition('any number')
    card_one = @project.cards.create!(:name => 'card 1', :card_type => @project.card_types.first)
    card_two = @project.cards.create!(:name => 'card 2', :card_type => @project.card_types.first)
    
    any_num.update_card(card_one, '1')
    card_one.save!
    
    any_num.update_card(card_two, '1.0')
    card_two.save!
    
    assert_equal '1', any_num.value(card_one)
    assert_equal '1.0', any_num.value(card_two)
  end
  
  def test_should_not_be_able_to_set_property_to_user_input_special_values
    hiya = setup_text_property_definition('hiya')
    card_one = @project.cards.create!(:name => 'cardomatic 1', :card_type_name => 'Card')
    card_two = @project.cards.create!(:name => 'cardomatic 2', :card_type_name => 'Card')
    
    hiya.update_card(card_one, Transition::USER_INPUT_REQUIRED)
    card_one.save
    assert_equal ["hiya: #{Transition::USER_INPUT_REQUIRED.bold} is an invalid value. Value cannot both start with '(' and end with ')' unless it is an existing project variable which is available for this property."], card_one.errors.full_messages
    
    hiya.update_card(card_two, Transition::USER_INPUT_OPTIONAL)
    card_two.save
    assert_equal ["hiya: #{Transition::USER_INPUT_OPTIONAL.bold} is an invalid value. Value cannot both start with '(' and end with ')' unless it is an existing project variable which is available for this property."], card_two.errors.full_messages
  end
  
  def test_enumeration_values_should_be_any_text_when_the_propery_definition_allow_any_text
    assert_equal "Any text", @property.property_values_description
  end
  
  private
  
  def assert_not_numeric(card, new_value)
    @property.update_card(card, new_value)
    card.save!
    assert !@property.numeric?
  end
  
end
