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

class CardQueryProjectVariableDetectorTest < ActiveSupport::TestCase
  
  def setup
    login_as_admin
    @project = card_query_project
    @project.activate
    related_card_property = @project.find_property_definition('related card')
    @plv = create_plv!(@project, :name => 'favorite - card', :value => @project.cards.first.id, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definition_ids => [related_card_property.id])
  end
  
  def teardown
    logout_as_nil
  end
  
  def test_should_be_able_to_find_plv_in_where_clause
    assert_project_variables [@plv.name], "SELECT COUNT(*) WHERE 'related card' = (#{@plv.name})"
  end
  
  private
  def detector(mql)
    CardQuery::ProjectVariableDetector.new(CardQuery.parse(mql))
  end
  
  def assert_project_variables(expected_project_variable_names, mql)  
    assert_equal expected_project_variable_names.sort, detector(mql).execute.collect(&:name).sort
  end
end
