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

class CreateSequenceForExportsTable < ActiveRecord::Migration[5.0]
  def self.up
    return unless ActiveRecord::Base.table_name_prefix.blank? # Skip for imports
    seq_name =  connection.config[:driver] == "org.postgresql.Driver" ? 'exports_id_seq' : 'EXPORTS_SEQ'
    create_sequence(seq_name, 1, :strict_counter => true) unless sequence_exists?(seq_name)
  end

  def self.down
    #Not required
  end
end
