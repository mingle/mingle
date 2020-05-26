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

class PropertyTypeTest < ActiveSupport::TestCase

  def test_type_should_be_compatible_with_a_list_include_itself
    assert PropertyType.compatible?(:date, [:date])
    assert PropertyType.compatible?(:date, [:string, :date])
    assert !PropertyType.compatible?(:date, [:string, :numeric])
  end

  def test_compatiability_check_can_mix_usage_of_object_and_symbol
    assert PropertyType.compatible?(PropertyType::NumericType.new(nil), [:string, :numeric])
    assert PropertyType.compatible?(:string, [PropertyType::StringType.new, :date])
    assert !PropertyType.compatible?(PropertyType::StringType.new, [PropertyType::NumericType.new(nil)])
  end

  def test_compatiability_check_should_not_change_the_with_list
    with_list = [:numeric]
    PropertyType.compatible?(:integer, with_list)
    assert_equal [:numeric], with_list
  end

  def test_integer_type_should_be_compatible_with_numeric
    assert PropertyType.compatible?(:integer, [:numeric])
    assert !PropertyType.compatible?(:integer, [:string])
  end

  def test_project_type_should_be_compatible_with_string
    assert PropertyType.compatible?(:project, [:string])
    assert !PropertyType.compatible?(:project, [:numeric])
  end
end

class DatePropertyTypeTest < ActiveSupport::TestCase
  def setup
    login_as_member
    @project = create_project
    @type = PropertyType::DateType.new(@project)
    @project.activate
  end

  def teardown
    Clock.reset_fake
  end

  def test_database_value_should_convert_TODAY_to_current_date
    Clock.fake_now(:year => 1984, :month => 4, :day => 16)
    @project.time_zone = ActiveSupport::TimeZone.new("London").name
    assert_equal '1984-04-16', @type.url_to_db_identifier(PropertyType::DateType::TODAY)
  end

  def test_database_value_should_parse_dates
    assert_equal '1994-05-30', @type.url_to_db_identifier('1994/5/30')
  end

  def test_sanitize_db_identifier_should_try_to_convert_the_identifier_to_default_format
    assert_nil @type.sanitize_db_identifier(nil, nil)
    assert_equal '2002-10-20', @type.sanitize_db_identifier('20 Oct 2002', nil)
    assert_equal 'ill date', @type.sanitize_db_identifier('ill date', nil)
  end

  def test_to_sym
    assert_equal :date, @type.to_sym
  end

  def test_to_s
    assert_equal 'date', @type.to_s
  end
end

class StringPropertyTypeTest < ActiveSupport::TestCase
  def setup
    login_as_member
    @project = create_project
    @type = PropertyType::StringType.new
    @project.activate
  end

  def test_display_value_url_identifier_and_db_identifier_should_be_identical
    assert_equal 'some_value', @type.url_to_db_identifier('some_value')
    assert_equal 'some_value', @type.db_to_url_identifier('some_value')
    assert_equal 'some_value', @type.display_value_for_db_identifier('some_value')
  end

  def test_to_sym
    assert_equal :string, @type.to_sym
  end

  def test_to_s
    assert_equal 'string', @type.to_s
  end
end

class CalculatedPropertyTypeTest < ActiveSupport::TestCase
  def setup
    login_as_member
    @project = create_project
    @project.activate
  end

  def test_should_output_display_value_with_formular_output_formating
    formula_property_definition = setup_formula_property_definition('formula', '1 + 2')
    calculated_type = PropertyType::CalculatedType.new(@project, formula_property_definition)
    assert_equal '16', calculated_type.display_value_for_db_identifier('16.00')
    assert_equal '16.01', calculated_type.display_value_for_db_identifier('16.01')
  end

  # bug 3058
  def test_calculated_types_that_come_out_as_dates_will_have_a_date_display_value
    formula_property_definition = setup_formula_property_definition('formula', '1 + 2')
    date_type = PropertyType::DateType.new(@project)
    calculated_type = PropertyType::CalculatedType.new(@project, formula_property_definition)

    assert_equal date_type.display_value_for_db_identifier('2006-05-16'), calculated_type.display_value_for_db_identifier('2006-05-16')
    assert_equal date_type.display_value_for_db_identifier('16 May 2006'), calculated_type.display_value_for_db_identifier('16 May 2006')
  end

  # bug 3058
  def test_sanitize_db_identifier_will_choose_correct_output_based_on_identifier_string
    startdate = setup_date_property_definition('startdate')
    formula = setup_formula_property_definition('formula', 'startdate + 1')

    calculated_type = PropertyType::CalculatedType.new(@project, nil)
    assert_equal '2002-10-20', calculated_type.sanitize_db_identifier('20 Oct 2002', formula)
    assert_equal '16', calculated_type.sanitize_db_identifier('16', formula)
  end

  def test_to_sym_should_be_base_on_the_output_type_of_formula
    fpd = setup_formula_property_definition('formula1', '1 + 2')
    assert_equal :numeric, PropertyType::CalculatedType.new(@project, fpd).to_sym

    startdate = setup_date_property_definition('startdate')

    fpd = setup_formula_property_definition('formula2', 'startdate + 1')
    assert_equal :date, PropertyType::CalculatedType.new(@project, fpd).to_sym
  end
end

class NumericPropertyTypeTest < ActiveSupport::TestCase
  def setup
    login_as_member
    @project = create_project
    @type = PropertyType::NumericType.new(@project)
    @project.activate
  end

  def test_db_identifier_is_card_id_url_identifier_is_card_number_and_display_value_is_card_name
    db_value = url_value = display_value = object_value = '10.2'
    assert_equal url_value, @type.db_to_url_identifier(db_value)
    assert_equal db_value, @type.url_to_db_identifier(url_value)
    assert_equal display_value, @type.display_value_for_db_identifier(db_value)
    assert_equal object_value, @type.find_object(db_value)
    assert_equal db_value, @type.object_to_db_identifier(object_value)
  end

  def test_should_be_tolerant_nil_identifier
    assert_nil @type.db_to_url_identifier(nil)
    assert_nil @type.url_to_db_identifier(nil)
    assert_nil @type.display_value_for_db_identifier(nil)
    assert_nil @type.find_object(nil)
    assert_nil @type.object_to_db_identifier(nil)
  end

  def test_should_throw_when_invalid_value_is_passed_to_find_object
    assert_raise(PropertyDefinition::InvalidValueException) { @type.find_object('a') }
  end

  def test_should_pass_validation_when_a_number
    assert @type.validate('10.5').empty?
  end

  def test_should_fail_validation_when_not_a_number
    assert !@type.validate('abc').empty?
  end

  def test_should_pass_validation_when_nil
    assert @type.validate(nil).empty?
  end

  #bug 6346 (Get ActiveRecord error when try to import a large value via excel) caused by over max precision
  def test_should_provide_an_error_when_value_pecision_is_over_max_precision
    max_precision = ActiveRecord::Base.connection.max_precision
    assert_include 'invalid numeric precision', @type.validate("6.00089E+#{max_precision+1}").first
  end

  def test_sanitize_should_not_allow_various_forms_of_the_same_number_for_finite_valued_property_definitions
    prop_def = OpenStruct.new(:values => [OpenStruct.new(:value => '3.0')], :finite_valued? => true)
    assert_equal '3.0', @type.sanitize_db_identifier('3.00', prop_def)
  end

  def test_sanitize_should_allow_various_forms_of_the_same_number_for_infinite_valued_property_definitions
    prop_def = OpenStruct.new(:values => ['3.0'], :finite_valued? => false)
    assert_equal '3.00', @type.sanitize_db_identifier('3.00', prop_def)
  end

  def test_detect_existing_should_use_project_precision
     assert_equal '4.0', @type.detect_existing('3.999', [EnumerationValue.new(:value => '4.0')], true).value
     assert_equal '4.0', @type.detect_existing('3.999', ['4.0'], false)
  end

  def test_sanitize_db_identifier_should_format_new_values_based_on_project_precision
    setup_numeric_text_property_definition('size')
    size = @project.find_property_definition('size')
    assert_equal '4.00', @type.sanitize_db_identifier('3.999', size)
    assert_equal '3.99', @type.sanitize_db_identifier('3.99', size)
  end

  def test_sanitize_db_identifier_does_not_care_aboue_existing_values_when_creating_a_new_value
    setup_numeric_text_property_definition('size')
    card = create_card!(:name => 'I am card', :size => '4')
    size = @project.find_property_definition('size')
    assert_equal '4.00', @type.sanitize_db_identifier('3.999', size)
  end

  def test_make_uniq_should_return_only_numerically_unique_values
    size = setup_numeric_text_property_definition('size')
    uniq_results = @type.make_uniq(['2', '2.00', '2.0', '1.00', '2.10', '1.01'])
    assert_equal ['2.00', '1.00', '2.10', '1.01'], uniq_results
  end

  def test_should_detect_uniqueness_without_ignoring_significant_zeros_for_integral_numbers
    size = setup_numeric_text_property_definition('size')
    uniq_results = @type.make_uniq(['2', '20'])
    assert_equal ['2', '20'], uniq_results
  end

  def test_should_detect_uniqueness_taking_into_account_significant_zeros_for_decimal_numbers
    size = setup_numeric_text_property_definition('size')
    uniq_results = @type.make_uniq(['2', '2.0', '2.00'])
    assert_equal ['2.00'], uniq_results
  end

  def test_should_detect_uniqueness_of_deciamls_without_integral_parts_by_taking_into_account_significant_zeros_past_the_decimal_point
    size = setup_numeric_text_property_definition('size')
    uniq_results = @type.make_uniq(['.2', '.20', '.200'])
    assert_equal ['.200'], uniq_results
  end

  def test_find_object_should_format_by_project_precision
    assert_equal '5.56', @type.find_object('5.55555')
    assert_equal '5.00', @type.find_object('5.000')
    assert_equal '7.0', @type.find_object('7.0')
    assert_equal '7', @type.find_object('7')
  end

  def test_format_value_for_card_query_different_when_need_cast_numeric_columns
    assert_equal '5.55555', @type.format_value_for_card_query('5.55555')
    assert_equal '5.000', @type.format_value_for_card_query('5.000')
    assert_equal '7.0', @type.format_value_for_card_query('7.0')
    assert_equal '7', @type.format_value_for_card_query('7')
    assert_equal nil, @type.format_value_for_card_query(nil)
    assert_equal '0', @type.format_value_for_card_query('0')
    assert_equal '', @type.format_value_for_card_query('')

    assert_equal '5.56', @type.format_value_for_card_query('5.55555', true)
    assert_equal '5.00', @type.format_value_for_card_query('5.000', true)
    assert_equal '7.00', @type.format_value_for_card_query('7.0', true)
    assert_equal '7.00', @type.format_value_for_card_query('7', true)
    assert_equal nil, @type.format_value_for_card_query(nil, true)
    assert_equal '0.00', @type.format_value_for_card_query('0', true)
    assert_equal '', @type.format_value_for_card_query('', true)
  end

  # part of bug 2976
  def test_an_empty_string_is_equivalent_to_nil
    assert_nil @type.find_object("")
  end

  def test_to_sym
    assert_equal :numeric, @type.to_sym
  end

  def test_to_s
    assert_equal 'numeric', @type.to_s
  end
end

class CardPropertyTypeTest < ActiveSupport::TestCase
  def setup
    login_as_member
    @project = create_project
    @type = PropertyType::CardType.new(@project)
    @project.activate
  end

  def test_db_identifier_is_card_id_url_identifier_is_card_number_and_display_value_is_card_name_with_number_in_front
    card = create_card!(:name => 'card 1')
    assert_equal card.number.to_s, @type.db_to_url_identifier(card.id)
    assert_equal card.id.to_s, @type.url_to_db_identifier(card.number)
    assert_equal "##{card.number} #{card.name}", @type.display_value_for_db_identifier(card.id)
    assert_equal card, @type.find_object(card.id)
    assert_equal card.id.to_s, @type.object_to_db_identifier(card)
  end

  def test_should_be_tolerant_nil_identifier
    assert_nil @type.db_to_url_identifier(nil)
    assert_nil @type.url_to_db_identifier(nil)
    assert_nil @type.display_value_for_db_identifier(nil)
    assert_nil @type.find_object(nil)
    assert_nil @type.object_to_db_identifier(nil)
  end

  def test_should_parse_exported_value
    card = create_card!(:name => 'card 1')
    assert_equal card.id.to_s, @type.parse_import_value("##{card.number} #{card.name}")
    assert_equal card.id.to_s, @type.parse_import_value("##{card.number}")
    assert_equal card.id.to_s, @type.parse_import_value("  ##{card.number} ")
    assert_raise(CardImport::CardImportException){ @type.parse_import_value("#1111111111") }
    assert_raise(CardImport::CardImportException){ @type.parse_import_value("card 1") }

    assert_nil @type.parse_import_value('')
    assert_nil @type.parse_import_value(nil)
  end

  def test_find_object_should_raise_info_about_looking_for_non_existing_card
    assert_raise PropertyDefinition::InvalidValueException, "Card properties can only be updated with ids of existing cards: cannot find card or card version with id not-exist" do
      @type.find_object("not-exist")
    end
  end

  def test_find_object_returns_nil_if_passed_empty_string
    create_card! :name => 'card 1'
    assert_nil @type.find_object("")
  end

  def test_to_sym
    assert_equal :card, @type.to_sym
  end

  def test_to_s
    assert_equal 'card', @type.to_s
  end
end

class BooleanPropertyTypeTest < ActiveSupport::TestCase
  def setup
    @type = PropertyType::BooleanType.new
  end

  def test_export_value
    assert_equal 'yes', @type.export_value(true)
    assert_equal 'no', @type.export_value(false)
    assert_equal 'no', @type.export_value(nil)
  end

  def test_parse_import_value
    assert @type.parse_import_value('yes')
    assert @type.parse_import_value('YES')
    assert @type.parse_import_value('True')
    assert @type.parse_import_value('true')
    assert !@type.parse_import_value('no')
    assert !@type.parse_import_value('false')
    assert !@type.parse_import_value('')
    assert !@type.parse_import_value(' ')
  end

  def test_data_type
    assert_equal :boolean, @type.to_sym
  end

  def test_to_s
    assert_equal 'boolean', @type.to_s
  end
end

class ProjectPropertyTypeTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    @type = PropertyType::ProjectType.new
  end

  def test_db_identifier_should_be_project_id
    assert_equal @project.id.to_s, @type.object_to_db_identifier(@project)
    assert_equal @project.id.to_s, @type.url_to_db_identifier(@project.identifier)
    assert_equal @project.identifier, @type.db_to_url_identifier(@project.id)
    assert_equal @project.name, @type.display_value_for_db_identifier(@project.id)
    assert_equal @project.name, @type.format_value_for_card_query(@project.name)
  end

  def test_should_return_nil_when_project_does_not_exist
    assert_equal nil, @type.url_to_db_identifier("nonexist")
    assert_equal nil, @type.db_to_url_identifier("12345678")
    assert_equal nil, @type.display_value_for_db_identifier("12345678")
  end
end
