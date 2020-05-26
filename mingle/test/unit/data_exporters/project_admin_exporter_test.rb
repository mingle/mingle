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

class ProjectAdminExporterTest < ActiveSupport::TestCase
  
  def test_should_export_to_sheet_and_name
    assert ProjectAdminExporter.new('').exports_to_sheet?
    assert_equal 'Project admins', ProjectAdminExporter.new('').name
  end

  def test_sheet_should_contain_project_admins_data
    login_as_admin
    with_new_project(:name => 'zzzz') do |project|

    first_admin = create_user!(:login => "first_user", :email => "first_user@email.com", :name => "first_user", :password => "newpassword1.", :password_confirmation => "newpassword1.", :admin => true)
    second_admin = create_user!(:login => "second_user", :email => "second_user@email.com", :name => "second_user", :password => "newpassword1.", :password_confirmation => "newpassword1.", :admin => true)

    project.add_member(first_admin, MembershipRole[:project_admin])
    project.add_member(second_admin, MembershipRole[:project_admin])

    project_admin_exporter = ProjectAdminExporter.new('')
    sheet = ExcelBook.new('test').create_sheet(project_admin_exporter.name)
    project_admin_exporter.export(sheet)

    assert_equal 3, sheet.headings.count
    assert_equal ['Project name', 'Admin name', 'Admin email address'], sheet.headings
    assert_equal [project.name, first_admin.name, first_admin.email], sheet.row(sheet.number_of_rows-2)
    assert_equal [project.name, second_admin.name, second_admin.email], sheet.row(sheet.number_of_rows-1)
    end
  end
end
