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

module Engines
  module Assets    
    class << self      
      @@readme = %{Files in this directory are automatically generated from your plugins.
They are copied from the 'assets' directories of each plugin into this directory
each time Rails starts (script/server, script/console... and so on).
Any edits you make will NOT persist across the next server restart; instead you
should edit the files within the <plugin_name>/assets/ directory itself.}     
       
      # Ensure that the plugin asset subdirectory of RAILS_ROOT/public exists, and
      # that we've added a little warning message to instruct developers not to mess with
      # the files inside, since they're automatically generated.
      def initialize_base_public_directory
        dir = Engines.public_directory
        unless File.exist?(dir)
          FileUtils.mkdir_p(dir)
        end
        readme = File.join(dir, "README")        
        File.open(readme, 'w') { |f| f.puts @@readme } unless File.exist?(readme)
      end
    
      # Replicates the subdirectories under the plugins's +assets+ (or +public+) 
      # directory into the corresponding public directory. See also 
      # Plugin#public_directory for more.
      def mirror_files_for(plugin)
        return if plugin.public_directory.nil?
        begin 
          Engines.mirror_files_from(plugin.public_directory, File.join(Engines.public_directory, plugin.name))      
        rescue Exception => e
          Engines.logger.warn "WARNING: Couldn't create the public file structure for plugin '#{plugin.name}'; Error follows:"
          Engines.logger.warn e
        end
      end
    end 
  end
end
