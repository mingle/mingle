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

class PropertyDefinitionsHelperTest < ActiveSupport::TestCase
  include PropertyDefinitionsHelper, ActionView::Helpers::TextHelper, ActionView::Helpers::UrlHelper
  
  def test_any_text_property_definitions_should_display_any_text_as_property_values
    first_project.activate
    @property_definition = first_project.find_property_definition('id')
    assert_equal 'Any text', create_property_values_description(@property_definition) 
  end
  
  def test_card_relationship_property_definition_should_show_that_it_is_a_generic_card
    User.with_current(User.find_by_login('admin')) do
      with_new_project do |project|
        jimmy = project.create_card_relationship_property_definition(:name => 'jimmy')
        assert_equal 'Any card', create_property_values_description(jimmy)
      end
    end
  end
end
