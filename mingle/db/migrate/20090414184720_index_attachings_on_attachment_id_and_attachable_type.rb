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

class IndexAttachingsOnAttachmentIdAndAttachableType < ActiveRecord::Migration
  def self.up
    add_index "attachings", ["attachment_id"], :name => "#{ActiveRecord::Base.table_name_prefix}index_att_on_a_id"
    add_index "attachings", ["attachable_id"], :name => "#{ActiveRecord::Base.table_name_prefix}index_att_on_able_id"
    add_index "attachings", ["attachable_type"], :name => "#{ActiveRecord::Base.table_name_prefix}index_att_on_able_type"
  end

  def self.down
    remove_index "attachings", :name => "#{ActiveRecord::Base.table_name_prefix}index_att_on_a_id"
    remove_index "attachings", :name => "#{ActiveRecord::Base.table_name_prefix}index_att_on_able_id"
    remove_index "attachings", :name => "#{ActiveRecord::Base.table_name_prefix}index_att_on_able_type"
  end
end
