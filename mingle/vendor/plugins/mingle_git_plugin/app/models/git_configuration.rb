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

# Copyright (c) 2010 ThoughtWorks Inc. (http://thoughtworks.com)
# Licenced under the Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0.txt)

require 'uri'
require 'cgi'
class GitConfiguration < ActiveRecord::Base

  include RepositoryModelHelper

  strip_on_write


  belongs_to :project


  after_create :remove_cache_dirs
  after_destroy :remove_cache_dirs
  before_save :encrypt_password

  validates_presence_of :repository_path

  def self.display_name
    "Git"
  end

  def vocabulary
    {
      'revision' => 'changeset',
      'committed' => 'author',
      'repository' => 'repository',
      'head' => 'master',
      'short_identifier_length' => 12
    }
  end

  def view_partials
    {:node_table_header => 'git_source/node_table_header',
     :node_table_row => 'git_source/node_table_row' }
  end

  def source_browsing_ready?
    initialized?
  end

  def validate
    super

    begin
      uri = URI.parse(repository_path)
    rescue
      errors.add_to_base(%{
        The repository path appears to be of invalid URI format.
        Please check your repository path.
      })
    end

    if uri && !uri.password.blank?
      errors.add_to_base(%{
        Do not store repository password as part of the URL.
        Please use the supplied form field.
      })
    end
  end

  # use mingle project's encryption capability to protect password in DB
  def encrypt_password
    return unless password_changed?
    pwd_attr = @attributes['password']
    if !pwd_attr.blank?
      write_attribute(:password, project.encrypt(pwd_attr))
    else
      write_attribute(:password, pwd_attr)
    end
  end

  # *returns*: decrypted password
  def password
    pwd = super
    return pwd if pwd.blank?
    project.decrypt(pwd)
  end

  def repository
    scm_client = GitClient.new(remote_master_info, cache_dir)

    source_browser = GitSourceBrowser.new(scm_client)

    repository = GitRepository.new(scm_client, source_browser)

    GitRepositoryClone.new(repository, cache_dir, project, retry_previously_failed_connection)
  end

  def repository_location_changed?(configuration_attributes)
    self.repository_path != configuration_attributes[:repository_path]
  end

  def clone_repository_options
    {:repository_path => self.repository_path, :username => self.username, :password => self.password}
  end

  def remote_master_info
    uri = URI.parse(repository_path)

    if uri.scheme.blank?
      GitRemoteMasterInfo.new(
        repository_path
      )
    else

      remote_user = username.blank? ? uri.user : username

      path = "#{uri.scheme}://#{remote_user}:#{CGI.escape(CGI.unescape(password.to_s))}@#{host_port_path_from(uri)}"
      log_safe_path = "#{uri.scheme}://#{remote_user}:*****@#{host_port_path_from(uri)}"

      if uri.scheme == 'git'
        path = "#{uri.scheme}://#{host_port_path_from(uri)}"
        log_safe_path = path
      elsif uri.scheme == 'ssh'
        path = "#{uri.scheme}://#{remote_user.to_s}@#{host_port_path_from(uri)}"
        log_safe_path = path
      end

      GitRemoteMasterInfo.new(path, log_safe_path)
    end
  end

  def host_port_path_from(uri)
    result = "#{uri.host}"
    result << ":#{uri.port}" unless uri.port.blank?
    result << "#{uri.path}"
    result
  end

  private

  def remove_cache_dirs
    FileUtils.rm_rf(cache_dir)
  end

  def cache_dir
    File.expand_path(DataDir::PluginData.pathname('mingle_git_plugin', id.to_s))
  end

  # this is hacktastic, but we'd need to make some design changes to
  # the mingle SCM API to avoid this check
  def retry_previously_failed_connection
    RUBY_PLATFORM =~ /java/ && java.lang.Thread.current_thread.name =~ /cache_revisions/
  end

end
