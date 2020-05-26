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

class ProgramTest < ActiveSupport::TestCase

  def setup
    login_as_admin
  end

  def test_that_program_creates_a_plan
    program = create_program
    assert program.plan
  end

  def test_that_a_plan_is_destroyed_when_a_program_is_destroyed
    program = create_program
    plan_id = program.plan.id
    program.destroy
    assert_false Plan.exists?(plan_id)
  end

  def test_that_backlog_objectives_are_destroyed_when_a_program_is_destroyed
    program = create_program
    program.objectives.backlog.create(name: "b1")
    assert 1, program.objectives.backlog.count

    program.destroy

    assert 0, program.objectives.backlog.count
  end

  def test_duplicate_name_validation
    create_program "program1"
    program = Program.new(:name => "program1", :identifier => "another_identifier")
    assert_false program.valid?
    assert_equal 'name has already been taken', program.errors.first.join(' ')
  end

  def test_trims_name
    program = Program.create!(:name => " new program ", :identifier => "newprogram")
    assert_equal "new program", program.name
  end

  def test_rename_along_with_identifier_should_add_number_to_non_unique_identifier
    Program.create!(:name => 'who cares', :identifier => 'nuevo_nombre')
    program = create_program
    program.rename_along_with_identifier('NueVo NomBre')
    assert_equal 'NueVo NomBre', program.name
    assert_equal 'nuevo_nombre1', program.identifier
  end
  
  def test_rename_along_with_identifier_should_create_stripped_identifier
    program = create_program
    program.rename_along_with_identifier('!NueVo NomBre!')
    assert_equal '!NueVo NomBre!', program.name
    assert_equal '_nuevo_nombre_', program.identifier
  end
  
  def test_rename_along_with_identifier_should_create_downcased_identifier
    program = create_program
    program.rename_along_with_identifier('ALL CAPS')
    assert_equal 'ALL CAPS', program.name
    assert_equal 'all_caps', program.identifier
  end

  def test_should_add_current_user_as_team_member_on_create
    bob = login_as_bob
    program = create_program
    assert program.team.users.include?(bob)
    assert_equal MembershipRole[:program_admin], program.role_for(bob)
  end

  def test_should_clear_team_membership_after_deleted_program
    program = create_program
    member = User.find_by_login('member')
    program.add_member(member)
    assert program.destroy
    assert_equal 0, MemberRole.count(:conditions => {:deliverable_id => program.id})
  end

  def test_restricts_program_name_length
    program = create_program
    program.rename_along_with_identifier('The quick brown fox jumped over the lazy dog' * 10)
    assert_false program.valid?
    assert_equal 'Name is too long (maximum is 255 characters)', program.errors.full_messages.first
  end

  def test_should_create_objective_sequence_table_on_create
    program = create_program
    assert_equal 1, program.next_objective_number
    assert_equal 2, program.next_objective_number
  end


  def test_should_create_default_objective_type_for_new_program
    program = create_program
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

  def test_all_selected_should_return_all_program_with_given_identifiers
    program_1 = create_program
    create_program
    program_3 = create_program

    programs_identifier = Program.all_selected([program_1.identifier, program_3.identifier]).map(&:identifier)

    programs_identifier.each do |identifier|
      assert_include identifier, [program_1.identifier, program_3.identifier]
    end
  end

  def test_export_dir_name_should_remove_non_word_characters
    program = Program.create!(name: 'prog/ $%with @#nonword chars', identifier:'prog_1')
    assert_equal 'prog_ _with _nonword chars', program.export_dir_name
  end
end
