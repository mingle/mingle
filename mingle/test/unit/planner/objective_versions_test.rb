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

class ObjectiveVersionsTest < ActiveSupport::TestCase
  def setup
    login_as_admin
    @program = create_program
    @plan = @program.plan
  end
  
  def test_creating_an_objective_creates_one_version
    assert_difference "Objective::Version.count", 1 do
      @objective = @program.objectives.planned.create(:name => 'first objective', :start_at => '2011-1-1', :end_at => '2011-2-1')
    end
    assert_equal 1, @objective.versions.count
    first_version = @objective.versions.first
    assert_equal @objective.modified_by, first_version.modified_by
    assert_equal @objective.program_id, first_version.program_id
  end

  def test_updating_an_objective_attribute_creates_a_new_version
    objective = @program.objectives.planned.create(:name => 'first objective', :start_at => '2011-1-1', :end_at => '2011-2-1')
    objective.update_attributes :name => 'A first objective'
    assert_equal 2, objective.versions.count

    objective.update_attributes :name => 'updated first objective'
    assert_equal 3, objective.versions.count

    objective.versions.each do |version|
      assert_equal objective.id, version.objective_id
    end
  end

  def test_deleting_an_objective_creates_a_new_version
    objective = @program.objectives.planned.create(:name => 'first objective', :start_at => '2011-1-1', :end_at => '2011-2-1')
    assert_difference 'objective.versions.count', 1 do
      objective.destroy
    end
  end
end
