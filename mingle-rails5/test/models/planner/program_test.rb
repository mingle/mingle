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

class ProgramTest < ActiveSupport::TestCase

  def setup
    create(:admin, login: :admin, admin: true)
    login_as_admin
  end

  should have_one(:plan).dependent(:destroy)
  should have_many(:objectives).dependent(:destroy)
  should validate_uniqueness_of(:name)
  should validate_length_of(:name).is_at_most(255)
  should have_many(:program_projects).dependent(:destroy)
  should have_many(:projects)
  should have_many(:objective_property_definitions).dependent(:destroy)

  def test_program_should_create_a_plan
    program = create(:program)
    assert program.plan
  end

  def test_should_create_objective_sequence_table_on_create
    program = create(:program)
    assert_equal 1, program.next_objective_number
    assert_equal 2, program.next_objective_number
  end

  def test_duplicate_name_validation
    create(:program, name: 'program1')
    program = build(:program, :name => 'program1', :identifier => 'another_identifier')
    assert_false program.valid?
    assert_equal 'name has already been taken', program.errors.first.join(' ')
  end

  def test_trims_name
    program = create(:program, :name => ' new program ', :identifier => 'newprogram')
    assert_equal 'new program', program.name
  end

  def test_reorder_objectives
    program =  create(:program, :name => ' new program ', :identifier => 'newprogram')
    create(:objective, :backlog, name: 'A', program_id: program.id)
    create(:objective, :backlog, name: 'B', program_id: program.id)
    create(:objective, :planned, name: 'C', program_id: program.id)
    create(:objective, :planned, name: 'D', program_id: program.id)
    objectives = program.objectives

    assert_equal %w[B D A C], objectives.map(&:name)

    program.reorder_objectives(objectives.backlog.reverse.map(&:number))
    assert_equal %w[A D B C], objectives.all_objectives.reload.map(&:name)
  end

  def test_should_add_current_user_as_team_member_on_create
    bob = create(:bob)
    login(bob)
    program = create(:program)
    assert program.team.users.include?(bob)
    assert_equal MembershipRole[:program_admin], program.role_for(bob)
  end

  def test_should_create_objective_sequence_table_on_create
    program = create(:program)
    assert_equal 1, program.next_objective_number
    assert_equal 2, program.next_objective_number
  end

  def test_should_fetch_projects_associated_with_the_program
    program = create(:program)

    project1 = create(:project)
    project2 = create(:project)
    create(:program_project, project_id:project1.id,program_id:program.id)
    create(:program_project, project_id:project2.id,program_id:program.id)

    assert_equal 2, program.projects_associated.size
    assert program.projects_associated.include? project1.name
    assert program.projects_associated.include? project2.name

  end


  def test_should_fetch_all_member_with_the_given_login_name
    user1 = create(:user)
    user2 = create(:user)
    user3 = create(:user)
    user4 = create(:user)
    program = create(:program)
    program.add_member(user1)
    program.add_member(user2)
    program.add_member(user3)
    program.add_member(user4)

    expected_result = [user1.id, user3.id]
    actual_result =  program.members_for_login([user1.login, user3.login])

    assert_equal expected_result, actual_result.map(&:member_id)

  end

  def test_should_create_default_objective_type_for_new_program
    program = create(:program)
    expected_default_value_statement = '<h2>Context</h2>

<h3>Business Objective</h3>

<p>Whose life are we changing?</p>

<p>What problem are we solving?</p>

<p>Why do we care about solving this?</p>

<p>What is the successful outcome?</p>

<h3>Behaviours to Target</h3>

<p>(Example: Customer signup for newsletter, submitting support tickets, etc)</p>
'

    assert_equal(1, program.objective_types.size)
    assert_equal('Objective', program.objective_types.first.name)
    assert_equal(expected_default_value_statement, program.objective_types.first.value_statement)
  end

  def test_default_objective_type_returns_default_value
    program = create(:program)
    program.objective_types.create(name: 'Idea', value_statement: 'Blah blah idea')

    assert_equal(ObjectiveType.default_attributes[:name], program.default_objective_type.name)
    assert_equal(ObjectiveType.default_attributes[:value_statement], program.default_objective_type.value_statement)
  end

  def test_should_create_default_properties_and_mappings_for_new_program
    program = create(:program)

    assert_equal(2, program.objective_property_definitions.size)

    sorted_prop_defs = program.objective_property_definitions.sort_by(&:name)
    assert_equal('Size', sorted_prop_defs.first.name)
    assert_equal('Value', sorted_prop_defs.second.name)
    assert_not_nil(ObjectivePropertyMapping.find_by(obj_prop_def_id: sorted_prop_defs.first.id))
    assert_not_nil(ObjectivePropertyMapping.find_by(obj_prop_def_id: sorted_prop_defs.second.id))
  end

  def test_should_create_default_properties_with_default_values
    program = create(:program)
    size_property_definition = ManagedNumber.find_by_name_and_program_id('Size', program.id)
    value_property_definition = ManagedNumber.find_by_name_and_program_id('Value', program.id)
    values = 11.times.map {|value| value * 10}

    assert_false size_property_definition.nil?
    assert_equal values, size_property_definition.objective_property_values.map(&:value).map(&:to_i).sort
    assert_false value_property_definition.nil?
    assert_equal values, value_property_definition.objective_property_values.map(&:value).map(&:to_i).sort
  end
end
