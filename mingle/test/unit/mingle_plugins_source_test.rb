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

class MinglePluginsSourceTest < ActiveSupport::TestCase
  
  # def setup
  #   MinglePlugins::Source.available_plugins = []
  # end
  # 
  # def teardown
  #   MinglePlugins::Source.available_plugins = []
  # end
  
  # class FooSourceConfiguration
  # end
  
  def setup_configurations
    first_project.with_active_project do |project|
      SubversionConfiguration.create!(:project => project, 
        :repository_path => '/good/one', :marked_for_deletion => nil)
      SubversionConfiguration.create!(:project => project, 
        :repository_path => '/deleted/one', :marked_for_deletion => true)
    end
    project_without_cards.with_active_project do |project|
      SubversionConfiguration.create!(:project => project, 
        :repository_path => '/good/two', :marked_for_deletion => false)
      SubversionConfiguration.create!(:project => project, 
        :repository_path => '/deleted/two', :marked_for_deletion => true)
    end    
  end
  
  # def test_registration
  #   assert MinglePlugins::Source.available_plugins.empty?
  #   MinglePlugins::Source.register(SubversionConfiguration)
  #   assert_equal [SubversionConfiguration], MinglePlugins::Source.available_plugins
  #   MinglePlugins::Source.register(FooSourceConfiguration)
  #   assert_equal [FooSourceConfiguration, SubversionConfiguration], MinglePlugins::Source.available_plugins.sort_by(&:to_s)
  #   MinglePlugins::Source.register(FooSourceConfiguration)
  #   assert_equal [FooSourceConfiguration, SubversionConfiguration], MinglePlugins::Source.available_plugins.sort_by(&:to_s)
  # end
  
  def test_find_for_project_ignores_configs_marked_for_deletion
    setup_configurations
    assert_equal '/good/one', MinglePlugins::Source.find_for(first_project).repository_path
    assert_equal '/good/two', MinglePlugins::Source.find_for(project_without_cards).repository_path
  end
  
  def test_find_for_project_returns_nil_when_none_found
    assert_nil MinglePlugins::Source.find_for(first_project)
  end
  
  def test_find_for_project_marks_all_for_deletion_when_too_many_found
    first_project.with_active_project do |active_project|
      SubversionConfiguration.create!(:project => active_project, 
        :repository_path => '/good/one', :marked_for_deletion => false)
      SubversionConfiguration.create!(:project => active_project, 
        :repository_path => '/deleted/one', :marked_for_deletion => false)
      assert_nil MinglePlugins::Source.find_for(active_project)
      all_configs = SubversionConfiguration.find(:all, :conditions => ["project_id = #{active_project.id}"])
      assert_equal 2, all_configs.size
      assert all_configs.all?{|config| config.marked_for_deletion}
    end
  end
  
  def test_find_all_marked_for_deletion
    MinglePlugins::Source.available_plugins.each do |plugin_type|
      plugin_type.find(:all).each(&:destroy)
    end
    
    setup_configurations
    
    deleted_configs = MinglePlugins::Source.find_all_marked_for_deletion
    assert_equal 2, deleted_configs.size
    assert_equal ['/deleted/one', '/deleted/two'], deleted_configs.collect(&:repository_path).sort
  end
  
  def test_find_all_marked_for_deletion_returns_empty_array_when_none_exist
    MinglePlugins::Source.available_plugins.each do |plugin_type|
      plugin_type.find(:all).each(&:destroy)
    end
    assert_equal [], MinglePlugins::Source.find_all_marked_for_deletion
  end
  
  
end

