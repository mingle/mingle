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

class RemoveOrphanedPropertyColumnsTest < ActiveSupport::TestCase

  def setup
    login_as_admin
  end

  def test_applying_fix_will_remove_orphaned_property_columns_from_cards_and_card_versions_tables
    with_new_project do |project|
      setup_managed_text_definition("a text prop", ["a", "b"])
      project.connection.add_column(project.cards_table, "cp_orphan", :string)
      project.connection.add_column(project.card_versions_table, "cp_orphan", :string)

      expected_columns = columns_for_cards_table(project)
      assert expected_columns.include?("cp_orphan")
      assert expected_columns.include?("cp_a_text_prop")

      expected_version_columns = columns_for_card_versions_table(project)
      assert expected_version_columns.include?("cp_orphan")
      assert expected_version_columns.include?("cp_a_text_prop")

      DataFixes::RemoveOrphanedPropertyColumns.apply([ project.id ])

      expected_columns = columns_for_cards_table(project)
      assert !expected_columns.include?("cp_orphan")
      assert expected_columns.include?("cp_a_text_prop")

      expected_version_columns = columns_for_card_versions_table(project)
      assert !expected_version_columns.include?("cp_orphan")
      assert expected_version_columns.include?("cp_a_text_prop")
    end
  end

  def test_should_return_project_ids_that_have_orphaned_columns
    with_new_project do |project|
      setup_managed_text_definition("a text prop", ["a", "b"])
      project.connection.add_column(project.cards_table, "cp_orphan", :string)
      project.connection.add_column(project.card_versions_table, "cp_orphan", :string)

      assert_equal project.id.to_s, DataFixes::RemoveOrphanedPropertyColumns.project_ids_with_orphans[0].to_s
    end
  end

  def test_required_check_returns_true_when_card_table_contains_a_column_not_present_in_property_definitions_table
    with_new_project do |project|
      setup_managed_text_definition("a text prop", ["a", "b"])

      assert_false DataFixes::RemoveOrphanedPropertyColumns.required?

      project.connection.add_column(project.cards_table, "cp_orphan", :string)
      project.connection.add_column(project.card_versions_table, "cp_orphan", :string)

      assert DataFixes::RemoveOrphanedPropertyColumns.required?
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
