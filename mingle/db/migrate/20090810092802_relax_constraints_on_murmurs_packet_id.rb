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

class RelaxConstraintsOnMurmursPacketId < ActiveRecord::Migration
  def self.up
    drop_not_null_constraint "murmurs", "packet_id"
    drop_not_null_constraint "murmurs", "jabber_user_name"
  end

  def self.down
    execute "DELETE FROM #{safe_table_name("murmurs")}"
    create_not_null_constraint "murmurs", "jabber_user_name"
    create_not_null_constraint "murmurs", "packet_id"
  end
end
