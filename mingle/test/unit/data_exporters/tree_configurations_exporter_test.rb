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

class TreeConfigurationsExporterTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def test_should_export_to_sheet_and_name
    assert TreeConfigurationsExporter.new('').exports_to_sheet?
    assert_equal 'Trees', TreeConfigurationsExporter.new('').name
  end

  def test_sheet_should_contain_correct_tree_configuration_data
    login_as_admin
    with_new_project do |project|
      configuration = project.tree_configurations.create!(:name => 'Planning', :description => 'desc')
      type_release, type_iteration, type_story = init_planning_tree_types
      init_three_level_tree(configuration)
      estimate_prop_def = project.create_text_list_definition!(:name => 'estimate', :type => 'number list', :description => 'It is a number list property', :hidden => true, :is_numeric => true)
      release_agg_prop_options = {
          :name => 'release aggregate prop def',
          :description => 'it is a aggregate property',
          :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
          :aggregate_type => AggregateType::AVG,
          :aggregate_card_type_id => type_release.id, :tree_configuration_id => configuration.id}
      iteration_agg_prop_options = {
          :name => 'iteration aggregate prop def',
          :description => 'it is a aggregate property',
          :aggregate_scope => AggregateScope::ALL_DESCENDANTS,
          :aggregate_type => AggregateType::AVG,
          :aggregate_card_type_id => type_iteration.id, :tree_configuration_id => configuration.id,
          :aggregate_target_id => estimate_prop_def.id,
          :aggregate_condition => 'type = story'}

      release_agg_prop_options.merge!(:aggregate_target_id => estimate_prop_def.id)
      release_aggregate_prop_def = project.create_aggregate_property_definition!(release_agg_prop_options)
      iteration_aggregate_prop_def = project.create_aggregate_property_definition!(iteration_agg_prop_options)

      tree_configurations_exporter = TreeConfigurationsExporter.new('')
      sheet = ExcelBook.new('test').create_sheet(tree_configurations_exporter.name)
      tree_configurations_exporter.export(sheet)

      assert_equal 8, sheet.headings.count
      assert_equal 3, sheet.number_of_rows
      assert_equal ['Tree name', 'Tree Description', 'Parent Node', 'Child Node', 'Linking Property', 'Aggregate property', 'Aggregate formula', 'Aggregate Scope'], sheet.headings
      assert_equal [configuration.name, configuration.description, type_release.name, type_iteration.name, 'Planning release', release_aggregate_prop_def.name, 'Average of estimate', 'All'], sheet.row(1)
      assert_equal [configuration.name, configuration.description, type_iteration.name, type_story.name, 'Planning iteration', iteration_aggregate_prop_def.name, 'Average of estimate', 'type = story'], sheet.row(2)
    end
  end

  def test_should_be_exportable_when_tree_property_definitions_are_defined
    login_as_admin
    with_new_project do |project|
      project.tree_configurations.create!(:name => 'Planning', :description => 'desc')
      init_planning_tree_types

      tree_configurations_exporter = TreeConfigurationsExporter.new('')
      assert tree_configurations_exporter.exportable?
    end
  end

  def test_should_not_be_exportable_when_tree_property_definitions_are_not_defined
    login_as_admin
    with_new_project do
      tree_configurations_exporter = TreeConfigurationsExporter.new('')
      assert_false tree_configurations_exporter.exportable?
    end
  end
end
