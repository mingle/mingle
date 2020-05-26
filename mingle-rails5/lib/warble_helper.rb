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

  def recreate_web_xml
    webxml = OpenStruct.new(:context_params => {
        :'rails.env' => 'production',
        :'rails.root' => '/WEB-INF',
        :'public.root' =>'/'
    })
    webxml_filepath = 'config/web.xml'

    puts "Recreating #{webxml_filepath}"
    File.delete(webxml_filepath) if File.exist?(webxml_filepath)
    erb = ERB.new(File.read('config/web.xml.erb'))
    File.open(webxml_filepath, 'w') do |f|
      f.write(erb.result(binding))
    end
  end

  def copy_configs
    origin = File.join(config_path, File.basename(log4j_properties_filepath))
    if File.exist?(origin)
      FileUtils.mv origin, backup_file(origin)
    end
    FileUtils.cp log4j_properties_filepath, origin
  end

  def restore_configs
    origin = File.join(config_path, File.basename(log4j_properties_filepath))
    if File.exist?(backup_file(origin))
      FileUtils.mv backup_file(origin), origin
    else
      FileUtils.rm origin
    end
  end

  def config_path
    @config_path ||= File.expand_path(File.join(File.dirname(__FILE__), "..", "config"))
  end

  def backup_file(f)
    "#{f}.bak"
  end

  def log4j_properties_filepath
    'config/war/log4j.properties'
  end
end
