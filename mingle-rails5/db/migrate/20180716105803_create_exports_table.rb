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

class CreateExportsTable < ActiveRecord::Migration[5.0]
  class << self
    def up
      create_table :exports do |table|
        table.string :status
        table.references :user
        table.integer :total
        table.integer :completed
        table.string :export_file
        table.timestamps
      end
    end

    def down
      drop_table :exports
    end
  end
end
