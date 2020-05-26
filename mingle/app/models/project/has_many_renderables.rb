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

class Project
  module HasManyRenderables

    def self.included(base)
      base.class_eval do
        def self.invalidate_renderable_content_cache(source = 'unknown')
          return unless Renderable.caching_enabled?
          self.not_hidden.to_a.shift_each! do |project|
            project.invalidate_renderable_content_cache(source)
          end
        end
      end
    end

    def invalidate_renderable_content_cache(source = 'unknown')
      return unless Renderable.caching_enabled?
      logger.debug("Project #{self.identifier} renderable content cache invalidated by #{source}.")
      CacheKey.touch(:structure_key, self)
    end
  end
end
