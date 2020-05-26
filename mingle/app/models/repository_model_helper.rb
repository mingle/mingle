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

module RepositoryModelHelper
  def self.included(base)
    base.extend ClassMethods
  end
  
  module ClassMethods
    def create_or_update(project_id, id, options={})
      options = options.symbolize_keys
      options.delete(:project_id)
      options.delete(:id)

      if id.present?
        update_config(project_id, id, options)
      else
        create_new(project_id, options)
      end
    end
    
    def create_new(project_id, options)
      existing = find_project(project_id).repository_configuration
      if !existing
        options.merge! :project_id => project_id
        self.create(options)
      else
        add_error("Could not create the new repository configuration because a repository configuration already exists.", options)
      end
    end
    
    def update_config(project_id, id, options)
      unless config = self.find_by_project_id_and_id(project_id, id)
        return add_error("Could not update because the repository configuration does not exist.", options)
      end
      
      if config.username != options[:username].to_s.strip
        config.password = nil
      end

      if config.repository_location_changed?(options.dup)
        recreate_config(config, project_id, options)
      else
        config.update_attributes(options)
        config
      end
    end
    
    def recreate_config(config, project_id, options)
      config.attributes = config.attributes.merge(options)
      if config.valid?
        config.mark_for_deletion
        create_new(project_id, config.clone_repository_options.merge(options))
      else
        config
      end
    end
    
    def find_project(project_id)
      Project.find(project_id)
    end
    
    private
    def add_error(message, options)
      errored_config = self.new(options)
      errored_config.errors.add_to_base(message)
      errored_config
    end
  end
  
  #overwrite this method if behaviour is different
  def mark_for_deletion
    update_attribute :marked_for_deletion, true
  end
  
end
