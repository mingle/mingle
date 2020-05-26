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

class P4CmdConfiguration
  PERFORCE_SETTINGS = ::Configuration::Default::new_section('p4_cmd')
  CONFIG_YML = File.join(MINGLE_CONFIG_DIR, 'perforce_config.yml')
  
  def self.configured_p4_cmd
    $p4_cmd ||= new.load
    path = if($p4_cmd.match(/^~/))
      File.expand_path($p4_cmd)
    else 
      $p4_cmd
    end
    
    path.inspect.gsub(/^\"/, '').gsub(/\"$/, '')
  end
  
  def self.destroy
    File.delete(CONFIG_YML) if exist?
    $p4_cmd = nil
  end
  
  def self.exist?
    File.exists?(CONFIG_YML)
  end
  
  def create(params, file_name=CONFIG_YML)
    ActiveRecord::Base.logger.debug("Creating Perforce plugin Configuration into file #{file_name}")
    ActiveRecord::Base.logger.debug("Perforce settings: #{params.inspect}")
    FileUtils.mkpath(File.dirname(file_name))
    File.open(file_name, "w+") do |io|
      PERFORCE_SETTINGS.merge_params(params).write_as_yaml_on(io)
    end
    load(file_name)
  end
  
  def load(file_name=CONFIG_YML)
    if File.exists?(file_name)
      settings = YAML::load(IO.read(file_name)) rescue nil
      ActiveRecord::Base.logger.debug("Perforce plugin Configuration loaded from file #{file_name}")
      
      if settings && !settings["p4_cmd"].blank?
        ActiveRecord::Base.logger.info{"Perforce plugin Configuration p4_cmd loaded: #{settings["p4_cmd"]}"}
        return settings["p4_cmd"]
      end
    else
      ActiveRecord::Base.logger.debug("Perforce plugin Configuration could not load. File #{file_name} does not exist. This could be OK during initial application install.")
    end
    
    create('p4_cmd' => 'p4')
  end
end
