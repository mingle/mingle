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

def prepare_assets_config
    config = {}
    assets_for_rails_5 = MingleSprocketsConfig.manifest.assets.select {|x,y| x.match(/(sprockets|print)\w*.*/)}
    assets_for_rails_5.each do |actual_file,versioned_file|
        actual_file = actual_file.gsub('.', '_')
        config[actual_file] = versioned_file
    end
    config
end

def write_to_yaml_file(config)
    FileUtils.touch 'shared_assets.yml'
    File.open('shared_assets.yml','w') do |file|
        file.write(config.to_yaml)
    end
end

desc 'show all the pending tests'
task :shared_assets => [:assets] do
    config = prepare_assets_config
    write_to_yaml_file config
end
