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

class DatePropertyDefinitionTest < ActiveSupport::TestCase  

  def setup
    login_as_member
    @project = create_project
    @property = setup_date_property_definition('ourdateproperty')
    @project.activate
    @card = create_card!(:name => 'card one')
  end  

  def teardown
    Clock.reset_fake
  end

  def test_should_return_sensible_defaults_for_card_with_no_value
    assert_nil @property.value(@card)
    assert_equal PropertyValue::NOT_SET, @card.display_value(@property)
    assert @card.property_value(@property).not_set?
  end  

  def test_should_be_able_to_set_a_date_property_on_a_card
    @property.update_card(@card, '25 Aug 2007')
    @card.save!
    
    assert_equal 2007, @card.cp_ourdateproperty.year
    assert_equal 8, @card.cp_ourdateproperty.month
    assert_equal 25, @card.cp_ourdateproperty.day
    @project.all_property_definitions.reload
    assert @project.property_definitions.collect(&:name).include?('ourdateproperty')
  end
  
  def test_should_interpret_two_digit_years_as_being_in_the_20th_and_21st_centuries
    @property.update_card(@card, '25 Aug 68')
    assert_equal Date.new(2068, 8, 25), @property.value(@card)

    @property.update_card(@card, '25 Aug 69')
    assert_equal Date.new(1969, 8, 25), @property.value(@card)

    @property.update_card(@card, '25 Aug 70')
    assert_equal Date.new(1970, 8, 25), @property.value(@card)
  end  
  
  def test_should_be_able_to_reset_a_date_property_on_a_card
    @property.update_card(@card, '25 Aug 2007')
    @card.save!
    assert_equal Date.new(2007, 8, 25), @property.value(@card.reload)
    
    @property.update_card(@card, nil)
    @card.save!
    assert_nil @property.value(@card.reload)
  end

  def test_should_describe_itself_as_date
    assert_equal 'Date', @property.describe_type
  end
  
  def test_should_return_current_number_of_values
    @property.update_card(@card, '25 Aug 2007')
    @card.save!
    @property.update_card(@card, '25 Aug 2008')
    @card.save!
    
    assert_equal 1, @property.values.size
  end
  
  def test_should_return_string_representation_of_date_as_value_identifier
    @property.update_card(@card, '25 Aug 2007')
    @card.save!
    assert_equal "2007-08-25", @card.reload.property_value(@property).db_identifier
  end

  def test_should_invalidate_cards_if_date_is_wonky
    @property.update_card(@card, 'Jam for Sputnik')
    assert !@card.errors.empty?
  end  

  def test_should_return_current_day_converted_by_project_time_zone_for_today_identifiers
    Clock.fake_now(:year => 2005, :month => 10, :day => 3)
    @project.time_zone = ActiveSupport::TimeZone.new("International Date Line West").name
    @property.update_card(@card, PropertyType::DateType::TODAY)
    assert_equal PropertyType::DateType::TODAY, @property.property_value_from_db(PropertyType::DateType::TODAY).display_value
    assert_equal "2005-10-02", @property.value(@card).to_s
  end
  
  def test_should_be_able_special_value_of_today_in_a_case_insensitive_manner
    Clock.fake_now(:year => 2005, :month => 10, :day => 3)
    @project.time_zone = ActiveSupport::TimeZone.new("International Date Line West").name
    @property.update_card(@card, PropertyType::DateType::TODAY.upcase)
    assert_equal "2005-10-02", @property.value(@card).to_s
  end

  def test_should_be_able_to_enter_today_without_parentheses_in_date_field
    Clock.fake_now(:year => 2005, :month => 10, :day => 3)
    @project.time_zone = ActiveSupport::TimeZone.new("International Date Line West").name
    @property.update_card(@card, 'Today')
    assert_equal "2005-10-02", @property.value(@card).to_s
  end
  
  def test_should_display_date_in_project_format
    @property.update_card(@card, '25 Aug 1969') # default format
    assert_equal '25 Aug 1969', @card.display_value(@property)
    @project.date_format = '%d/%m/%Y'
    assert_equal '25/08/1969', @card.display_value(@property)
    @project.date_format = '%m/%d/%Y'
    assert_equal '08/25/1969', @card.display_value(@property)
    @project.date_format = '%y %b %d'
    assert_equal '69 Aug 25', @card.display_value(@property)
  end

  def test_property_values_description
    assert_equal "Any date", @property.property_values_description
  end
end


