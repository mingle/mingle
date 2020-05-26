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

class RablExtTest < ActiveSupport::TestCase
  def setup
    @original_config = Rabl.configuration.convert_to_camelcase
    Rabl.configuration.convert_to_camelcase = true
  end

  def test_should_convert_attributes_to_camel_case_when_convert_to_camelcase_configured
    renderable = OpenStruct.new(attr_with_snake_case: 'hello world')

    json = Rabl::Renderer.json(renderable, "attribute :attr_with_snake_case\n")

    assert_equal '{"attrWithSnakeCase":"hello world"}', json
  end

  def test_should_remove_trailing_question_mark_from_attributes_when_convert_to_camelcase_configured
    renderable = OpenStruct.new(attr_with_snake_case?: 'hello world')

    json = Rabl::Renderer.json(renderable, "attribute :attr_with_snake_case?\n")

    assert_equal '{"attrWithSnakeCase":"hello world"}', json
  end

  def test_should_leave_camel_cased_attributes_as_it_is_when_convert_to_camelcase_configured
    renderable = OpenStruct.new(attrWithCamelCase?: 'hello world')

    json = Rabl::Renderer.json(renderable, "attribute :attrWithCamelCase?\n")

    assert_equal '{"attrWithCamelCase":"hello world"}', json
  end

  def test_should_not_convert_keys_when_camelcase_not_configured
    Rabl.configuration.convert_to_camelcase = false
    renderable = OpenStruct.new(attr_with_snake_case?: 'hello world')

    json = Rabl::Renderer.json(renderable, "attribute :attr_with_snake_case?\n")

    assert_equal '{"attr_with_snake_case?":"hello world"}', json
  end

  def teardown
    Rabl.configuration.convert_to_camelcase = @original_config
  end
end
