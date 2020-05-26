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

require 'set'

module MinglePlugins

  class Source

    def self.register(plugin_type)
      (available_plugins << plugin_type).uniq!
    end

    def self.available_plugins
      ($mingle_plugins['source'] ||= [])
    end

    def self.available_plugins=(available)
      available.each do |plugin|
        self.register(plugin)
      end
    end

    def self.available_plugins_as_options
      options = []
      self.available_plugins.each do |plugin_type|
        display_name = plugin_type.display_name
        options << [display_name, plugin_type.to_s]
      end
      options
    end

    def self.project_ids_with_configurations
      project_ids = []
      available_plugins.each do |plugin_type|
        project_ids.concat(plugin_type.find(:all,
          :conditions => ["(marked_for_deletion = ? OR marked_for_deletion IS NULL)", false], :select => 'project_id').map(&:project_id))
      end
      project_ids
    end

    def self.find_for(project)
      # table_exists? is expensive when there are lots of schemas and
# tables
      # hence do nothing when the scm feature is turned off on SaaS
      return unless FEATURES.active?("scm")

      plugins = []
      available_plugins.each do |plugin_type|
        next unless ActiveRecord::Base.connection.table_exists?(plugin_type.table_name)
        found_for_type = plugin_type.find(:all,
          :conditions => ["project_id = ? AND (marked_for_deletion = ? OR marked_for_deletion IS NULL)", project.id, false])
        plugins.concat(found_for_type)
      end

      if plugins.size > 1
        ActiveRecord::Base.logger.error(%{
          More than 1 source plugin found for project #{project.identifier}. This is not expected.
          All configurations will be marked for deletion. Please wait a few minutes and reconfigure
          your project's source repository settings.
        })
        plugins.each do |plugin|
          plugin.update_attribute(:marked_for_deletion, true)
        end
        plugins = []
      end

      plugins.first
    end

    def self.delete_all_for(project)
      available_plugins.each do |plugin_type|
        plugin_type.connection.execute("DELETE FROM #{plugin_type.table_name} WHERE project_id = #{project.id}")
      end
    end

    def self.find_all_marked_for_deletion
      plugins = []
      available_plugins.each do |plugin_type|
        plugins.concat(plugin_type.find(:all, :conditions => ['marked_for_deletion = ?', true]))
      end
      plugins
    end

  end
end
