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

# Copyright 2010 ThoughtWorks, Inc. Licensed under the Apache License, Version 2.0.

require 'uri'
require 'cgi'
require File.expand_path(File.join(File.dirname(__FILE__), 'hg_java_env'))

#
# HgConfiguration is the model class for storing a project's hg repository
# connection information. HgConfiguration is also responsible for producing
# hg-specific vocabulary and constructing the 'repository' object that
# mingle will use to interact with the actual hg repository.
#
# Required by Mingle: project, display_name, vocabulary, view_partials, repository
#
# Provided by Mingle: strip_on_write, include RepositoryModelHelper, project.encrypt
class HgConfiguration < ActiveRecord::Base
  # supplies create_or_update method that keeps controller simple
  # supplies mark_for_deletion method used by mingle to manage config lifecycle
  include RepositoryModelHelper

  # mingle model utility that will strip leading and trailing whitespace from all attributes
  strip_on_write
  # configuration must belong to a project
  belongs_to :project
  validates_presence_of :repository_path
  after_create :remove_cache_dirs
  after_destroy :remove_cache_dirs
  before_save :encrypt_password

  #<snippet name="display_name">
  class << self
    # *returns*: Human-readable name of SCM type, used in source config droplist
    def display_name
      "Mercurial"
    end
  end
  #</snippet>

  def remove_cache_dirs
    FileUtils.rm_rf(data_dir)
  end

  # *returns* whether or not the repository content is ready to be browsed on the source tab
  def source_browsing_ready?
    initialized?
  end

  # prevent user from storing any userinfo in repostory path
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

  # *returns*: hg-specific terms for mingle display
  def vocabulary
    {
      'revision' => 'changeset',
      'committed' => 'committed',
      'repository' => 'repository',
      'head' => 'tip',
      'short_identifier_length' => 12
    }
  end

  # *returns*: table header and row partials to be used in source directory browser
  def view_partials
    {:node_table_header => 'hg_source/node_table_header',
     :node_table_row => 'hg_source/node_table_row' }
  end

  # *returns*: an instance of HgRepository for Mercurial repository sepcified by this configuration
  def repository
    clone_path = File.join(data_dir, 'repository')
    style_dir = File.expand_path("#{File.dirname(__FILE__)}/../templates")

    java_hg_client = com.thoughtworks.studios.mingle.hg.hgcmdline::HgClient.new(repository_path_with_userinfo, clone_path, style_dir)
    hg_client = HgClient.new(java_hg_client)
    source_browser_cache_path = File.join(data_dir, 'source_browser_cache')
    mingle_rev_repos = HgMingleRevisionRepository.new(project)
    source_browser = HgSourceBrowser.new(
      java_hg_client, source_browser_cache_path, mingle_rev_repos
    )
    repository = HgRepository.new(hg_client,  source_browser)
    HgRepositoryClone.new(HgSourceBrowserSynch.new(repository, source_browser), data_dir, project, retry_previously_failed_connection)
  end

  # *returns*: options needed for RepositoryModelHelper::create_or_update to create
  # new config based upon existing config
  def clone_repository_options
    {:repository_path => self.repository_path, :username => self.username, :password => self.password}
  end

  # *returns*: whether new configuration attributes contain a path name as required by
  # RepositoryModel::create_or_update to determine whether to update existing config for create new config
  def repository_location_changed?(configuration_attributes)
    self.repository_path != configuration_attributes[:repository_path]
  end

  #:nodoc:
  def repository_path_with_userinfo
    uri = URI.parse(repository_path)

    return repository_path if (uri.scheme.blank? || uri.scheme == 'ssh')

    if !username.blank? && !password.blank?
      "#{uri.scheme}://#{username}:#{CGI.escape(CGI.unescape(password))}@#{host_port_path_from(uri)}"
    elsif !username.blank?
      "#{uri.scheme}://#{username}@#{host_port_path_from(uri)}"
    elsif !uri.user.blank? && password.blank?
      "#{uri.scheme}://#{uri.user}@#{host_port_path_from(uri)}"
    elsif !uri.user.blank? && !password.blank?
      "#{uri.scheme}://#{uri.user}:#{CGI.escape(CGI.unescape(password))}@#{host_port_path_from(uri)}"
    else
      repository_path
    end

  end

  def host_port_path_from(uri)
    result = "#{uri.host}"
    result << ":#{uri.port}" unless uri.port.blank?
    result << "#{uri.path}"
    result
  end

  private

  def data_dir
    File.expand_path(DataDir::PluginData.pathname('mingle_hg_plugin', id.to_s))
  end

  # this is hacktastic, but we'd need to make some design changes to
  # the mingle SCM API to avoid this check
  def retry_previously_failed_connection
     RUBY_PLATFORM =~ /java/ && java.lang.Thread.current_thread.name =~ /cache_revisions/
  end

end
