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

class GithubIntegrationsExporterTest < ActiveSupport::TestCase
  def test_should_export_to_sheet_and_name
    assert GithubIntegrationsExporter.new('').exports_to_sheet?
    assert_equal 'Github integration', GithubIntegrationsExporter.new('').name
  end
  
  def test_sheet_should_contain_correct_github_integrations_data
    login_as_admin
    with_new_project do |project|
      Github.create(:username => "marley", :repository => "another_fun_code", :secret => "confidential", :project_id => project.id, :webhook_id => '67890')
      Github.create(:username => "bob", :repository => "fun_code", :secret => "super_secret", :project_id => project.id, :webhook_id => '12345')

      github_integrations_exporter = GithubIntegrationsExporter.new('')
      sheet = ExcelBook.new('test').create_sheet(github_integrations_exporter.name)
      github_integrations_exporter.export(sheet)

      assert_equal 3, sheet.headings.count
      assert_equal Github.find_all_by_project_id(project.id).count + 1, sheet.number_of_rows
      assert_equal ['Username', 'Repository', 'Webhook ID'], sheet.headings
      assert_equal ['bob', 'fun_code', 12345], sheet.row(1)
      assert_equal ['marley', 'another_fun_code', 67890], sheet.row(2)
    end
  end
end
