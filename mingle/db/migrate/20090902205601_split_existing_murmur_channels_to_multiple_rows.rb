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

class M20090902205601MurmurChannel < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}murmur_channels"
  self.inheritance_column = 'm_foo' #disable single table inheretance
end

class M20090902205601Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  has_many :murmur_channels, :class_name => "M20090902205601MurmurChannel", :foreign_key => "project_id"
end

class SplitExistingMurmurChannelsToMultipleRows < ActiveRecord::Migration
  def self.up
    M20090902205601Project.find(:all).each do |project|
      next if project.murmur_channels.empty?
      only_channel = project.murmur_channels.first
      next if only_channel.disabled?
      next unless only_channel.jabber_chat_room_enabled?
      
      project.murmur_channels.create!(:type => 'JabberChatRoom', 
                                      :disabled => false,
                                      :jabber_chat_room_status => only_channel.jabber_chat_room_status, 
                                      :jabber_chat_room_enabled => true, 
                                      :jabber_chat_room_id => only_channel.jabber_chat_room_id)
    end
  end

  def self.down
    raise 'Not supported.'
  end
  
end
