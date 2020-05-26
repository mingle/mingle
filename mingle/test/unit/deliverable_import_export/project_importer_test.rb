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
require File.expand_path(File.dirname(__FILE__) + '/../../messaging/messaging_test_helper')

class ProjectImporterTest < ActiveSupport::TestCase

  include MessagingTestHelper

  def setup
    login_as_admin
  end

  def test_column_mappings
    importer = DeliverableImportExport::ProjectImporter.new
    table = TableStub.new
    record = {}

    (0..5).to_a.each do |i|
      table << ColumnStub.new("column_#{i}")
      record["column_#{i}"] = i
    end

    assert_equal "column_2", importer.column_mappings_for(table, record.keys)["column_2"]
  end

  def test_raises_exception_when_user_emails_not_unique
    users_table = [
      { "email" => "foo@email.com" },
      { "email" => "FOO@email.com" },
      { "email" => 'bar@email.com' },
      { "email" => nil },
      { "email" => '' }
    ]
    begin
      DeliverableImportExport::ProjectImporter.new.validate_unique_user_emails(users_table)
      fail "should have raised and error for duplicate emails"
    rescue => e
      assert_match /The following emails are shared among multiple users\: foo\@email\.com/, e.message
    end
  end

  def test_raises_exception_when_ruby_objects_serialized_into_yaml
    project_importer = UnitTestDataLoader.create_project_importer!(User.current, "#{Rails.root}/test/data/ruby_injection_project.mingle")
    project_importer.process!
    assert_equal('completed failed', project_importer.status)
    assert_equal('Upgrade failed, please contact Mingle support', project_importer.progress.message[:errors].first)
  end

end

class TableStub < Array
  def name
    "test-table"
  end

  def columns
    self
  end

end

class ColumnStub
  attr_reader :name
  def initialize(name)
    @name = name
  end
  def type_cast(*args); end
end
