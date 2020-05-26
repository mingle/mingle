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

class PropertyValueCollectionTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    @project.activate
    login_as_member
  end
  
  def test_generate_from_params_using_method_get_should_use_param_value_as_url_identifier
    first_user = User.find_by_login('first')
    property_values = PropertyValueCollection.from_params(@project, {'dev' => 'first'}, :method => 'get')
    assert_equal 1, property_values.size
    assert_equal first_user.name, property_values.first.display_value
  end

  def test_generate_from_params_not_specify_method_should_use_param_value_as_db_identifier
    first_user = User.find_by_login('first')
    property_values = PropertyValueCollection.from_params(@project, {'dev' => first_user.id}, :method => 'get')
    assert_equal 1, property_values.size
    assert_equal first_user.name, property_values.first.display_value
  end

  def test_generate_from_params_using_time_object_should_use_project_date_format
    property_values = PropertyValueCollection.from_params(@project, {'start date' => Time.parse('2010/11/20')})
    assert_equal '2010-11-20', property_values.first.db_identifier
  end
  
  def test_generate_from_params_ignores_non_existant_properties
    property_values = PropertyValueCollection.from_params(@project, {'not_exist' => '2', 'status' => 'new'})
    assert_equal 1, property_values.size
    assert_equal 'Status', property_values.first.name
  end
  
  def test_generate_from_params_by_default_should_not_include_hidden_properties
    @project.find_property_definition('status').update_attribute(:hidden, true)
    property_values = PropertyValueCollection.from_params(@project.reload, {'iteration' => '2', 'status' => 'new'})
    assert_equal 1, property_values.size    
  end
  
  def test_generate_from_params_should_include_hidden_properties_with_include_hidden_option
    @project.find_property_definition('status').update_attribute(:hidden, true)
    property_values = PropertyValueCollection.from_params(@project.reload, {'iteration' => '2', 'status' => 'new'}, :include_hidden => true)
    assert_equal 2, property_values.size    
  end
  
  def test_should_always_make_card_type_value_the_first_property_value
    property_values = PropertyValueCollection.from_params(@project, {'iteration' => '2', 'status' => 'new', 'type' => 'card'})
    assert_equal 'Type', property_values.first.name
  end
  
  def test_sort_by_position
    @project.find_property_definition('iteration').update_attribute(:position, 10)
    @project.find_property_definition('status').update_attribute(:position, 5)
    property_values = PropertyValueCollection.from_params(@project, {'iteration' => '2', 'status' => 'new', 'type' => 'card'})
    assert_equal ['Type', 'Status', 'Iteration'], property_values.collect(&:name)
  end
  
  def test_delete_value
    @project.find_property_definition('iteration').update_attribute(:position, 10)
    @project.find_property_definition('status').update_attribute(:position, 5)
    property_values = PropertyValueCollection.from_params(@project, {'iteration' => '2', 'status' => 'new', 'type' => 'card'})
    property_values.delete!(property_values.first)
    assert_equal ['Status', 'Iteration'], property_values.collect(&:name)
  end
  
  def test_add
    property_values = PropertyValueCollection.from_params(@project, {'iteration' => '2', 'status' => 'new', 'type' => 'card'})
    prop_value = property_values.first
    property_values.delete!(prop_value)
    property_values << prop_value
    assert property_values.collect(&:name).include?('Type')
  end
  
  def test_should_parsing_out_plv_property_values
    iteration = @project.find_property_definition('iteration')
    create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1', :property_definition_ids =>[ iteration.id] )
    
    property_values = PropertyValueCollection.from_params(@project, {'iteration' => '(current iteration)', 'status' => 'new', 'type' => 'card'})
    current_iteration = property_values.detect{ |property_value| property_value.name == 'Iteration'  }
    assert current_iteration
    assert_equal VariableBinding, current_iteration.class
  end
  
  def test_assigning_card_with_plv_porperty_value
    iteration = @project.find_property_definition('iteration')
    create_plv!(@project, :name => 'current iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '1', :property_definition_ids =>[ iteration.id] )
    property_values = PropertyValueCollection.from_params(@project, {'iteration' => '(current iteration)', 'status' => 'new', 'type' => 'card'})
    card = Card.new(:name => 'new card')
    property_values.assign_to(card)
    assert_equal 'new', card.cp_status
    assert_equal '1', card.cp_iteration
  end
  
end
