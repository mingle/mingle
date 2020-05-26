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
class ImportExportProjectVariablesTest < ActiveSupport::TestCase
  include ProjectImportExportTestHelper
  
  def test_export_import_project_variables
    @user = login_as_member
    @project = with_new_project do |project|
      setup_property_definitions :status => ['new', 'open', 'fixed'], :iteration => [1,2], :release => [1]
      status = project.find_property_definition('status')
      create_plv!(project, :name => 'CURRENT IT', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => '5', :property_definitions => [status])
      project
    end
    @export_file = create_project_exporter!(@project, @user, :template => true).export
    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!

    assert_equal 1, imported_project.project_variables.size
    assert_equal 'CURRENT IT', imported_project.project_variables.find_by_name('CURRENT IT').name
    assert_equal 1, imported_project.project_variables.find_by_name('CURRENT IT').property_definitions.size
    assert_equal 'status', imported_project.project_variables.find_by_name('CURRENT IT').property_definitions.first.name
  end
  
  # Bugs 6594 and 6582
  def test_export_import_project_variables_that_use_user_properties_should_change_values_to_new_user_ids
    @user = login_as_member
    with_new_project do |project|
      timmy = create_user!(:login => 'bug6594and6582', :name => 'bug6594and6582 name')
      project.add_member(@user)
      project.add_member(timmy)
      cp_owner = setup_user_definition('owner')
      project_variable = create_plv!(project, :name => 'favorite user', :value => timmy.id, :data_type => ProjectVariable::USER_DATA_TYPE, :property_definition_ids => [cp_owner.id])
      @export_file = create_project_exporter!(project, @user).export
      project.project_variables.first.destroy
      project.remove_member(timmy)
      timmy.destroy
      assert_nil project.connection.select_value("Select login from users where login='bug6594and6582'"), "bug6594and6582 name should have been removed before re-importing the project."
      @project_importer = create_project_importer!(User.current, @export_file)
      imported_project = @project_importer.process!
      imported_project.reload
      
      assert_equal 'bug6594and6582 name', imported_project.project_variables.first.display_value
    end
  end
  
  def test_export_import_project_variables_that_use_card_properties_should_change_values_to_new_card_ids
    @user = login_as_member
    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      type_release, type_iteration, type_story = find_planning_tree_types
      iteration1 = project.cards.find_by_name('iteration1')
      cp_iteration = project.find_property_definition('Planning iteration')
      
      project_variable = create_plv!(project, :name => 'current iteration', :value => iteration1.id, :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definition_ids => [cp_iteration.id])
      
      @export_file = create_project_exporter!(project, @user).export
      @project_importer = create_project_importer!(User.current, @export_file)
      imported_project = @project_importer.process!

      iteration1 = imported_project.cards.find_by_name('iteration1')
      type_iteration = imported_project.card_types.find_by_name('iteration')
      assert_equal 1, imported_project.project_variables.size
      
      imported_project.reload
      
      assert_equal iteration1.id.to_s, imported_project.project_variables.first.value
      assert_equal type_iteration.id, imported_project.project_variables.first.card_type_id
    end
  end
  
  def test_should_maintain_associations_to_property_definitions_from_plvs_if_exporting_project_as_template
    @user = login_as_member
    @project = create_project(:users => [@user])
    owner = setup_user_definition('owner')
    me =  create_plv!(@project, :name => 'me', :property_definition_ids => [owner.id], :value => User.current.id.to_s, :data_type => ProjectVariable::USER_DATA_TYPE)
    my_cards = create_named_view('my cards', @project, :filters => ['[owner][is][(me)]'])
    
    @export_file = create_project_exporter!(@project, User.current, :template => true).export
    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!

    imported_my_cards = imported_project.card_list_views.find_by_name('my cards')
    assert !imported_my_cards.filters.invalid?
  end
end
