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

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class ModelFreeImportTest < ActiveSupport::TestCase
  module ProjectImportStubbing
    def project_identifier
      "model_free_test"
    end

    def table(name)
      []
    end

    def schema_version
      ActiveRecord::Migrator.current_version
    end
  end

  def setup
    @project_importer = ModelFreeImport.new
    @project_importer.extend(ProjectImportStubbing)
  end

  def test_should_create_same_card_schema_with_create_project_did
    @project_importer.create_card_and_card_version_tables
    with_new_project do |project|
      assert_sort_equal column_names(Card.table_name), column_names(@project_importer.card_table_name)
      assert_sort_equal column_names(Card::Version.table_name), column_names(@project_importer.card_version_table_name)
    end
  ensure
    Project.connection.drop_table(@project_importer.card_table_name)
    Project.connection.drop_table(@project_importer.card_version_table_name)
  end

  def column_names(table_name)
    Project.connection.columns(table_name).collect(&:name)
  end
end
