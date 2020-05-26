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

class SecretKeyBaseHelper
  SECRETS_YML = 'secrets.yml'

  def initialize(config_dir)
    @config_dir = config_dir
    @secrets_yml = File.join(@config_dir, SECRETS_YML)
  end

  def secret_key_base
    create_new_secret_config unless File.exist?(@secrets_yml)
    load_secret_config(@secrets_yml)[:secret_key_base]
  end

  private

  SECRET_KEY_BASE_LENGTH = 128

  def create_new_secret_config
    config  = { secret_key_base:SecureRandom.hex(SECRET_KEY_BASE_LENGTH)}
    write_new_db_config(config)
  end

  def write_new_db_config(secrets_config)
    File.write(@secrets_yml, secrets_config.to_yaml)
  end

  def load_secret_config(secrets_file)
    YAML.load(File.read(secrets_file)).to_hash
  end
end
