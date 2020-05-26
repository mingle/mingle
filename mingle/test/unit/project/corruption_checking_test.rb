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

class Project::CorruptionCheckingTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree  

  class BadSchema < Null
    def column_not_insync_properties
      raise "error under searching"
    end
  end

  def setup
    @project = create_project
    @project.activate
    login_as_admin
  end
  
  def test_corruption_info_should_be_empty_for_fresh_project
    assert_false @project.corrupt?
  end

  def test_after_corruption_check_state_should_be_set
    corruption_check
    assert @project.reload.corruption_checked?
    assert_false @project.corrupt?
  end
  
  def test_should_report_corruption_on_column_not_find
    setup_missing_column_property_definition('iteration')
    corruption_check
    
    assert @project.reload.corruption_checked?
    assert @project.corrupt?
    assert_include "Property <%= link_to '#{'iteration'.bold}', property_definitions_list_url, :title => 'click to go to card properties page to delete' %> is corrupt", @project.corruption_info
  end
  
  def test_member_should_get_different_corruption_message
    iteration = setup_missing_column_property_definition('iteration')
    corruption_check
    login_as_member
    assert_equal "Mingle found a problem it couldn't fix. Please contact your Mingle administrator. When the administrator accesses this project they should be able to rectify the issue by deleting the corrupt property.", @project.corruption_info
  end
  
  def test_should_report_for_all_property_column_absent
    setup_missing_column_property_definition('iteration', 'status')
    corruption_check
    assert @project.reload.corrupt?
    assert_include "<%= link_to '#{'iteration'.bold}', property_definitions_list_url, :title => 'click to go to card properties page to delete' %>", @project.corruption_info
    assert_include "<%= link_to '#{'status'.bold}', property_definitions_list_url, :title => 'click to go to card properties page to delete' %>", @project.corruption_info
  end
  
  def test_for_aggregate_property_link_should_point_to_aggregate_config_link
    tree_configuration = @project.tree_configurations.create!(:name => 'Release tree')
    init_three_level_tree(tree_configuration)

    aggregate_count_on_release = setup_aggregate_property_definition('count for release', 
                  AggregateType::COUNT, 
                  nil, 
                  tree_configuration.id, 
                  tree_configuration.all_card_types.first.id, 
                  AggregateScope::ALL_DESCENDANTS)

    @project.card_schema.remove_column(aggregate_count_on_release.column_name, aggregate_count_on_release.index_column?)
    @project.reload
    corruption_check
    assert_not_include "property_definitions_list_url", @project.corruption_info
    assert_include "edit_aggregate_properties_url(:id => #{tree_configuration.id})", @project.corruption_info
  end
  
  def test_for_relationship_property_should_only_name_without_link
    tree_configuration = @project.tree_configurations.create!(:name => 'Release tree')
    init_three_level_tree(tree_configuration)
    relationship_property_definition = tree_configuration.relationships.first
    @project.card_schema.remove_column(relationship_property_definition.column_name, relationship_property_definition.index_column?)
    @project.reload
    corruption_check
    info = MingleFormatting.replace_mingle_formatting(@project.corruption_info)
    assert_not_include "property_definitions_list_url", info
    assert_include relationship_property_definition.name, info
    assert_not_include tree_configuration.id.to_s, info
  end
  
  def test_should_be_able_to_recover_from_corruption_state_by_deleting_the_property
    setup_missing_column_property_definition('iteration')
    corruption_check
    assert @project.corrupt?
    @project.find_property_definition('iteration').destroy
    @project.reload
    corruption_check
    assert_false @project.corrupt?
  end
  
  def test_should_ensure_set_checked_flag_to_avoid_redirecting_loop_when_error_happened_during_checking
    def @project.card_schema
      BadSchema.new
    end
    User.with_first_admin { @project.update_attribute(:corruption_checked, false) }
    assert_raise(RuntimeError) { corruption_check }
    assert @project.reload.corruption_checked?
  end

  def setup_missing_column_property_definition(*property_names)
    property_names.each do |property_name|
      setup_property_definitions property_name => [1, 2, 3]
    end

    property_names.each do |property_name|
      property = @project.find_property_definition(property_name)
      @project.card_schema.remove_column(property.column_name, property.index_column?)
    end
  end

  def corruption_check
    @project.corruption_check
  end
end
