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

class Install::OracleDatabaseConfig < Install::DatabaseConfig
  
  column :username, :string, 'mingle_user'
  column :port, :integer, '1521'
  
  validates_presence_of :password
  
  def to_url
    port = if self.port && !self.port.zero? then ":#{self.port}" else ":1521" end
    "jdbc:oracle:thin:@#{host}#{port}:#{database}"
  end
  
  def driver_class
    'oracle.jdbc.OracleDriver'
  end
  
  def self.database_type
    'Oracle'
  end
  
  def self.database_type_label
    'Oracle (Mingle Plus only)'
  end
  
  def labels
    Install::OracleDatabaseLabels.new
  end
  
  def requires_password?
    true
  end
  
end
