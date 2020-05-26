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

class SubversionConfiguration < ActiveRecord::Base
  include PasswordEncryption
  include RepositoryModelHelper

  belongs_to :project
  before_save :encrypt_password

  validates_presence_of :repository_path
  
  def self.display_name
    'Subversion'
  end
  
  def vocabulary
    {
      'revision' => 'revision',
      'committed' => 'committed',
      'repository' => 'repository',
      'head' => 'HEAD'
     }
  end
  
  strip_on_write

  v1_serializes_as :complete => [:id, :marked_for_deletion, :project_id, :repository_path, :username],
                   :compact => []

  v2_serializes_as :complete => [:id, :marked_for_deletion, :project, :repository_path, :username],
                   :compact => []

  compact_at_level 0
  
  self.resource_link_route_options = proc { |sc| { :project_id => Project.id_to_identifier(sc.project_id) } }
  self.routing_name = "subversion_configurations"
  
    
  def repository
    Repository.new(repository_path, project.version_control_users, username, decrypted_password).tap do |repo|
      project.on_deactivate { repo.close }
    end
  end

  def view_partials
    {:node_table_header => 'subversion_configurations/node_table_header', 
     :node_table_row => 'subversion_configurations/node_table_row' }
  end
  
  def repository_location_changed?(attributes)
    self.repository_path != attributes[:repository_path]
  end
  
  def clone_repository_options
    {:repository_path => self.repository_path, :username => self.username, :password => self.password}
  end
  
  def source_browsing_ready?
    true
  end
end
