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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class RepositoryModelHelperTest < ActiveSupport::TestCase  
  class RepositoryStub
    include RepositoryModelHelper

    attr_accessor :password, :username, :repository_path, :project_id, :id
    
    @@repositories = {}
    
    def self.reset
      @@repositories = {}
    end
    
    def initialize(options={})
    end
    
    def self.create(options={})
      config = self.new(options)
      config.update_attributes(options)
    end
    
    def self.find_by_project_id_and_id(project_id, id)
      @@repositories["#{project_id}:#{id}"]
    end
    
    def self.find_by_project_id_and_marked_for_deletion(project_id, marked_for_deletion)
      config_for_project = @@repositories.find { |e| e.first.include?(project_id) && !e[1].mark_for_deletion? }
      config_for_project[1] if config_for_project
    end
    
    def self.find_by_id(id)
      @@repositories.first
    end
    
    def self.find_project(project_id)
      OpenStruct.new(:repository_configuration => self.find_by_project_id_and_marked_for_deletion(project_id, false))
    end
    
    def update_attributes(attributes={})
      self.project_id = attributes[:project_id] if attributes[:project_id]
      self.password = attributes[:password] if attributes[:password]
      self.username = attributes[:username] if attributes[:username]
      self.repository_path = attributes[:repository_path] if attributes[:repository_path]
      self.save
    end
    
    def valid?
      !self.repository_path.blank?
    end
    
    def attributes
      {}
    end

    def attributes=(attributes)
      self.repository_path = attributes[:repository_path]
    end

    
    def save
      if self.id.blank?
        self.id = "id".uniquify
      end
      @@repositories[key] = self
    end
    
    def key
      "#{self.project_id}:#{self.id}"
    end
    
    def mark_for_deletion?
      @mark_for_deletion ||= false
    end
    
    #interface need to be implemented for repository model
    def repository_location_changed?(attributes)
      self.repository_path != attributes[:repository_path]
    end
    
    def clone_repository_options
      {:repository_path => self.repository_path, :username => self.username, :password => self.password}
    end
    
    def mark_for_deletion
      @mark_for_deletion = true
    end
    
    def errors
      @errors_happened = true
      FakeRepositoryErrors.new
    end
    
    def errors_happened
      @errors_happened
    end

    class FakeRepositoryErrors
      def add_to_base(message)
        #nothing
      end
    end
  end
  
  def setup
    @project_id = 'project_id'
    @default_options = {:project_id => @project_id, :password => 'pass', :username => 'username', :repository_path => 'repository_path'}
    RepositoryStub.reset
  end
  
  def test_should_create_new_configuration_when_id_is_nil
    config = RepositoryStub.create_or_update(@project_id, nil, @default_options)
    assert_not_nil config.id
    assert_equal 'project_id', config.project_id
    assert_equal 'pass', config.password
    assert_equal 'username', config.username
    assert_equal 'repository_path', config.repository_path
  end
  
  def test_should_handle_string_keys
    config = RepositoryStub.create_or_update(@project_id, nil, @default_options.stringify_keys)
    assert_not_nil config.id
    assert_equal 'project_id', config.project_id
    assert_equal 'pass', config.password
    assert_equal 'username', config.username
    assert_equal 'repository_path', config.repository_path
  end
  
  def test_should_update_configuration_with_id_is_specified_and_linked_to_an_existed_configuration_when_updating_password
    config = RepositoryStub.create_or_update(@project_id, nil, @default_options)
    new_config = RepositoryStub.create_or_update(@project_id, config.id, @default_options.merge(:password => 'new password'))
    
    assert_equal config.id, new_config.id
    
    assert_equal 'project_id', new_config.project_id
    assert_equal 'new password', new_config.password
    assert_equal 'username', new_config.username
    assert_equal 'repository_path', new_config.repository_path
  end
  
  def test_should_not_use_project_id_and_id_in_the_options
    config = RepositoryStub.create_or_update(@project_id, nil, @default_options)
    new_config = RepositoryStub.create_or_update(@project_id, config.id, @default_options.merge(:password => 'new password', :project_id => 'hack project id', :id => 'hack id'));
    assert_equal config.id, new_config.id
    
    assert_equal 'project_id', new_config.project_id
    assert_equal 'new password', new_config.password
    assert_equal 'username', new_config.username
    assert_equal 'repository_path', new_config.repository_path
  end
  
  def test_should_clear_password_when_username_changed
    config = RepositoryStub.create_or_update(@project_id, nil, @default_options)
    new_config = RepositoryStub.create_or_update(@project_id, config.id, :username => 'new username', :repository_path => 'repository_path')

    assert_nil new_config.password
    assert_equal 'new username', new_config.username
    assert_equal 'repository_path', new_config.repository_path
  end
  
  def test_should_mark_config_as_deletion_and_create_new_repository_when_repository_location_changed
    config = RepositoryStub.create_or_update(@project_id, nil, @default_options)
    assert !config.mark_for_deletion?
    
    new_config = RepositoryStub.create_or_update(@project_id, config.id, :repository_path => 'new repository location', :username => 'username')

    assert config.mark_for_deletion?
    assert_not_equal config.id, new_config.id
    assert_equal 'pass', new_config.password
    assert_equal 'username', new_config.username
    assert_equal 'new repository location', new_config.repository_path
  end
  
  def test_should_not_copy_password_when_repository_location_and_username_changed
    config = RepositoryStub.create_or_update(@project_id, nil, @default_options)
    assert !config.mark_for_deletion?
    
    new_config = RepositoryStub.create_or_update(@project_id, config.id, :repository_path => 'new repository location', :username => 'new username')

    assert config.mark_for_deletion?
    assert_not_equal config.id, new_config.id
    assert_nil new_config.password
    assert_equal 'new username', new_config.username
    assert_equal 'new repository location', new_config.repository_path
  end
  
  def test_should_can_specify_password_when_repository_location_and_username_changed
    config = RepositoryStub.create_or_update(@project_id, nil, @default_options)
    assert !config.mark_for_deletion?
    new_config = RepositoryStub.create_or_update(@project_id, config.id, :repository_path => 'new repository location', :username => 'new username', :password => 'new pass')

    assert config.mark_for_deletion?
    assert_not_equal config.id, new_config.id
    assert_equal 'new pass', new_config.password
    assert_equal 'new username', new_config.username
    assert_equal 'new repository location', new_config.repository_path
  end

  # bug 8515
  def test_should_not_allow_creation_of_repositry_when_one_already_exists
    config = RepositoryStub.create_or_update(@project_id, nil, @default_options)
    assert config
    
    new_config = RepositoryStub.create_or_update(@project_id, nil, @default_options)
    
    assert !config.mark_for_deletion?
    assert new_config.errors_happened
  end

  def test_should_not_mark_config_for_deletion_when_invalid_path_provided
    config = RepositoryStub.create_or_update(@project_id, nil, @default_options)
    assert config

    options = {:project_id => @project_id, :password => 'pass', :username => 'username', :repository_path => ''}    
    new_config = RepositoryStub.create_or_update(@project_id, config.id, options)
    
    assert !config.mark_for_deletion?
  end
end
