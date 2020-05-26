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

module Caches

  class RenderableCache
    extend CachingUtils
  
    class << self
      def get(renderable, context={})
        Cache.get(path_for(renderable, context))
      end
  
      def add(renderable, content, context={})
        Cache.add(path_for(renderable, context), content)
      end
  
      private
  
      def path_for(renderable, context={})
        join('renderable_cache', KeySegments::RenderableProjectStructure.new(renderable.owner), KeySegments::Renderable.new(renderable))
      end
    end
  end

  class RenderableWithMacrosCache < RenderableCache
    class << self
      # def get(renderable, context={})
      #   puts "[DEBUG] get => #{path_for(renderable, context).inspect}"
      #   super
      # end

      private
      def path_for(renderable, context={})
        cache_key = nil
        benchmark_value = Benchmark.measure do
          cache_key = join('renderable_cache',
                           KeySegments::RenderableProjectStructure.new(renderable.owner),
                           KeySegments::MacroContent.new(renderable.owner),
                           KeySegments::Renderable.new(renderable),
                           context[:embed_chart].to_s)
        end
        Rails.logger.info("====RenderableWithMacrosCache key gen===> #{benchmark_value}")
        cache_key
      end
    end
  end
  
  class ChartCache
    extend CachingUtils
    
    class << self
      def get(renderable, chart_type, position)
        Cache.get(path_for(renderable, chart_type, position))
      end
      
      def add(renderable, chart_type, position, content)
        Cache.add(path_for(renderable, chart_type, position), content)
      end
      
      private
      
      def path_for(renderable, chart_type, position)
        join('chart_cache',
             KeySegments::RenderableProjectStructure.new(renderable.owner),
             KeySegments::MacroContent.new(renderable.owner),
             KeySegments::Renderable.new(renderable), chart_type, position)
      end
    end
  end

  class CrossProjectCache
    class << self
      include CachingUtils

      def with_cache
        return get if get
        value_to_cache = yield
        add value_to_cache
        value_to_cache
      end

      def get
        Cache.get(path)
      end

      def add(string)
        Cache.add(path, string)
      end

      def path
        join('cross_project', KeySegments::AllProjects.new)
      end
    end
  end

end  
