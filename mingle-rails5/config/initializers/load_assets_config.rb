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

assets_config_file_path = File.join(Rails.root, 'config', 'shared_assets.yml')
if File.exist?(assets_config_file_path)
  assets_config = YAML.load_file(assets_config_file_path).symbolize_keys
  Rails.application.config.assets_config = MingleAssetsConfig.new(assets_config)
else
  Rails.logger.warn "Could not find asset config file at path: #{assets_config_file_path}. Using empty config"
  Rails.application.config.assets_config = MingleAssetsConfig.new({})
end
