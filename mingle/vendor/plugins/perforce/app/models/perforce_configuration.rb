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


class PerforceConfiguration < ActiveRecord::Base
  
  INVALID_WILDCARDS = ['*', '%', '@']
  ELLIPSES = '...'
  
  v2_serializes_as :id, :marked_for_deletion, :project, :repository_path, :username, :host, :port
  
  def self.display_name
    'Perforce'
  end

  def self.client_installed?
    P4.available?
  end
  
  def self.client_unavailable_message
    "The Perforce client executable (#{P4CmdConfiguration.configured_p4_cmd}) was not found. Please ensure that this is installed, that the complete path has been updated in perforce_config.yml and try again."
  end
    
  def vocabulary
    {
      'revision' => 'changelist',
      'committed' => 'submitted',
      'repository' => 'depot',
      'head' => 'HEAD'
     }
  end
  
  include PasswordEncryption
  include RepositoryModelHelper
  before_save :encrypt_password

  strip_on_write

  belongs_to :project
  validates_presence_of :username, :repository_path, :host, :port

  def source_browsing_ready?
    true
  end
  
  def view_partials
    {:node_table_header => 'perforce_configurations/node_table_header', 
     :node_table_row => 'perforce_configurations/node_table_row' }
  end
  
  def repository_path=(path)
    write_attribute(:repository_path, path.gsub(/^[\/\\]+/, P4::ROOT_PATH))
  end

  def repository_location_changed?(attributes)
    self.repository_path != attributes[:repository_path] || self.port != attributes[:port] || self.host != attributes[:host]
  end
  
  def clone_repository_options
    {:repository_path => self.repository_path, :username => self.username, :password => self.password, :port => self.port, :host => self.host}
  end

  def repository
    if !defined?(@repository)
      begin
        version_control_users = project.version_control_users
        @repository = PerforceRepository.new(version_control_users,
                username,
                password,
                repository_path,
                host, port)
      rescue Exception => e
        log_error(e, "Unable to connect to perforce repository for project #{project.identifier}")
        @repository = nil
      end
    end
    @repository
  end
  
  def validate
    if repository_path
      invalid_characters = INVALID_WILDCARDS.select { |invalid_char| repository_path.include?(invalid_char) }
      errors.add(:repository_path, "cannot contain #{invalid_characters.to_sentence(:words_connector => ' or ', :two_words_connector => ' or ')}") unless invalid_characters.empty?
      errors.add_to_base("Repository path depot paths must each end in a letter, number, slash, or '...'") unless repository_path.split(' ').all? { |path| path =~ /(\.\.\.|[A-z0-9]|\/)$/ }
      errors.add_to_base("Repository path '#{ELLIPSES}' can only appear at the end of depot paths") if repository_path.split(' ').any? { |path| contains_embedded_ellipses(path) }
      errors.add(:repository_path, "depot paths cannot be only '//'") if repository_path.split(' ').any? { |path| path == '//' }
      errors.add(:repository_path, "'//' can only appear at the beginning of depot paths") if repository_path.split(' ').any? { |path| contains_embedded_double_slashes(path) }
    end
  end

  private
  def contains_embedded_ellipses(depot_path)
    (ellipses_index = depot_path.index(ELLIPSES)) && (ellipses_index > 0) && (ellipses_index < (depot_path.size - ELLIPSES.size))
  end
  
  def contains_embedded_double_slashes(depot_path)
    depot_path.index('//', 1)
  end
end

