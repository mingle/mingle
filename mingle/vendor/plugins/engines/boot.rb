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

begin
  require 'rails/version'
  unless Rails::VERSION::MAJOR >= 2 && Rails::VERSION::MINOR >= 3 && Rails::VERSION::TINY >= 2
    raise "This version of the engines plugin requires Rails 2.3.2 or later!"
  end
end

require File.join(File.dirname(__FILE__), 'lib/engines')

# initialize Rails::Configuration with our own default values to spare users 
# some hassle with the installation and keep the environment cleaner

{ :default_plugin_locators => [Engines::Plugin::FileSystemLocator],
  :default_plugin_loader => Engines::Plugin::Loader,
  :default_plugins => [:engines, :all] }.each do |name, default|    
  Rails::Configuration.send(:define_method, name) { default }
end
