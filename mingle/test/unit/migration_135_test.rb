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
require File.expand_path(File.dirname(__FILE__) + '/../../db/migrate/135_reorder_numeric_property_definition_values.rb')

class Migration135Test < ActiveSupport::TestCase
  def test_reorder_numeric_property_defintion_values
    with_new_project do |project|
      setup_numeric_property_definition('size', ['1','3', '5', '8'])
      size = project.find_property_definition('size')
      size.find_enumeration_value('1').update_attributes(:position => 6, :nature_reorder_disabled => true)
      size.find_enumeration_value('3').update_attributes(:position => 5, :nature_reorder_disabled => true)
      assert_equal ['5', '8','3','1'], size.enumeration_values.sort_by(&:position).collect(&:value)
      ReorderNumericPropertyDefinitionValues.up
      project.reload
      assert_equal ['1','3','5', '8'], size.enumeration_values.sort_by(&:position).collect(&:value)
    end
  end
  
  def test_reorder_numeric_property_defintion_should_not_reorder_text_property_definition
    with_new_project do |project|
      setup_property_definitions(:estimate => ['8', '5', '1', '3'])
      estimate = project.find_property_definition('estimate')
      assert_equal ['8', '5','1','3'], estimate.enumeration_values.sort_by(&:position).collect(&:value)
      ReorderNumericPropertyDefinitionValues.up
      assert_equal ['8', '5','1','3'], estimate.enumeration_values.sort_by(&:position).collect(&:value)
    end
  end
  
  def test_numerci_property_definition_should_sort_by_number
    with_new_project do |project|
      setup_numeric_property_definition('size', ['10','1', '7', '0.60'])
      size = project.find_property_definition('size')
      assert_equal  ['10','1', '7', '0.60'], size.enumeration_values.sort_by(&:position).collect(&:value)
      ReorderNumericPropertyDefinitionValues.up
      project.reload
      assert_equal ['0.60', '1', '7', '10'], size.enumeration_values.sort_by(&:position).collect(&:value)
    end
  end
end
