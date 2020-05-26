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

module WarbleHelper
  module_function

  def config(&block)
    regenerate_webxml do
      with_war_configs(&block)
    end
  end

  def with_war_configs(&block)
    copy_configs
    yield
  ensure
    restore_configs
  end

  def config_path
    @config_path ||= File.expand_path(File.join(File.dirname(__FILE__), "..", "config"))
  end

  def war_configs_path
    @war_configs_path ||= File.expand_path(File.join(config_path, "war"))
  end

  def regenerate_webxml(&block)
    FileUtils.rm_rf File.join(config_path, "web.xml")
    yield
  ensure
    generate_webxml
  end

  def copy_configs(file = nil)
    war_configs(file).each do |f|
      origin = File.join(config_path, File.basename(f))
      if File.exist?(origin)
        FileUtils.mv origin, backup_file(origin)
      end
      FileUtils.cp f, origin
    end
  end

  def restore_configs(file = nil)
    war_configs(file).each do |f|
      origin = File.join(config_path, File.basename(f))
      if File.exist?(backup_file(origin))
        FileUtils.mv backup_file(origin), origin
      else
        FileUtils.rm origin
      end
    end
  end

  def war_configs(file_pattern)
    file_pattern = '*.*' if file_pattern.nil?
    Dir.glob(File.join(war_configs_path, file_pattern))
  end

  def backup_file(f)
    "#{f}.bak"
  end
end
