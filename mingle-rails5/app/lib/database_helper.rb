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

class DatabaseHelper
  DATABASE_YML = 'database.yml'
  NEW_RAILS_DATABASE_YML = 'database.yml.new_rails'

  def initialize(config_dir = MINGLE_CONFIG_DIR)
    @config_dir = config_dir
    @database_yml = File.join(@config_dir, DATABASE_YML)
    @new_rails_database_yml = File.join(@config_dir, NEW_RAILS_DATABASE_YML)
  end

  def db_config_file
    return File.join(Rails.root, 'config', DATABASE_YML) unless File.exist?(@database_yml)
    return @database_yml if valid?(@database_yml)
    create_new_db_config
  end

  def setup
    return false unless File.exist?(@database_yml)
    config_file = @database_yml
    config_file = create_new_db_config unless valid?(@database_yml)
    ActiveRecord::Base.establish_connection env_specific_config(load_db_config(config_file))
    ActiveRecord::Base.connection.active?
  end

  private

  def create_new_db_config
    db_config = load_db_config(@database_yml)
    postgresql?(env_specific_config(db_config)) ? create_pg_config(db_config) : create_oracle_config(db_config)
    @new_rails_database_yml
  end

  def create_pg_config(db_config)
    specific_config = env_specific_config(db_config)
    specific_config['adapter'] = 'postgresql'
    specific_config.delete('driver')
    write_new_db_config(db_config)
  end

  def create_oracle_config(db_config)
    specific_config = env_specific_config(db_config)
    specific_config['adapter'] = 'oracle_enhanced'
    specific_config.delete('driver')
    write_new_db_config(db_config)
  end

  def write_new_db_config(db_config)
    File.write(@new_rails_database_yml, db_config.to_yaml)
  end

  def valid?(db_config_file)
    db_config = load_db_config(db_config_file)
    specific_config = env_specific_config(db_config)
    postgresql?(specific_config) ? valid_pg_config?(specific_config) : valid_oracle_config?(specific_config)
  end

  def env_specific_config(db_config)
    db_config[Rails.env]
  end

  def load_db_config(db_config_file)
    YAML.load(ERB.new(File.read(db_config_file)).result).to_hash
  end

  def valid_pg_config?(db_config)
    valid_adapter?(db_config['adapter'], :postgresql)
  end

  def valid_oracle_config?(db_config)
    valid_adapter?(db_config['adapter'], :oracle)
  end

  def valid_adapter?(adapter, db_type)
    valid_adapter = (db_type === :postgresql) ? 'postgresql' : 'oracle_enhanced'
    adapter === valid_adapter
  end

  def postgresql?(db_config)
    !db_config['url'].match("postgresql").nil?
  end

end
