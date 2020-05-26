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

class CreateMurmursTable < ActiveRecord::Migration
  def self.up
    create_table :murmurs do |t|
      t.column "project_id",          :integer,  :null => false
      t.column "user_id",             :integer,  :null => true
      t.column "packet_id",           :string,   :null => false
      t.column "jabber_login_id",     :string,   :null => false
      t.column "created_at",          :datetime, :null => false
      t.column "murmur",              :string,   :null => false, :limit => safe_limit(1000)
    end
  end

  def self.down
    drop_table :murmurs
  end
end
