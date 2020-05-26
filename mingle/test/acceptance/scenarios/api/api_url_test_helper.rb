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

module API
  module URLTestHelper

    def basic_auth_url_for(*paths)
      defaults = {:user => "admin", :password => MINGLE_TEST_DEFAULT_PASSWORD, :host => "localhost", :port => 8080}

      options = defaults.merge(paths.extract_options!)
      options[:userinfo] = "#{options.delete(:user).strip}:#{options.delete(:password)}"

      paths.join("/").split("?").tap do |p|
        options[:path] = p.shift
        options[:query] = p.join("&") unless p.empty?
      end

      # allow building anonymous urls by setting :user to nil or blank
      options.delete(:userinfo) if options[:userinfo] =~ /^:/

      URI::HTTP.build(options).to_s
    end

    # convenience method for building api urls
    def base_api_url_for(*paths)
      basic_auth_url_for *(%w(/api v2) + paths)
    end

    # most of the time, we want and API call for a specific project
    def project_base_url_for(*paths)
      base_api_url_for("projects", @project.identifier, *paths)
    end

    def projects_list_url(options={})
      base_api_url_for "projects.xml", options
    end

    def project_url(options={})
      base_api_url_for("projects", "#{@project.identifier}.xml", options)
    end

    def cards_list_url(options={})
      project_base_url_for "cards.xml", options
    end

    def card_url_for(card, options={})
      project_base_url_for("cards", "#{card.number}.xml", options)
    end

    def card_type_url_for(card_type, options={})
      project_base_url_for "card_types", "#{card_type.id}.xml", options
    end

    def card_types_list_url(options={})
      project_base_url_for "card_types.xml", options
    end

    def property_definition_url_for(property_definition, options={})
      project_base_url_for "property_definitions", "#{property_definition.id}.xml", options
    end

    def property_definitions_list_url(options={})
      project_base_url_for "property_definitions.xml", options
    end

    def transition_url_for(transition, options={})
      project_base_url_for "transitions", "#{transition.id}.xml", options
    end

    def transition_execution_url_for(transition, options={})
      project_base_url_for "transition_executions", "#{transition.id}.xml", options
    end

    def transitions_list_url(options={})
      project_base_url_for "transitions.xml", options
    end

    def murmurs_list_url(options={})
      project_base_url_for "murmurs.xml", options
    end

    def murmur_url_for(murmur, options={})
      project_base_url_for "murmurs", "#{murmur.id}.xml", options
    end

    def create_card_murmurs_url(card_number)
      project_base_url_for "cards", card_number, "murmurs.xml"
    end

    def feeds_url(options={})
      project_base_url_for "feeds", "events.xml", options
    end

    def wiki_list_url(options={})
      project_base_url_for "wiki.xml", options
    end

    def wiki_url_for(page, options={})
      project_base_url_for "wiki", "#{page.identifier}.xml", options
    end

    def site_uri_from_server
      @@site_uri ||= URI.parse(interrogate_server_site_uri)
    end

    def interrogate_server_site_uri
      # the server, running in a different process, may have a different siteURL if running in MRI
      request_url = basic_auth_url_for "/_class_method_call", :query => "class=MingleConfiguration&method=site_url"
      URI.extract(Net::HTTP.get_response(URI.parse(request_url)).body).last
    end
  end
end
