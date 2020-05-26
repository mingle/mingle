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

require File.expand_path("../../../unit_test_helper", File.dirname(__FILE__))

class ObjectiveEventsTest < ActiveSupport::TestCase
  def setup
    login_as_admin
    @program = program('simple_program')
    @plan = @program.plan
    @objective = @program.objectives.planned.create(:name => 'first objective', :start_at => '2011-1-1', :end_at => '2011-2-1')
  end

  def test_creating_an_objective_should_create_a_new_event
    event = @objective.versions.first.event
    assert event
    assert_equal 'Program', event.deliverable_type
    assert_equal @program.id, event.deliverable_id
    assert_equal User.current.id, event.created_by_user_id
  end

  def test_deleting_an_objective_should_create_an_objective_delete_event
    assert_difference "ObjectiveDeletionEvent.count", 1 do
      @objective.destroy
    end
  end

  def test_deleting_an_objective_with_the_same_name_as_another_existing_objective_creates_a_new_version_for_delete
    a_program = create_program
    a_program.objectives.planned.create(:name => 'first objective', :start_at => '2011-1-1', :end_at => '2011-2-1')

    assert_difference "ObjectiveDeletionEvent.count", 1 do
      @objective.destroy
    end
  end

end
