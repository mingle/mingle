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

require 'active_record'
require 'tfsscm_repository'
require 'tfsscm'

class TfsscmConfiguration < ActiveRecord::Base
  include RepositoryModelHelper
  include PasswordEncryption
  strip_on_write
  belongs_to :project
  before_save :encrypt_password
  validates_presence_of :server_url, :collection, :tfs_project, :domain, :username, :password

  def self.display_name
    "Team Foundation Server"
  end

  def vocabulary
    {
      'revision' => 'changeset',
      'committed' => 'checked in',
      'repository' => 'repository',
      'head' => 'latest',
    }
  end

  def repository
    TfsscmRepository.new(tfs)
  end

  def clone_repository_options
    {
      :server_url => server_url,
      :collection => collection,
      :tfs_project => tfs_project,
      :domain => domain,
      :username => username,
      :password => password,
    }
  end

  def repository_location_changed?(new_props)
    old_props = clone_repository_options
    [:server_url, :collection, :tfs_project].any? { |p| new_props[p] != old_props[p] }
  end

  def source_browsing_ready?
    false
  end
  
  def source_browsable?
    false
  end

  private
  def tfs
    @tfs ||= Tfsscm::TfsAdapter.new(server_url, collection, tfs_project, domain, username, decrypted_password)
  end
end
