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

class RenamedEnumerationValueMqlGenerationTest < ActiveSupport::TestCase
  def setup
    @project = card_query_project
    @project.activate
    login_as_member
  end
  
  def test_should_be_able_to_rename_value_in_single_condition
    assert_equal "Feature = 'Project Monitoring'",  change_value('feature = Dashboard', 'Feature', 'Dashboard', 'Project Monitoring')
  end

  def test_should_not_rename_columns_with_similar_names
    assert_equal "Feature = 'Project Monitoring' AND 'Feature Thing' = Dashboard",  change_value('feature = Dashboard AND "Feature Thing" = "Dashboard"', 'Feature', 'Dashboard', 'Project Monitoring')
  end
  
  def test_should_be_able_to_rename_value_in_an_in_clause
    assert_equal "Feature IN ('Info Radiator', Notifications)",  change_value('feature IN (Dashboard, Notifications)', 'Feature', 'Dashboard', 'Info Radiator')
  end
  
  def test_should_be_able_to_rename_value_in_composite_condition
    assert_equal "((Feature = Applications) OR (Feature = 'Project Monitoring'))",  change_value('Feature = Applications or Feature = Dashboard', 'Feature', 'Dashboard', 'Project Monitoring')
  end
  
  def change_value(query_str, property_name, old_value, new_value)
    query = CardQuery.parse(query_str)
    CardQuery::RenamedEnumerationValueMqlGeneration.new(property_name, old_value, new_value, query).execute
  end
  
  
end
