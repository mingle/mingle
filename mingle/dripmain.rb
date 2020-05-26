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

require File.expand_path(File.join(File.dirname(__FILE__), '/config/boot'))

[:check_ruby_version,
 :install_gem_spec_stubs,
 :set_load_path,
 :add_gem_load_paths,
 :require_frameworks,
 :set_autoload_paths,
 :add_plugin_load_paths,
 :preload_frameworks,
 :add_support_load_paths,
 :check_for_unbuilt_gems
].each do |command|
  Rails::Initializer.run(command)
end

# pre initialize a logger to make gem need logging while loading happy
ActionController::Base.logger = Logger.new($stdout)

[
 :load_gems,
 :check_gem_dependencies
].each do |command|
  Rails::Initializer.run(command)
end
