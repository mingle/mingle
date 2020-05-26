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

class RemovePropertiesWithMissingColumnsTest < ActiveSupport::TestCase

  def setup
    login_as_admin
  end

  def test_applying_fix_will_remove_property_definitions_whose_columns_do_not_exist
    with_new_project do |project|
      pd_stays = setup_managed_text_definition("stays", ["a", "b"])
      pd_to_remove = setup_managed_text_definition("wontexist", ["a", "b"])

      assert columns_for_cards_table(project).include?("cp_stays")
      assert columns_for_cards_table(project).include?("cp_wontexist")

      project.connection.remove_column(project.cards_table, "cp_wontexist")
      project.connection.remove_column(project.card_versions_table, "cp_wontexist")

      assert columns_for_cards_table(project).include?("cp_stays")
      assert !columns_for_cards_table(project).include?("cp_wontexist")

      assert_not_nil PropertyDefinition.find(pd_stays.id)
      assert_not_nil PropertyDefinition.find(pd_to_remove.id)

      DataFixes::RemovePropertiesWithMissingColumns.apply

      assert_not_nil PropertyDefinition.find(pd_stays.id)
      assert_equal 0, PropertyDefinition.all(:conditions => ["id = ?", pd_to_remove.id]).size
    end
  end

  def test_applying_fix_will_remove_peripheral_objects
    with_new_project do |project|
      card = project.cards.create(:name => "first card", :card_type_name => "card")
      pd_to_remove = setup_managed_text_definition("wontexist", ["a", "b"])
      plv = create_plv!(project, :name => "broken plv", :value => "a")
      plv.update_attributes({:property_definition_ids => [pd_to_remove.id]})

      transition = create_transition(project, 'whatever',
              :card_type => project.card_types.first,
              :required_properties => {:wontexist => 'b'},
              :set_properties => {:wontexist => plv.name})

      StalePropertyDefinition.create!(:card_id => card.id, :project_id => project.id, :prop_def_id => pd_to_remove.id)

      project.connection.remove_column(project.cards_table, "cp_wontexist")

      assert_not_equal(0, pd_to_remove.property_type_mappings.size)
      assert_not_equal(0, pd_to_remove.variable_bindings.size)
      assert_not_equal(0, EnumerationValue.find_all_by_property_definition_id(pd_to_remove.id).size)
      assert_not_equal(0, PropertyDefinitionTransitionAction.find_all_by_target_id(pd_to_remove.id).size)
      assert_not_equal(0, TransitionPrerequisite.find_all_by_property_definition_id(pd_to_remove.id).size)
      assert_not_equal(0, StalePropertyDefinition.find_all_by_prop_def_id(pd_to_remove.id).size)

      DataFixes::RemovePropertiesWithMissingColumns.apply

      assert_equal(0, pd_to_remove.property_type_mappings.size)
      assert_equal(0, pd_to_remove.variable_bindings.size)
      assert_equal(0, EnumerationValue.find_all_by_property_definition_id(pd_to_remove.id).size)
      assert_equal(0, PropertyDefinitionTransitionAction.find_all_by_target_id(pd_to_remove.id).size)
      assert_equal(0, TransitionPrerequisite.find_all_by_property_definition_id(pd_to_remove.id).size)
      assert_equal(0, StalePropertyDefinition.find_all_by_prop_def_id(pd_to_remove.id).size)

      assert_equal(0, PropertyDefinition.all(:conditions => ["id = ?", pd_to_remove.id]).size)
    end
  end

  private

  def columns_for_cards_table(project)
    project.connection.columns(project.cards_table).map(&:name)
  end

  def columns_for_card_versions_table(project)
    project.connection.columns(project.card_versions_table).map(&:name)
  end

end
