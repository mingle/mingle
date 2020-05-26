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

require 'elasticsearch'

module Aws
  class ElasticSearchClient
    def initialize(endpoint=nil, aws_region=nil)
      aws_region ||= 'us-west-1'
      @es_client = Elasticsearch::Client.new(transport: Aws::HttpClient.new(endpoint, 'es', aws_region)) unless endpoint.blank?
    end

    def create_index_with_mappings(index)
      return unless @es_client
      if !@es_client.indices.exists?(index: index)
        @es_client.indices.create(index: index, body: {mappings: mappings, settings: settings}.to_json)
      else
        @es_client.indices.put_settings(index: index, body: dynamic_settings.to_json)
        @es_client.indices.put_mapping(index: index, type: 'document', body: mappings.to_json)
      end
    end


    def index(id, body, index_name, type)
      #Todo: modify properties generated in card.rb to this structure when using only one cluster
      data = modify_properties(body)
      data[:type] = type
      data[:timestamp] = (Time.now.to_f * 1000).to_i
      invoke_on_client(:index, index: index_name, type: 'document', id: id_for_type(id, type), body: data.to_json)
    end

    def delete(ids, index_name, type)
      deletes = ids.map { |id| {delete: {_id: id_for_type(id, type), _type: 'document', _index: index_name}} }
      invoke_on_client(:bulk, body: deletes)
    end

    def bulk(body)
      invoke_on_client(:bulk, body: body)
    end

    def delete_by_query(index_name, query)
      invoke_on_client(:delete_by_query, index: index_name, body: query.to_json)
    end

    def search(index_name, query)
      invoke_on_client(:search, index: index_name, body: query.to_json)
    end

    private
    def modify_properties(body)
      data = body.dup
      properties_to_index = data.delete(:properties_to_index) || []
      data[:properties_to_index] = []
      properties_to_index.each do |k, v|
        data[:properties_to_index] << {name: k, value: v}
      end
      data
    end

    def invoke_on_client(method, *params)
      begin
        if @es_client
          JSON.parse(@es_client.send(method, *params))
        end
      rescue Aws::HttpClient::AWSRequestException => e
        Rails.logger.error "Elastic search error: #{e.message}"
        {'hits' => {'hits' => [], 'total' => 0}}
      end
    end

    def mappings
      {
        document:
          {date_detection: false,
           properties: {
             namespace: {type: 'keyword'},
             type: {type: 'keyword'},
             timestamp: {type: 'date'},
             name: {type: 'text', boost: 5, analyzer: 'mingle'},
             murmur: {type: 'text', boost: 2, analyzer: 'mingle'},
             description: {type: 'text', boost: 1, analyzer: 'mingle'},
             indexable_content: {type: 'text', boost: 2, analyzer: 'mingle'},
             properties_to_index: {type: 'nested'}
           }
          }
      }
    end

    def settings
      {
        analysis: {
          analyzer: {
            mingle: {
              tokenizer: 'standard',
              filter: %w(standard lowercase snowball)
            }
          }
        },
      }.merge(dynamic_settings)
    end

    def dynamic_settings
      {'index.mapping.total_fields.limit' => 1000}
    end

    def id_for_type(id, type)
      "#{type}-#{id}"
    end

  end
end
