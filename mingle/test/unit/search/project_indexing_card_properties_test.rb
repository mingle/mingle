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

class ProjectTest < ActiveSupport::TestCase

  def test_properties_to_index_should_include_user_or_enumerated_or_text_property_definitions
    with_new_project do |project|
      login_as_admin
      formula_property = setup_formula_property_definition('one third', '1/3')
      setup_property_definitions(:status => ['new', 'open'])
      setup_user_definition("owner")
      setup_text_property_definition('hiya')
      setup_numeric_text_property_definition('any number')

      story_card_type = setup_card_type(project, 'story', :properties => ['status', 'one third', 'owner', 'hiya', 'any number'])

      assert_equal ['any number', 'hiya', 'owner', 'status'], project.properties_to_index.map(&:name).sort
    end
  end


end
