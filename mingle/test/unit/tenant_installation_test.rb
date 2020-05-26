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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class TenantInstallationTest < ActiveSupport::TestCase

  def test_generate_login_from_email
    assert_equal 'a', generate_from_email('a@a.com')
    assert_equal 'a', generate_from_email('A@a.com')
    assert_equal 'a___b', generate_from_email('a$%^b@a.com')
    assert_equal 'a' * 40, generate_from_email("#{'a' * 40}b@a.com")
    assert_equal 'abcd', generate_from_email('abcd')
  end

  def generate_from_email(email)
    TenantInstallation.generate_from_email(email)
  end

  def test_should_purge_s3_files_for_a_tenant
      s3_mock = mock("S3")
      s3_mock.expects(:clear).with('test')
      TenantInstallation.purge_s3_data_for_tenant("test", s3_mock)
  end

  def test_error_handling_for_migration
    assert_raise TenantInstallation::MigrationError do
      TenantInstallation.with_migration_error_logging('tenant-name') do
        raise 'world'
      end
    end
  end
end
