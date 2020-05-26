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

module Renderable

  module Caching

    module SingletonMethods
      def disable_caching
        @caching_disabled = true
      end

      def enable_caching
        @caching_disabled = false
      end

      def caching_enabled?
        !defined?(@caching_disabled) || !@caching_disabled
      end
    end

    def self.included(base)
      base.alias_method_chain :formatted_content, :caching
    end

    def formatted_content_with_caching(view_helper, context={}, substitutions = nil)
      return formatted_content_without_caching(view_helper, context, substitutions) if content_changed? || context[:conversion_to_html_in_progress]
      read_cached_content(context) || format_content_and_write_cache(view_helper, context, substitutions)
    rescue TimeoutError => e
      raise e
    rescue => e
      Project.logger.info "Error retrieving cached content -- rendering content without caching.  Check your memcache settings in web.xml.  Original trace: #{e.message}"
      Project.logger.info e.backtrace.join("\n")
      return formatted_content_without_caching(view_helper, context, substitutions)
    end

    private

    def format_content_and_write_cache(view_helper, context, substitutions)
      content = formatted_content_without_caching(view_helper, context, substitutions)
      write_cached_content(content, context) if Renderable.caching_enabled? && can_be_cached? && id && macro_execution_errors.blank?
      content
    end

    def write_cached_content(content, context)
      cache.add(self, content, context)
 end

    def read_cached_content(context)
      return unless Renderable.caching_enabled? && id && version
      cache.get(self, context)
    end

    def cache
      has_macros ? Caches::RenderableWithMacrosCache : Caches::RenderableCache
    end
  end
end
