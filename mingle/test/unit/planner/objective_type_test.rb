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

require File.expand_path("../../unit_test_helper", File.dirname(__FILE__))

class ObjectiveTest < ActiveSupport::TestCase

  def setup
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan
  end

  def test_duplicate_name_validation
    create_objective_type "obj_type", "statement", @program.id
    obj_type  = ObjectiveType.new(:name => "obj_type", :value_statement => "value statement", :program_id => @program.id)
    assert_false obj_type.valid?
    assert_equal 'name Already used for an existing ObjectiveType in your Program', obj_type.errors.first.join(' ')
  end

  def test_objective_type_name_cant_be_blank
    objective_type = ObjectiveType.new(:name => '   ', :value_statement => "value statement", :program_id => @program.id)
    assert !objective_type.valid?
    assert_equal "can't be blank", objective_type.errors[:name]
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
end
