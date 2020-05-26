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

require File.expand_path(File.dirname(__FILE__) + '/project_import_export_test_helper')

# this test will fail if there's residue in the database
# and we are having trouble with transactionality in this test
# let's ensure there's nothing weird there before we start the test
class ImportExportAggregatePropertiesTest < ActiveSupport::TestCase
  include ProjectImportExportTestHelper
  
  # bug 6536
  def test_importing_aggregates_should_set_target_property_ids_to_new_id
    @user = login_as_member
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      login_as_admin
      type_release, type_iteration, type_story = find_planning_tree_types
      
      # create size property definition
      size = setup_numeric_property_definition("size", [1, 2, 3, 4])
      type_story.add_property_definition(size)
      
      # create aggregate
      options = { :name => 'Sum of size',
                  :aggregate_scope => type_story,
                  :aggregate_type => AggregateType::SUM,
                  :aggregate_card_type_id => type_iteration.id,
                  :tree_configuration_id => configuration.id,
                  :target_property_definition => size.reload
                }
      sum_of_size = project.all_property_definitions.create_aggregate_property_definition(options)
      project.reload.update_card_schema
      
      # create priority after creating the aggregate, so that priority's id is higher and it will be imported after the aggregate
      priority = setup_numeric_property_definition("priority", [1, 2, 3, 4])
      assert priority.id > sum_of_size.id
      
      # change the aggregate to operate on priority instead of size
      sum_of_size.target_property_definition = priority
      sum_of_size.save!
      
      # now export and import, and ensure the aggregate's target property is set correctly (it used to be nil)
      export_file = create_project_exporter!(project, User.current).export
      imported_project = create_project_importer!(User.current, export_file).process!
      imported_project.reload
      new_target_property_definition = imported_project.find_property_definition('Sum of size').target_property_definition
      assert_equal priority.name, new_target_property_definition.name
    end
  end
  
  # bug 7031
  def test_importing_aggregates_with_dependent_formulas_should_set_dependent_formulas_to_new_formula_ids
    @user = login_as_member

    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      login_as_admin
      type_release, type_iteration, type_story = find_planning_tree_types
      
      # create size property definition
      size = setup_numeric_property_definition("size", [1, 2, 3, 4])
      type_story.add_property_definition(size)
      
      # create aggregate
      options = { :name => 'Sum of size',
                  :aggregate_scope => type_story,
                  :aggregate_type => AggregateType::SUM,
                  :aggregate_card_type_id => type_iteration.id,
                  :tree_configuration_id => configuration.id,
                  :target_property_definition => size.reload
                }
      sum_of_size = project.all_property_definitions.create_aggregate_property_definition(options)
      project.reload.update_card_schema
      
      # create formula that uses the aggregate
      formula = setup_formula_property_definition("formula", "'#{sum_of_size.name}' + 1000")
      formula.card_types = [type_iteration]
      formula.save!
      assert_equal [formula.id], sum_of_size.reload.dependant_formulas
      
      # now export and import, and ensure the aggregate's dependent formulas has the newly imported formula's id, not the old formula's id
      export_file = create_project_exporter!(project, User.current).export
      imported_project = create_project_importer!(User.current, export_file).process!
      imported_project.reload
      
      imported_formula_pd = imported_project.find_property_definition('formula')
      imported_aggregate_pd = imported_project.find_property_definition('Sum of size')
      
      assert_not_equal imported_formula_pd.id, formula.id   # if this assertion fails, our test is meaningless -- we'd like the imported id to be different
      assert_equal [imported_formula_pd.id.to_s], imported_aggregate_pd.dependant_formulas.map(&:to_s)
    end
  end
end
