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

module Search

  class Query

    CARD_TYPE_REGEX = /\btype\:(["'])([^'"]+)(?:\1)|\btype:([\w]+)/i

    FRAGMENT_SIZE = 250
    NO_OF_FRAGMENTS = 3

    def initialize(query_string, options={})
      @query_string = construct_query_string(query_string)
      @type = options[:type]
      @size = options[:size]
      @highlight = options.has_key?(:highlight) ? options[:highlight] : true
      @search_fields = options[:search_fields] || []
    end

    def to_json
      to_hash.to_json
    end

    def to_hash
      query_hash = MingleConfiguration.saas? ? saas_query_format : installer_query_format
      query_hash
    end

    def query_string
      prepare_query_string(@query_string)
    end

    private
    def construct_query_string(query)
      if MingleConfiguration.saas? || !Project.activated?
        "(#{query})"
      else
        restrict_to = %w(project_id raising_project_id resolving_project_id).map {|field| "#{field}:#{Project.current.id}"}
        "(#{query}) AND (#{restrict_to.join(" OR ")})"
      end
    end

    def installer_query_format
      q = {:query => {:queryString => {:fields => @search_fields, :default_operator => "AND", :query => query_string}}}
      q[:highlight] = highlight_with_properties if @highlight
      q
    end

    def saas_query_format
      query = {
        query: {
          bool: {
            should: [
              nested_properties_query,
              fields_query
            ],
            minimum_should_match: 1,
            filter: filter
          }
        }
      }
      query.merge!(highlight: highlight_without_properties) if @highlight
      query.merge!({size: @size}) if @size
      query
    end

    def fields_query
      {
        :query_string => {:default_operator => 'AND', :query => query_string}
      }
    end

    def nested_properties_query
      q = {
        nested: {
          path: 'properties_to_index', query: {bool: {must: [{query_string: {:default_operator => 'AND', query: query_string}}]}}
        }
      }
      if @highlight
        highlight = common_highlight_options
        highlight[:fields] = {'properties_to_index.name' => {}, 'properties_to_index.value' => {}}
        q[:nested][:inner_hits] = {highlight: highlight}
      end
      q
    end

    def filter
      filter = {
        bool: {
          must: [
            {
              bool: {
                should: [{term: {project_id: Project.current.id}}, {term: {raising_project_id: Project.current.id}}, {term: {resolving_project_id: Project.current.id}}],
                minimum_should_match: 1}
            }
          ]
        }
      }
      filter[:bool][:must].push({term: {type: @type}}) if @type
      filter
    end

    def prepare_query_string(query_string)
      result = transform_card_type(query_string)
      result = to_lower result
      escape_url(result)
    end

    def to_lower(query)
      query.gsub('AND', '@@@').gsub('OR', '||').gsub('NOT', '~~~').downcase.gsub('@@@', 'AND').gsub('||', 'OR').gsub('~~~', 'NOT')
    end

    def transform_card_type(subject)
      if CARD_TYPE_REGEX.match subject
        card_type_name = $2 || $3
        card_type_id = Project.current.card_types.select { |card_type| card_type_name.downcase == card_type.name.downcase }.first.try(:id)

        subject.gsub(CARD_TYPE_REGEX, "card_type_id:#{card_type_id}")
      else
        subject
      end
    end

    def escape_url(subject)
      subject.gsub(/\:\/\//, '\\\\://')
    end

    def common_highlight_options
      {
        :encoder => 'html',
        :fragment_size => FRAGMENT_SIZE,
        :number_of_fragments => NO_OF_FRAGMENTS,
        :pre_tags => ["<span class='term fragment_highlight'>"], :post_tags =>  ['</span>']
      }
    end

    def fields_without_properties
      {
        :indexable_content => {},
        :description => {},
        :murmur => {},
        :name => {
          :number_of_fragments => 0,
          :pre_tags => ["<span class='name fragment_highlight'>"], :post_tags =>  ["</span>"]
        },
        :tag_names => {},
        :checklist_items_texts => {},
        # on card
        :raises_dependencies => {},
        :resolves_dependencies => {},

        # dependency-related
        :status => {},
        :raised_by_project => {},
        :resolved_by_project => {},
        :raised_by_card => {},
        :resolved_by_cards => {}
      }
    end


    # only string properties can be highlighted; dates, numbers, etc will be ignored by Elasticsearch
    def highlight_with_properties
      highlight = highlight_without_properties
      highlight[:fields]["properties_to_index*"] = {}
      highlight
    end

    def highlight_without_properties
      highlight = common_highlight_options
      highlight[:fields] = fields_without_properties
      highlight
    end
  end
end
