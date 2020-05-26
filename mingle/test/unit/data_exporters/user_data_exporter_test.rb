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

class UserDataExporterTest < ActiveSupport::TestCase

  def test_should_export_to_sheet_and_name
    assert UserDataExporter.new('').exports_to_sheet?
    assert_equal 'Users', UserDataExporter.new('').name
  end

  def test_sheet_should_contain_user_data
    user_data_exporter = UserDataExporter.new('')
    sheet = ExcelBook.new('test').create_sheet(user_data_exporter.name)
    user_data_exporter.export(sheet)

    assert_equal 6, sheet.headings.count
    assert_equal User.all.count + 1, sheet.number_of_rows
    assert_equal ['Name', 'Sign in name', 'Email', 'Role', 'Last Active On', 'Deactivated'], sheet.headings
    User.order_by_name.each_with_index do |user, i|
      assert_equal [user.name, user.login, user.email, user.role, format_date(user.login_access.last_login_at), (!user.activated? ? 'Yes' : 'No')], sheet.row(i + 1)
    end
  end

  private
  def format_date(date)
    date ? date.strftime('%d-%b-%Y') : ''
  end
end
