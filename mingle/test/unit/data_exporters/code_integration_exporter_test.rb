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

class CodeIntegrationExporterTest < ActiveSupport::TestCase

  def test_should_export_to_sheet_and_name
    with_first_project do |p|
      assert CodeIntegrationExporter.new('').exports_to_sheet?
      assert_equal 'Code integration', CodeIntegrationExporter.new('').name
    end
  end

  def test_sheet_should_contain_the_correct_code_integration_data_for_a_non_tfs_repository
    login_as_admin

    with_first_project do |project|
      config = SubversionConfiguration.create!({:project_id => project.id, :repository_path => 'for_repository', :username => 'first_user'})
      project.reload

      code_integration_exporter = CodeIntegrationExporter.new('')
      sheet = ExcelBook.new('test').create_sheet(code_integration_exporter.name)
      code_integration_exporter.export(sheet)

      assert_equal 3, sheet.headings.count
      assert_equal 2, sheet.number_of_rows
      assert_equal ['Username', 'Repository Type', 'Repository Path'], sheet.headings
      assert_equal [config.username, SubversionConfiguration.display_name, config.repository_path], sheet.row(1)
    end
  end

  def test_sheet_should_contain_the_correct_tfs_scm_config_data
    login_as_admin

    with_first_project do |project|
      config = TfsscmConfiguration.create!({:project_id => project.id, :username => 'first_user', :server_url => 'url', :domain => 'mingle', :collection => 'default_collection', :tfs_project => 'my_project', :password => 'secret'})
      project.reload

      code_integration_exporter = CodeIntegrationExporter.new('')
      sheet = ExcelBook.new('test').create_sheet(code_integration_exporter.name)
      code_integration_exporter.export(sheet)

      assert_equal 6, sheet.headings.count
      assert_equal 2, sheet.number_of_rows
      assert_equal ['Username', 'Repository Type', 'Server URL', 'Domain', 'Collection', 'Project'], sheet.headings
      assert_equal [config.username, TfsscmConfiguration.display_name, config.server_url, config.domain, config.collection, config.tfs_project], sheet.row(1)
    end
  end
end
