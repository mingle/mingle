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

class ProjectCacheFacade
  def self.instance
    @instance ||= new
  end

  class UserObserver <  ActiveRecord::Observer
    observe User

    def after_update(user)
      return if ProjectCacheFacade.instance.disabled?
      user.projects.each do |project|
        ProjectCacheFacade.instance.clear_cache(project.identifier)
      end
    end
    self.instance
  end

  class CacheKeyStore

    def invalidate(identifier)
      KeySegments::ProjectCache.delete_from_cache(identifier)
    end

    def cache_key(identifier)
      KeySegments::ProjectCache.new(identifier).to_s
    end

    def project_version_key(identifier)
      cache_key identifier
    end
  end

  delegate :total_count, :clear, :in_cache_projects, :to => :@cache

  def initialize(options={})
    @use_cache_actions = {}
    @cache_key_store = CacheKeyStore.new
    @enabled = max_size > 0
  end

  # should only be called when app is start-up
  def use_cached_projects_for(controller_class_name, actions)
    @use_cache_actions[controller_class_name] = actions.collect(&:to_s)
  end

  def use_cache_action?(controller_class_name, action)
    @use_cache_actions[controller_class_name] && @use_cache_actions[controller_class_name].include?(action.to_s)
  end

  def enabled?
    @enabled
  end

  def disabled?
    !enabled?
  end

  def setup(options)
    @cache = ProjectCache.new({:project_version_key_store => @cache_key_store, :max => max_size}.merge(options))
  end

  def start_reaping_invalid_objects(interval)
    return if disabled?
    @cache.start_reaping_invalid_objects(interval)
  end

  def load_project(identifier, request_info={})
    return Project.find_by_identifier(identifier) if disabled?
    if use_cache?(request_info)
      load_project_with_cache(identifier)
    else
      load_project_without_cache(identifier)
    end
  end

  def use_cache?(request_info)
    return if disabled?
    request_info = {:get_request => true, :controller_class_name => '', :action_name => ''}.merge(request_info)
    request_info[:get_request] || use_cache_action?(request_info[:controller_class_name], request_info[:action_name])
  end

  def load_project_with_cache(identifier)
    return if disabled?
    load_cached_project(identifier) || load_project_without_cache(identifier)
  end

  def clear_cache(identifier)
    return if disabled?
    @cache_key_store.invalidate(identifier)
  end

  def cache_project(project)
    return if disabled?
    return unless project
    @cache[project.identifier] = project
  end

  def stats
    return if disabled?
    ProjectCache::Stat.sum('All', @cache.stats)
  end

  def load_project_without_cache(identifier)
    return if disabled?
    # fetch key first to avoid another thread/process update cache_key
    cache_key = @cache_key_store.cache_key(identifier)
    Project.find_by_identifier(identifier).tap do |project|
      project.project_cache_key = cache_key if project
    end
  end

  def load_cached_project(identifier)
    return if disabled?
    @cache[identifier]
  end

  def max_size
    if RUBY_PLATFORM =~ /java/
      size = System.getProperty('mingle.projectCacheMaxSize')
      size.blank? ? ProjectCache::DEFAULT_OPTIONS[:max] : size.to_i
    else
      ProjectCache::DEFAULT_OPTIONS[:max]
    end
  end
end

ProjectCacheFacade.instance # initialize the instance, avoid thread issue
