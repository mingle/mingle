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

class CardQueryRenamesTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  
  def setup
    @project = card_query_project
    @project.activate
    login_as_member
    @card = @project.cards.find_by_number(1)
  end

  def test_can_rename_property_name_in_is_null_conditions
    assert_property_rename :from => 'old_type', :to => 'new type', :changes => 'old_type IS NULL', :into => "'new type' IS NULL"
  end
  
  def test_can_rename_property_name_in_is_not_null_conditions
    assert_property_rename :from => 'old_type', :to => 'new type', :changes => 'old_type IS NOT NULL', :into => "'new type' IS NOT NULL"
  end
  
  def test_can_rename_property_name_in_is_today_conditions
    assert_property_rename :from => 'date_deleted', :to => 'd_day', :changes => "date_deleted IS TODAY", :into => "d_day IS TODAY"
  end  
  
  def test_can_rename_property_name_in_conditions_that_compare_columns_and_values
    assert_property_rename :from => 'old_type', :to => 'new type', :changes => 'old_type = story', :into => "'new type' = story"
  end  
  
  def test_can_rename_property_name_in_conditions_that_compare_columns_and_other_columns
    assert_property_rename :from => 'old_type', :to => 'new type', :changes => "old_type = PROPERTY freetext1", :into => "'new type' = PROPERTY freetext1"
  end  

  def test_can_rename_property_value_in_conditions_that_compare_columns_and_values
    view = @project.card_list_views.create_or_update(:view => {:name => 'name'}, :filters => {:mql => 'old_type = story'})

    story = @project.find_property_definition('old_type').values.detect { |v| v.value == 'story' }
    story.value = 'st'
    story.save!

    view = @project.card_list_views.find_by_name('name') 
    assert_equal "old_type = st", view.to_params[:filters][:mql]
  end  

  def test_can_rename_property_value_in_IN_clause_conditions
    view = @project.card_list_views.create_or_update(:view => {:name => 'name'}, :filters => {:mql => 'old_type IN (story, foo)'})

    story = @project.find_property_definition('old_type').values.detect { |v| v.value == 'story' }
    story.value = 'st'
    story.save!

    view = @project.card_list_views.find_by_name('name') 
    assert_equal "old_type IN (st, foo)", view.to_params[:filters][:mql]
  end  

  def test_can_rename_property_value_with_spaces_in_IN_clause_conditions
    view = @project.card_list_views.create_or_update(:view => {:name => 'name'}, :filters => {:mql => 'old_type IN (story, foo)'})

    story = @project.find_property_definition('old_type').values.detect { |v| v.value == 'story' }
    story.value = 'big fish story'
    story.save!

    view = @project.card_list_views.find_by_name('name') 
    assert_equal "old_type IN ('big fish story', foo)", view.to_params[:filters][:mql]
  end  

  def test_can_rename_plv_in_column_comparisons
    variable = create_plv!(@project, :name => 'variable', :data_type => ProjectVariable::STRING_DATA_TYPE, :card_type => @project.card_types.first)
    variable.property_definition_ids = [@project.find_property_definition('old_type').id]
    variable.save!
    
    view = @project.card_list_views.create_or_update(:view => {:name => 'view name'}, :filters => {:mql => "old_type = (variable)"})
    variable.name = 'foo'
    variable.save!
    
    @project.project_variables.reload
    
    view = @project.card_list_views.find_by_name('view name') 
    assert_equal 'old_type = (foo)', view.to_params[:filters][:mql]
  end  
  
  # bug 7235
  def test_can_rename_plv_in_explicit_in_clauses
    variable = create_plv!(@project, :name => 'variable', :data_type => ProjectVariable::STRING_DATA_TYPE, :card_type => @project.card_types.first)
    variable.property_definition_ids = [@project.find_property_definition('old_type').id]
    variable.save!
    
    view = @project.card_list_views.create_or_update(:view => {:name => 'name'}, :filters => {:mql => "old_type IN (open, (variable))"})
    
    variable.name = 'foo'
    variable.save!
    
    view = @project.card_list_views.find_by_name('name') 
    assert_equal "old_type IN (open, (foo))", view.to_params[:filters][:mql]
  end
  
  def test_can_rename_plv_to_a_value_with_spaces_in_explicit_in_clauses
    variable = create_plv!(@project, :name => 'variable', :data_type => ProjectVariable::STRING_DATA_TYPE, :card_type => @project.card_types.first)
    variable.property_definition_ids = [@project.find_property_definition('old_type').id]
    variable.save!
    
    view = @project.card_list_views.create_or_update(:view => {:name => 'name'}, :filters => {:mql => "old_type IN ('two words', (variable))"})
    
    variable.name = 'new name'
    variable.save!
    
    view = @project.card_list_views.find_by_name('name') 
    assert_equal "old_type IN ('two words', ('new name'))", view.to_params[:filters][:mql]
  end  

  def test_can_rename_card_type_in_an_equals_clause
    view = @project.card_list_views.create_or_update(:view => {:name => 'name'}, :filters => {:mql => "type=Card"})
    
    story = @project.card_types.find_by_name('Card')
    story.name = 'foo'
    story.save!
    
    view = @project.card_list_views.find_by_name('name') 
    assert_equal "Type = foo", view.to_params[:filters][:mql]
  end  

  def test_can_rename_card_type_in_an_in_clause
    view = @project.card_list_views.create_or_update(:view => {:name => 'name'}, :filters => {:mql => "type IN (Card)"})
    
    story = @project.card_types.find_by_name('Card')
    story.name = 'foo'
    story.save!
    
    view = @project.card_list_views.find_by_name('name') 
    assert_equal "Type IN (foo)", view.to_params[:filters][:mql]
  end  

  def assert_property_rename(options = {:from => nil, :to => nil, :changes => nil, :into => nil})
    view = @project.card_list_views.create_or_update(:view => {:name => 'name'}, :filters => {:mql => options[:changes]})
    rename_property(options[:from], options[:to])
    assert_equal options[:into], @project.card_list_views.find_by_name('name').to_params[:filters][:mql]
  end  

  def rename_property(old_name, new_name)
    old_prop = @project.find_property_definition(old_name)
    old_prop.name = new_name
    old_prop.save!
  end  
end
