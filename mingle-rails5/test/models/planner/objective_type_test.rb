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

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class ObjectiveTypeTest < ActiveSupport::TestCase

  def setup
    User.current = nil
  end

  context :association do
    should have_many(:objective_property_mappings).dependent(:destroy)
    should have_many(:objective_property_definitions).through(:objective_property_mappings)
  end

  context 'ObjectiveValidations' do
    subject do
      program = FactoryGirl.create(:simple_program)
      FactoryGirl.build(:objective_type, program_id: program.id)
    end
    should validate_presence_of(:name)
    should validate_uniqueness_of(:name).scoped_to(:program_id).with_message('Already used for an existing ObjectiveType in your Program')
  end

  def test_default_attributes_should_return_right_attrs
    default_value_statement = '<h2>Context</h2>

<h3>Business Objective</h3>

<p>Whose life are we changing?</p>

<p>What problem are we solving?</p>

<p>Why do we care about solving this?</p>

<p>What is the successful outcome?</p>

<h3>Behaviours to Target</h3>

<p>(Example: Customer signup for newsletter, submitting support tickets, etc)</p>
'

    assert_equal({name: 'Objective', value_statement: default_value_statement}, ObjectiveType.default_attributes)
  end

  def test_should_sanitize_value_statement
    program = create(:program)
    html_text = "<div>Hello</div><unsafe-tag>Unsafe content</unsafe-tag><style> div{color:red;}</style>"
    expected_sanitized_html =  "<div>Hello</div>Unsafe content"

    objective_type = create(:objective_type, value_statement: html_text, program_id: program.id)
    assert_equal expected_sanitized_html, objective_type.value_statement
  end

  def test_to_params_should_include_property_definitions
    program = create(:program)
    objective_type  = program.objective_types.default.first
    allowed_values = [0, 10, 20, 30, 40, 50, 60, 70, 80, 90, 100]
    expected = {
        property_definitions: {
            Size:{name: 'Size', value: '(not set)', :allowed_values=> allowed_values},
            Value:{name: 'Value', value: '(not set)', :allowed_values=> allowed_values}
        }
    }.merge(objective_type.attributes.slice('id', 'name', 'value_statement')).symbolize_keys
    assert_equal(expected, objective_type.to_params)
  end

end
