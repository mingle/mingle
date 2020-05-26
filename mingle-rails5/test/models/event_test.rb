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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class EventTest < ActiveSupport::TestCase
  def setup
    create(:admin, login: :admin)
    login_as_admin
    @program = create(:program)
  end

  context 'EventValidations' do
    subject { create(:event, origin: create(:objective,:planned, program_id: @program.id),deliverable_id: @program.id, type: ObjectiveVersionEvent)}
    should belong_to(:origin)
    should belong_to(:deliverable)
    should belong_to(:created_by).with_foreign_key(:created_by_user_id)

    should validate_uniqueness_of(:origin_id).scoped_to([:origin_type, :type, :deliverable_id])
  end

  def test_should_store_program_and_created_at_and_user_id_and_type_as_program
    objective = create(:objective, :backlog, program_id: @program.id)

    version = objective.versions.first
    version.reload
    assert_equal @program.id, version.event.deliverable_id
    assert_equal version.updated_at, version.event.created_at
    assert_equal version.modified_by_user_id, version.event.created_by_user_id
    assert_equal 'Program', version.event.deliverable_type
  end

  def test_event_should_contain_origin_info
    objective = create(:objective, :backlog, program_id: @program.id)

    version = objective.versions.first
    version.reload
    assert_equal @program.id, version.event.deliverable_id
    assert_equal "Objective::Version", version.event.origin_type
    assert_equal version.id, version.event.origin_id

  end

  def test_event_objective_version_should_create_objective_version_event
    objective_version = mock('ObjectiveVersion')
    ObjectiveVersionEvent.stubs(:create!).with({value:'value', origin:objective_version})
    Event.objective_version(objective_version,{value: 'value'})
  end

  def test_event_objective_deletion_version_should_create_objective_deletion_version_event
    objective_version = mock('ObjectiveVersion')
    ObjectiveDeletionEvent.stubs(:create!).with({value:'value', origin:objective_version})
    Event.objective_deletion(objective_version,{value: 'value'})
  end

  def test_event_program_scope_should_yield_with_given_params
    program_id = 1
    updated_at = Time.now
    user_id = 23
    Event.with_program_scope(program_id, updated_at, user_id) do |options|
      assert_equal program_id, options[:deliverable_id]
      assert_equal updated_at, options[:created_at]
      assert_equal user_id, options[:created_by_user_id]
      assert_equal 'Program', options[:deliverable_type]
    end
  end


end
