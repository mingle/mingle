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

class ToughenUsersCredentials < ActiveRecord::Migration
  def self.up
    add_column :users, :salt, :string
    User.reset_column_information
    M20100421214257User.all.each do |user|
      user.update_attribute :salt, Salt.create
      user.update_attribute :password, Digest::SHA256.hexdigest(user.salt + user.password) if user.password.present?
    end
  end

  def self.down
    remove_column :users, :salt
  end
end

class M20100421214257User < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}users"
end

class Salt
  def self.create
    md5 = Digest::MD5::new
    now = Time::now
    md5.update(now.to_s)
    md5.update(String(now.usec))
    md5.update(String(rand(0)))
    md5.update(String($$))
    md5.update('foobar')
    md5.hexdigest
  end
end
