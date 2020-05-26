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

class Macro::ValidationsTest < ActiveSupport::TestCase
  class Foo

    class << self
      def validations
        @validations ||= []
      end
      def parameter_conversions
        @parameter_conversions ||= []
      end
    end

    include Macro::Validations

    attr_reader :start_date, :x_axis_start_date,
                :end_date, :x_axis_end_date,
                :target_release_date, :mark_target_release_date

    def initialize(start_date, end_date, target_release_date=nil)
      @start_date = start_date
      @end_date = end_date
      @target_release_date = target_release_date
      convert_parameters
      validate!
    end

    def parse_date(override, parameter_name)
      Date.parse(override.to_s)
    end

  end

  class SetAttributesFoo < Foo
    convert_parameter :x_axis_start_date, :from => :start_date, :as => :date
    convert_parameter :x_axis_end_date, :from => :end_date, :as => :date
    convert_parameter :mark_target_release_date, :from => :target_release_date, :as => :date
  end

  class ValidationFoo < Foo

    convert_parameter :x_axis_start_date, :from => :start_date, :as => :date
    convert_parameter :x_axis_end_date, :from => :end_date, :as => :date

    validate :a_should_before_b, :message => 'error message a_should_before_b'

    def a_should_before_b
      @x_axis_start_date < @x_axis_end_date
    end
  end

  class ValidationWithoutMessageFoo < Foo

    convert_parameter :x_axis_start_date, :from => :start_date, :as => :date
    convert_parameter :x_axis_end_date, :from => :end_date, :as => :date

    validate :a_should_before_b

    def a_should_before_b
      @x_axis_start_date < @x_axis_end_date
    end
  end

  class ErrorValidationFoo < Foo

    convert_parameter :x_axis_start_date, :from => :start_date, :as => :date
    convert_parameter :x_axis_end_date, :from => :end_date, :as => :date

    validate :a_should_before_b, :message => 'error message a_should_before_b'

    def a_should_before_b
      raise "unexpected"
    end
  end

  class BlockValidationFoo < Foo

    convert_parameter :x_axis_start_date, :from => :start_date, :as => :date
    convert_parameter :x_axis_end_date, :from => :end_date, :as => :date

    validate :a_exist, :block => true
    validate :a_should_before_b, :message => 'error message a_should_before_b'

    def a_exist
      raise 'a does not exist'
    end

    def a_should_before_b
      raise "unexpected"
    end
  end

  class ExplodingMacro < Macro

    parameter :start_date, :required => true,        :computable => true, :compatible_types => [:date]
    convert_parameter :some_converted_date, :from => :start_date, :as => :date

    def parse_date(override, parameter_name)
      Date.parse_with_hint(override.to_s, project.date_format)
    rescue => e
      raise StandardError.new("Parameter #{parameter_name.to_s.bold} must be a valid date.")
    end

  end

  class BlockValidationWithMessageFoo < Foo

    convert_parameter :x_axis_start_date, :from => :start_date, :as => :date
    convert_parameter :x_axis_end_date, :from => :end_date, :as => :date

    validate :a_exist, :message => 'a does not exist', :block => true
    validate :a_should_before_b, :message => 'error message a_should_before_b'

    def a_exist
      false
    end

    def a_should_before_b
      raise "unexpected"
    end
  end

  def test_convert_date_parameter
    foo = SetAttributesFoo.new("May 1 2010", "May 2 2010")
    assert_equal Date.parse("May 1 2010"), foo.x_axis_start_date
    assert_equal Date.parse("May 2 2010"), foo.x_axis_end_date
  end

  def test_convert_parameter_error
    assert_raise_message Macro::ConvertParameterError, /invalid date/ do
      SetAttributesFoo.new("foo", "May 2 2010")
    end
  end

  def test_validate
    assert ValidationFoo.new("May 1 2010", "May 2 2010").valid?
    assert_raise_message Macro::ValidationError, /error message a_should_before_b/ do
      ValidationFoo.new("May 3 2010", "May 2 2010")
    end
  end

  def test_should_not_do_validations_when_set_attributes_has_error
    assert_raise Macro::ConvertParameterError do
      ValidationFoo.new("foo", "May 2 2010")
    end
  end

  def test_should_give_error_even_no_message_defined_for_validation
    assert_raise_message Macro::ValidationError, /A should before b/ do
      ValidationWithoutMessageFoo.new("May 3 2010", "May 2 2010")
    end
  end

  def test_should_include_error_message_and_validation_message_when_setup_validation_message_and_error_occurs
    assert_raise_message Macro::ValidationError, /error message a_should_before_b: unexpected/ do
      ErrorValidationFoo.new("May 3 2010", "May 2 2010")
    end
  end

  def test_should_not_validate_the_following_validations_when_block_validation_failed
    assert_raise_message Macro::ValidationError, /a does not exist$/ do
      BlockValidationFoo.new("May 3 2010", "May 2 2010")
    end
  end

  def test_should_not_validate_the_following_validations_when_block_validation_failed2
    assert_raise_message Macro::ValidationError, /a does not exist$/ do
      BlockValidationWithMessageFoo.new("May 3 2010", "May 2 2010")
    end
  end

  def test_should_raise_errors_before_converting_parameters_if_resolving_parameter_values_results_in_errors
    with_first_project do |project|
      context = {:content_provider => project.cards.new}
      assert_raise_message Macro::ConvertParameterError, /must be a valid date/ do
        ExplodingMacro.new(context, 'exploding', {'start-date' => 'xyz'})
      end
    end
  end

  def test_should_not_raise_error_when_converting_a_not_yet_available_THIS_CARD_param_value
    with_first_project do |project|
      context = {:content_provider => project.cards.new}
      ExplodingMacro.new(context, 'exploding', {'start-date' => 'THIS CARD."start date"'})
    end
  end

  def test_should_ignore_conversion_if_from_parameter_is_not_given
    assert_equal nil, SetAttributesFoo.new(nil, "May 2 2010").x_axis_start_date
    assert_equal nil, SetAttributesFoo.new("", "May 2 2010").x_axis_start_date
    assert_equal nil, SetAttributesFoo.new("May 2 2010", "May 5 2010").mark_target_release_date
  end
end

