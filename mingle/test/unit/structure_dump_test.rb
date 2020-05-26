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

require File.expand_path("../unit_test_helper", File.dirname(__FILE__))
require "structure_dump"

class StructureDumpTest < ActiveSupport::TestCase
  def test_oracle_dump_should_include_latest_migration
    msg = "please run db:refresh_oracle_structure_dump on Oracle 11g to fix this failure"
    sd = StructureDump.new("oracle")
    assert_equal ActiveRecord::Migrator.get_all_versions.max, sd.version, msg
    assert_equal "oracle", sd.database_vendor, msg
  end

  def test_postgres_dump_should_include_latest_migration
    msg = "please run db:refresh_pg_structure_dump on PostgreSQL to fix this failure"
    sd = StructureDump.new("postgresql")
    assert_equal ActiveRecord::Migrator.get_all_versions.max, sd.version, msg
    assert_equal "postgresql", sd.database_vendor, msg
  end
end
