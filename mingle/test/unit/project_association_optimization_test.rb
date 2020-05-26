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

class ProjectAssociationOptimizationTest < ActiveSupport::TestCase
  def test_project_asscoication_should_return_cached_object
    with_first_project do |project|
      assert_same project, project.property_definitions.first.project
    end
  end
  
  def test_project_asscoication_should_load_correct_project_if_it_is_not_same_with_current_active_project
    with_first_project do |project|
      assert_identifier_equal project_without_cards, project_without_cards.property_definitions.first.project
    end
  end
end
