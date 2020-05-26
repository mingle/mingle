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

class ConfigFile
  def initialize(filename)
    @filename = filename
  end

  def path
    if File.exists?(File.join(MINGLE_CONFIG_DIR, filename))
      File.join(MINGLE_CONFIG_DIR, filename)
    else
      File.join(Rails.root, 'config', filename)
    end
  end

  def yaml_content
    YAML.load(File.read(path))
  end

  private
  def filename
    @filename
  end
end
