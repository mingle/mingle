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

class BacklogObjectiveTest < ActiveSupport::TestCase
  def setup
    login_as_admin
    @program = program('simple_program')
  end

  def test_can_assign_objectives_to_backlog
    @program.objectives.backlog.create!({:name => 'objective z'})
    assert_equal 1, @program.objectives.backlog.size
  end

  def test_uniqueness_of_backlog_objective_names
    assert_raise(ActiveRecord::RecordInvalid) { @program.objectives.backlog.create!({:name => 'objective a'}) }
    assert_equal 0, @program.reload.objectives.backlog.size

    assert_raise(ActiveRecord::RecordInvalid) { @program.objectives.backlog.create!({:name => 'Objective A'}) }
    assert_equal 0, @program.objectives.backlog.size
  end

  def test_backlog_objectives_are_sorted_as_last_inserted_on_top
    @program.objectives.backlog.create!({:name => 'A'})
    @program.objectives.backlog.create!({:name => 'B'})
    @program.objectives.backlog.create!({:name => '1'})
    assert_equal 3, @program.objectives.backlog.find_by_name('A').position
    assert_equal 2, @program.objectives.backlog.find_by_name('B').position
    assert_equal 1, @program.objectives.backlog.find_by_name('1').position
  end

  def test_validates_existance_of_plan_objectives_before_creating_backlog_objective
    @program.objectives.planned.create!(:name => "lenticular", :start_at => Clock.now, :end_at => Clock.now)
    backlog_objective = @program.objectives.backlog.create(:name => "lenticular")
    assert_false backlog_objective.valid?
    assert_equal "Name already used for an existing Feature.", backlog_objective.errors.full_messages.first

    # test for case insensitivity
    backlog_objective = @program.objectives.backlog.create(:name => "LeNtiCulAr")
    assert_false backlog_objective.valid?
    assert_equal "Name already used for an existing Feature.", backlog_objective.errors.full_messages.first
  end

  def test_validates_existance_of_backlog_objectives_before_creating_backlog_objective
    @program.objectives.backlog.create!({:name => 'A'})

    duplicated_objective = @program.objectives.backlog.create({:name => 'A'})
    assert_false duplicated_objective.valid?
    assert_equal "Name already used for an existing Feature.", duplicated_objective.errors.full_messages.first

    # test for case insensitivity
    duplicated_objective = @program.objectives.backlog.create({:name => 'a'})
    assert_false duplicated_objective.valid?
    assert_equal "Name already used for an existing Feature.", duplicated_objective.errors.full_messages.first
  end

  def test_after_backlog
    @program.objectives.backlog.create!({:name => 'A'})
    objective_B = @program.objectives.backlog.create!({:name => 'B'})
    objectives_after_B = @program.objectives.backlog.after(objective_B)
    assert_equal ['A'], objectives_after_B.map(&:name)
  end

  def test_on_delete_updates_position
    @program.objectives.backlog.create!({:name => 'A'})
    objective_B = @program.objectives.backlog.create!({:name => 'B'})
    objective_B.destroy
    objective_A = @program.objectives.backlog.find_by_name("A")
    assert_equal 1, objective_A.position
  end

  def test_updating_objective_value_statement
    @program.objectives.backlog.create!(:name => "test")
    backlog_objective = @program.objectives.backlog.first
    assert_nil @program.objectives.backlog.first.value_statement

    expected = "I am valuable."
    backlog_objective.value_statement = expected
    backlog_objective.save!
    assert_equal expected, backlog_objective.value_statement
  end

  def test_number_is_assigned_on_create
    backlog_objective = @program.objectives.backlog.create!(:name => 'test')

    current_number = backlog_objective.number
    assert_not_nil current_number

    second_backlog_objective = @program.objectives.backlog.create!(:name => 'test2')
    assert_equal current_number + 1, second_backlog_objective.number
  end

end
