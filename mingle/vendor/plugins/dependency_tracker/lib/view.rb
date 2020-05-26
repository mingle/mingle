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

require 'rubygems'
require 'active_support'

module DependencyTracker
  class View
    def initialize(current_project, current_card, properties, projects, dependency_project, card_types, met, app_context, program_macro, filter)
      @current_project = current_project
      @current_card = current_card
      @properties = properties
      @projects = projects
      @dependency_project = dependency_project
      @card_types = card_types
      @met = met
      @app_context = normalize_app_context(app_context)
      @program_macro = program_macro
      @filter = filter
    end

    def display
      html = ""
      html << script
      html << insert_stylesheet
      html << container_div
      wrap_in_div html
    end

    private
    def script
      <<-HTML
<notextile><!-- MACRO VERSION: 1.1.1-14 --></notextile>
<script>
  jQuery.noConflict();
  jQuery(document).ready(function() {
    jQuery('.dt-container').each(function() {
      var dom = jQuery(this);
      #{invoke_init}
    });
  });
</script>
      HTML
    end

    def invoke_init
      "DependencyTracker.init('#{@app_context}', dom, #{escaped_json @current_project.identifier}, #{escaped_json @current_card && @current_card.number }, #{escaped_json @projects}, #{escaped_json(@dependency_project)}, #{@properties.to_json}, #{@card_types.to_json}, #{@met.to_json}, #{@program_macro}, #{@filter.to_json});"
    end

    def normalize_app_context(app_context)
      app_context=='/' ? '' : app_context
    end

    def escaped_json(data)
      return data.to_json.gsub('#','&#35;')
    end

    def container_div
      <<-WRAPPER
<div class="dt-container"></div>
WRAPPER
    end

    def insert_stylesheet
      "<link type='text/css' href='#{ url 'stylesheets/dependency-tracker.css' }' rel='stylesheet' />"
    end

    def wrap_in_div html
      '<div class="dt-ui">' + html + '</div>'
    end

    def url suffix
      "#{@app_context}/plugins/dependency_tracker-1.1.1-14/#{suffix}"
    end
  end
end
