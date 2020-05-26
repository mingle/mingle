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

# The PluginList class is an array, enhanced to allow access to loaded plugins
# by name, and iteration over loaded plugins in order of priority. This array is used
# by Engines::RailsExtensions::RailsInitializer to create the Engines.plugins array.
#
# Each loaded plugin has a corresponding Plugin instance within this array, and 
# the order the plugins were loaded is reflected in the entries in this array.
#
# For more information, see the Rails module.
module Engines
  class Plugin
    class List < Array
      # Finds plugins with the set with the given name (accepts Strings or Symbols), or
      # index. So, Engines.plugins[0] returns the first-loaded Plugin, and Engines.plugins[:engines]
      # returns the Plugin instance for the engines plugin itself.
      def [](name_or_index)
        if name_or_index.is_a?(Fixnum)
          super
        else
          self.find { |plugin| plugin.name.to_s == name_or_index.to_s }
        end
      end
  
      # Go through each plugin, highest priority first (last loaded first). Effectively,
      # this is like <tt>Engines.plugins.reverse</tt>
      def by_precedence
        reverse
      end
    end
  end
end
