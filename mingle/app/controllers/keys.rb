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

module Keys
  class Discussion
    include CachingUtils

    def path_for(discussion, prefix="discussion_body")
      card = discussion.card
      segments = [prefix, KeySegments::CurrentUser.new(card.project), CardMurmurs.new.path_for(card)]
      join(*segments)
    end
  end

  class CardComments
    include CachingUtils

    def path_for(card)
      join('card_comments', card.id, card.version)
    end
  end

  class CardMurmurs
    include CachingUtils
    def path_for(card)
      join('card_murmurs', card.id, card.version, card.caching_stamp)
    end
  end

  class CardMurmursShowControl
    include CachingUtils

    def path_for(discussion, allow_comments)
      card = discussion.card
      segments = ["show_murmurs_control", CardMurmurs.new.path_for(card), KeySegments::CurrentUser.new(card.project)]
      segments << (allow_comments ? "allow_comments" : "deny_comments")
      join(*segments)
    end
  end

  class CardDivCache
    include CachingUtils
    include CardsHelper

    def path_for(card, view, users_key = KeySegments::AllUsers.new, dependency_key = KeySegments::AllDependencies.new)
      join('card_div_cache',
           KeySegments::Card.new(card),
           sort_position(card, view),
           card.ancestor_numbers,
           CacheKey.project_structure_key(card.project),
           users_key,
           dependency_key,
           KeySegments::ViewParams.new(view))
    end
  end

  class CardPopupData
    include CachingUtils

    def path_for(card)
      join('card_popup_data_cache', KeySegments::Card.new(card), KeySegments::CurrentUser.new(card.project), KeySegments::AllUsers.new, CacheKey.project_structure_key(card.project))
    end
  end

  class CardTransition
    include CachingUtils

    def path_for(card)
      join('card_transition_cache', KeySegments::Card.new(card), CacheKey.project_structure_key(card.project), KeySegments::CurrentUser.new(card.project))
    end
  end

  class Transitions
    include CachingUtils

    def path_for(project)
      join('transitions_cache', CacheKey.project_structure_key(project))
    end
  end

  class FeedUrl
    include CachingUtils

    def path_for(project, request_params)
      join('feed_url_cache', CacheKey.project_structure_key(project), User.current.privilege_level(project).rank, digest(request_params))
    end
  end

  class FavoritesView
    include CachingUtils

    def path_for(project, page_allows_view_creation)
      join('favorites_view_cache', KeySegments::AllFavorites.new(project.id), User.current.privilege_level(project).rank, page_allows_view_creation)
    end
  end

  class PersonalFavoritesView
    include CachingUtils

    def path_for(project, page_allows_view_creation)
      join('personal_favorites_view_cache', KeySegments::PersonalFavorites.new(project.id, User.current.id), User.current.privilege_level(project).rank, page_allows_view_creation)
    end
  end

  class TreeFilter
    include CachingUtils

    def path_for(tree_config, tag_values)
      join('tree_filter_cache', CacheKey.project_structure_key(tree_config.project), KeySegments::AllUsers.new, tree_config.id, tag_values.hash)
    end
  end

  class Filters
    include CachingUtils

    def path_for(project, filter_by_mql, tags)
      join('filter_cache', CacheKey.project_structure_key(project), filter_by_mql, project.tags.used.hash, tags.hash)
    end
  end

  class ColorLegend
    include CachingUtils

    def path_for(project, color_by)
      join('color_legend_cache', CacheKey.project_structure_key(project), User.current.privilege_level(project).rank, color_by.to_s.downcase)
    end
  end

  class TreeAndStyleSelector
    include CachingUtils
    def path_for(project, tree_name, style, tab, grid_setting)
      join('tree_and_style_selector_cache', CacheKey.project_structure_key(project), User.current.privilege_level(project).rank, tree_name, style, tab, grid_setting)
    end
  end

  class ShowPropertyContainer
    include CachingUtils
    def path_for(project, card, show_hidden_property)
      join('show_property_container_cache', CacheKey.project_structure_key(project), KeySegments::Card.new(card), User.current.privilege_level(project).rank, show_hidden_property)
    end
  end

  class ShowPropertyLazyContainer
    include CachingUtils
    def path_for(project, card)
      join('show_property_container_lazy', project.identifier, KeySegments::Card.new(card))
    end
  end

  class PropertyEditor
    include CachingUtils
    def path_for(project, options)
      options_key = MD5::md5(options.to_a.collect(&:to_s).sort.flatten.join('/')).hexdigest
      join('property_editor', project.id, CacheKey.project_structure_key(project), User.current.privilege_level(project).rank, options_key)
    end
  end

  class EventFeedEntry
    include CachingUtils
    def path_for(deliverable, entry)
      join(digest(join('event_feed_entry', deliverable.cache_key.feed_key, MingleConfiguration.site_url_with_context_path)), entry.id)
    end
  end

  class CardXml
    include CachingUtils
    def path_for(project, card, include_transition_ids)
      join(digest(join('card', CacheKey.project_structure_key(project),
                       MingleConfiguration.site_url_with_context_path)), card.id, card.version, include_transition_ids)
    end
  end

  class UserPropertyValues
    include CachingUtils
    def path_for(project)
      join('user_property_values', digest(join(KeySegments::AllUsers.new, CacheKey.project_structure_key(project))), project.id)
    end
  end

  class AtUserSuggestion
    include CachingUtils
    def path_for(project)
      join('at_user_suggestion', digest(join(KeySegments::AllUsers.new, CacheKey.project_structure_key(project))), project.id)
    end
  end

  class TagsData
    include CachingUtils
    def path_for(project)
      join("project_tags_json", project.cache_key.structure_key)
    end
  end

  class PropertyDefinitionJSON
    include CachingUtils
    def path_for(project, property_definition, include_property_values, excluded_attrs)
      join(project.cache_key.structure_key, 'property_definition_json', property_definition.id, include_property_values, digest(excluded_attrs.to_s))
    end
  end

  class CardTypeJSON
    include CachingUtils
    def path_for(project, card_type, include_property_values)
      join(project.cache_key.structure_key, 'card_type_json', card_type.id, include_property_values, )
    end
  end
end
