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

module KeySegments

  # base class for keys that are cached in memcached (the cached values are wiped out on deletion of the key); inheritors must implement key_string_for
  class Cached
    include CachingUtils

    class << self
      def delete_from_cache(*args)
        key_name = self.key_string_for(*args)
        ThreadLocalCache.set("keys_#{key_name}", nil)
        Cache.delete key_name
      end
      alias_method :invalidate, :delete_from_cache
    end

    def initialize(*args)
      @args = args
    end

    def to_s
      key_name = self.class.key_string_for(*@args)
      ThreadLocalCache.get("keys_#{key_name}") { cached_unique_key(key_name) }
    end
  end

  # represent of state of a card, key changed after any card update or card becomes staled
  class Card
    include CachingUtils

    class ParentCardChangeObserver < ActiveRecord::Observer
      observe ::Card
      include SqlHelper

      def after_update(card)
        card_as_parent_for_all_tree_conditions = card.tree_configurations.collect{ |config| config.sub_tree_condition(card).to_sql }
        card_as_value_for_all_card_relationship_property_definitions_conditions = card.project.card_relationship_property_definitions.collect { |pd| card.as_value_for_property_defnition_condition(pd) }
        all_possible_card_values_condition = card_as_parent_for_all_tree_conditions + card_as_value_for_all_card_relationship_property_definitions_conditions
        return if all_possible_card_values_condition.empty?
        CardCachingStamp.update(all_possible_card_values_condition.join(" OR "))
      end

      self.instance
    end

    class CardStaleObserver < ActiveRecord::Observer
      observe StalePropertyDefinition
      include SqlHelper

      on_callback(:after_create, :after_destroy) do |stale_aggregate|
        CardCachingStamp.update([stale_aggregate.card_id])
      end

      self.instance
    end

    class TreeBelongingObserver < ActiveRecord::Observer
      observe TreeBelonging

      on_callback(:after_create, :after_destroy) do |tree_belonging|
        CardCachingStamp.update [tree_belonging.card_id]
      end

      TreeBelongingObserver.instance
    end

    # for Keys::CardMurmurs
    class CardMurmurLinkObserver < ActiveRecord::Observer
      observe CardMurmurLink

      def after_create(link)
        Project.with_active_project(link.project_id) do |project|
          CardCachingStamp.update([link.card_id])
        end
      end

      self.instance
    end

    def initialize(card)
      @card = card
    end

    def to_s
      join(@card.number, @card.version, @card.caching_stamp.to_s)
     end
  end

  # represent for current user, key changed after login or user change role of project
  # not using Memcached to store key segment
  class CurrentUser
    include CachingUtils

    def initialize(project)
      @user = User.current
      @project = project
    end

    def to_s
      join(@user.id, @user.privilege_level(@project).rank)
    end
  end

  # only used in installer
  class ProjectCache < Cached
    PROJECT_CACHE_KEY_PREFIX = 'project_cache'

    def self.key_string_for(project_identifier)
      "#{PROJECT_CACHE_KEY_PREFIX}-#{project_identifier}"
    end
  end

  # represent of all user's status, key changed after any user update
  class AllUsers
    include CachingUtils
    include CachingUtils::DatabaseFingerprinting

    def to_s
      "all_users_#{fingerprint(::User, {})}"
    end
  end

  #Represents change in any project including deletion and creation
  class AllProjects
    include CachingUtils
    include CachingUtils::DatabaseFingerprinting

    ALL_PROJECTS_KEY = 'all_projects_key'

    def to_s
      "#{ALL_PROJECTS_KEY}_#{fingerprint(::Project, {})}"
    end
  end

  class AllFavorites
    ALL_FAVORITE_KEY = 'all_fav'

    def initialize(project_id)
      @project_id = project_id
    end

    def to_s
      count = Favorite.count(:conditions =>["project_id = ? AND user_id IS NULL", @project_id])
      last_modified = Favorite.maximum(:updated_at, :conditions =>["project_id = ? AND user_id IS NULL", @project_id])
      "#{ALL_FAVORITE_KEY}_#{@project_id}_#{last_modified.to_f}_#{count}"
    end
  end

  class PersonalFavorites
    KEY = 'pf'

    def initialize(project_id, user_id)
      @project_id = project_id
      @user_id=user_id
    end

    def to_s
      count = Favorite.count(:conditions =>["project_id = ? AND user_id = ?", @project_id, @user_id])
      last_modified = Favorite.maximum(:updated_at, :conditions =>["project_id = ? AND user_id = ?", @project_id, @user_id])
      "#{KEY}_#{@project_id}_#{@user_id}_#{last_modified.to_f}_#{count}"
    end

  end

  class RenderableProjectStructure
    include CachingUtils
    include CachingUtils::DatabaseFingerprinting

    def initialize(project)
      @project = project
    end

    def to_s()
      condition = ["project_id = ?", @project.id]
      page_fingerprint = count_fingerprint(::Page, condition)
      card_list_view_fingerprint = fingerprint(::CardListView, condition)
      unique_stuff = digest(join(@project_id, CacheKey.project_structure_key(@project), page_fingerprint, card_list_view_fingerprint, AllProjects.new()))
      "renderable_project_structure_key_" + unique_stuff
    end
  end

  class MacroContent
    include CachingUtils
    include CachingUtils::DatabaseFingerprinting

    def initialize(project)
      @project = project
    end

    def to_s()
      card_fingerprint = fingerprint(::Card, nil)
      join("macro_content_key_for", @project_id, card_fingerprint, AllUsers.new.to_s)
    end
  end

  class Renderable
    include CachingUtils

    def initialize(renderable)
      @renderable = renderable
    end

    def to_s
      if @renderable.respond_to?(:versioned)
        join(@renderable.versioned.class, @renderable.versioned.id, @renderable.version, @renderable.latest_version?)
      else
        join(@renderable.class, @renderable.id, @renderable.version)
      end
    end
  end

  class ColumnInformation

    def initialize(project)
      @project = project
    end

    def to_s(table_name)
      "#{@project.cache_key.structure_key}_#{table_name}"
    end
  end

  class UserOwnershipProperties

    def initialize(project)
      @project = project
    end

    def to_s()
      "#{@project.cache_key.structure_key}_user_properties"
    end
  end

  class ProjectCardTypeColors

    def initialize(project)
      @project = project
    end

    def to_s()
      "#{@project.cache_key.structure_key}_card_type_color_map"
    end
  end

  class AllDependencies
    include CachingUtils
    include CachingUtils::DatabaseFingerprinting

    def to_s
      "all_dependencies_#{fingerprint(::Dependency, {})}"
    end
  end

  class ViewParams
    include CachingUtils
    include CachingUtils::DatabaseFingerprinting

    def initialize(view)
      @view = view
    end

    def to_s
      digest(@view.to_params.to_json)
    end

  end
end
