#!/usr/bin/env ruby
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


require File.expand_path(File.join(File.dirname(__FILE__), '../config/environment'))

conn = ActiveRecord::Base.connection

tables = conn.execute("SELECT tablename FROM pg_tables where tablename not like 'pg_%' and schemaname = current_schema()")
tables.each do |table|
  begin
    seq = conn.execute("select setval(\'#{table}_id_seq\', max(id)) from #{table}")
    puts "#{table} id sequence reset to #{seq[0]}"

  # this is a lame way of handling the sequence not existing !!
  rescue Exception => error
    puts "error updating sequence for #{table}.  likely the sequence doesn't even exist."
  end
end
