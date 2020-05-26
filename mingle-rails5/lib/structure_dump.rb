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

class StructureDump
  attr_reader :name
  def initialize(name)
    @name = name
  end

  def dump
    config = ActiveRecord::Tasks::DatabaseTasks.current_config
    ActiveRecord::Tasks::DatabaseTasks.structure_dump(config, dump_file_path)
    if ActiveRecord::Base.connection.supports_migrations?
      File.open(dump_file_path, "a") do |dump_file|
        dump_file << ActiveRecord::Base.connection.dump_schema_information
        dump_file << "\n\n-- vendor #{ActiveRecord::Base.connection.database_vendor};\n\n"
        dump_file << "\n\n-- version #{ActiveRecord::Migrator.get_all_versions.max}"
      end
    end
  end

  def database_vendor
    File.read(dump_file_path) =~ /^-- vendor (\w+)+/m
    $1
  end

  def version
    File.read(dump_file_path) =~ /^-- version (\d+)+/m
    $1.to_i
  end

  def dump_file_path
    "db/#{name}_structure.sql"
  end
end
