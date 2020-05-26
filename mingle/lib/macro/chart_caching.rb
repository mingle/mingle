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

module ChartCaching
  def self.included(base)
    base.alias_method_chain :extract_and_generate, :caching
  end
  
  def extract_and_generate_with_caching(template, type, index, options = {})
    if options[:dont_use_cache]
      extract_and_generate_without_caching(template, type, index, options)
    else
      read_cached_content(type, index, options) || extract_and_generate_and_write_cache(template, type, index, options)
    end
  rescue Exception => e
    Project.logger.info "Error retrieving cached chart -- rendering chart without caching.  Check your memcache settings in web.xml.  Original trace: #{e.message}"
    Project.logger.debug e.backtrace.join("\n")
    return extract_and_generate_without_caching(template, type, index, options)
  end
  
  private
  
  def extract_and_generate_and_write_cache(template, type, index, options = {})
    chart = extract(template, type, index, options)
    chart_image = chart.generate
    write_cached_content(chart_image, options[:content_provider], type, index) if Renderable.caching_enabled? && chart.can_be_cached? && valid_content_provider?(options[:content_provider]) && !any_cross_project_reporting_on_renderable?(options[:content_provider])
    chart_image
  end
  
  def write_cached_content(chart_image, renderable, chart_type, index)
    cache.add(renderable, chart_type, index, chart_image)
  end
  
  def read_cached_content(chart_type, index, options)
    return unless Renderable.caching_enabled? && valid_content_provider?(options[:content_provider])
    cache.get(options[:content_provider], chart_type, index)
  end
  
  def cache
    Caches::ChartCache
  end
  
  def valid_content_provider?(content_provider)
    content_provider && content_provider.id && content_provider.version
  end
  
  def any_cross_project_reporting_on_renderable?(content_provider)
    content_provider.detect_cross_project_macro
    content_provider.rendered_projects.size > 0
  end
end
