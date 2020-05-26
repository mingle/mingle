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

class Install::DatabaseConfig < ActiveRecord::Base
  def self.columns() read_inheritable_attribute('columns') || []; end
  def self.column(name, sql_type = nil, default = nil, null = true)
    write_inheritable_array('columns', [ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type.to_s, null)])
  end

  def self.verify_pool_size!(ar_db_config, full_filename = MINGLE_DATABASE_YML)
    if ar_db_config['pool'].blank? && $connection_pool_size
      ar_db_config['pool'] = $connection_pool_size

      FileUtils.mkpath(File.dirname(full_filename))
      File.open(full_filename, "w+") { |io| io.write({Rails.env.to_s => ar_db_config}.to_yaml) }
    end
  end

  attr_accessor :connection
  
  column :host, :string, 'localhost'
  column :database, :string, 'mingle'
  column :username, :string, 'root'
  column :password, :string
  
  validates_presence_of :host, :database, :username
  
  CONFIGS = [
    Install::PostgresDatabaseConfig,
    Install::OracleDatabaseConfig
  ]

  def self.find_database_type(database_type)
    CONFIGS.find{|c| c.database_type == database_type} || Install::PostgresDatabaseConfig
  end
  
  def set_rails_configuration
    ActiveRecord::Base.configurations ||= {}
    ActiveRecord::Base.configurations[Rails.env.to_s] = to_database_yml
  end
  
  def write_database_yml(full_filename = MINGLE_DATABASE_YML)
    FileUtils.mkpath(File.dirname(full_filename))
    File.open(full_filename, "w+") { |io| io.write(ActiveRecord::Base.configurations.to_yaml) }
  end
  
  def establish_connection
    ActiveRecord::Base.establish_connection
    connection.verify_charset!
  end
  
  def database_type
    self.class.database_type
  end
  
  def labels
    Install::DatabaseLabels.new
  end
  
  def requires_password?
    false
  end

  protected
  
  def to_database_yml
    ({}).tap do |yml|
      yml['adapter']  = 'jdbc'
      yml['driver']   = driver_class
      yml['username'] = self.username
      yml['password'] = self.password if self.password
      yml['url']      = to_url
      yml['pool']     = $connection_pool_size || 0
    end
  end
  
  def connection
    @connection || ActiveRecord::Base.connection
  end
end

