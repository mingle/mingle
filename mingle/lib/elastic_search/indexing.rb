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

class ElasticSearch
  module Indexing

    module Namespace
      module_function
      def id(obj)
        with_namespace(obj) do
          "#{search_doc_namespace}-#{obj}"
        end
      end

      def doc(hash)
        with_namespace(hash) do
          hash.merge(namespace_term)
        end
      end

      def delete_all_documents_query(site)
        {
          "query" => {
            "term" => {"namespace" => "__ns__#{site}"}
          }
        }
      end

      def delete_query(term)
        with_namespace(term) do
          {
            "bool" =>  {
              "must" => [term, {"term" => namespace_term }]
            }
          }
        end
      end

      def search_query(hash)
        with_namespace(hash) do
          hash.merge("filter" => { "term" => namespace_term })
        end
      end

      def new_es_search_query(hash)
        with_namespace(hash) do
          filter = hash[:query][:bool][:filter]
          if filter.is_a? Array
            filter.push({ term: namespace_term })
          else
            filter[:bool][:must].push({term: namespace_term })
          end
          hash
        end
      end

      def search_result(hash)
        with_namespace(hash) do
          hash['hits']['hits'].each do |hit|
            hit['_id'].gsub!(/^#{search_doc_namespace}-/, '')
          end
          hash
        end
      end

      def new_search_result(hash)
        with_namespace(hash) do
          hash['hits']['hits'].each do |hit|
            hit['_id'].gsub!(/^\w+-#{search_doc_namespace}-/, '')
          end
          hash
        end
      end

      def with_namespace(obj)
        if MingleConfiguration.search_namespace?
          yield
        else
          obj
        end
      end

      def namespace_term
        {"namespace" => search_doc_namespace}
      end

      def search_doc_namespace
        # '__ns__' is prepended to prevent search results returning
        # all documents when searching for words with the app namespace
        "__ns__#{MingleConfiguration.app_namespace}"
      end
    end

    def create_index_with_mappings
      types = ["_default_", "cards", "murmurs", "pages", "dependencies"]
      namespace_mapping = {
        "date_detection" => false,
        "properties" => {
          "namespace" => { "type" => "string", "index" => "not_analyzed" }
        }
      }
      index = {"mappings" => {}}
      types.each do |type|
        mapping = JSON.parse namespace_mapping.to_json # make a deep copy
        mapping["properties"].merge!({
          "depnum" => {"type" => "string"},
          "desired_end_date" => {"type" => "date", "format" => "date_optional_time||date||date_time||date_time_no_millis"},
          "desired_completion_date" => {"type" => "date", "format" => "date_optional_time||date||date_time||date_time_no_millis"},
          "raising_project_id" => {"type" => "long"},
          "raising_card_id" => {"type" => "long"},
          "raising_card_number" => {"type" => "long"},
          "resolving_project_id" => {"type" => "long"}
        }) if type == "dependencies"

        index["mappings"][type] = mapping
      end

      begin
        if ElasticSearch.index_missing?
          exec :post, ElasticSearch.index_path(ElasticSearch.index_name), :body => index.to_json
        else
          types.each do |type|
            exec :put, ElasticSearch.index_path(ElasticSearch.index_name, type, "_mapping"), :body => { type => index["mappings"][type] }.to_json
          end
        end
      rescue ElasticSearch::NetworkError => e
        Kernel.log_error(e, "ElasticSearch server connection refused. Continuing with Mingle.")
      end
    end

    def deindex(ids, index_name, type)
      namespaced_ids = Array(ids).collect do |id|
        Namespace.id(id.to_s)
      end
      bulk_delete_data = namespaced_ids.map { |id| {"delete" => {"_id" => id}}.to_json }.join("\n")
      if MingleConfiguration.installer?
        exec :post, ElasticSearch.index_path(index_name, type, '_bulk'), :body => (bulk_delete_data << "\n")
      else
        aws_es.delete(namespaced_ids, index_name, type)
      end
    rescue => e
      Kernel.log_error(e, "Ignoring error while bulk deindexing")
    end

    def deindex_for_project(project_id, index_name)
      body = {"query" => Namespace.delete_query({"term" => {"project_id" => project_id}})}
      if MingleConfiguration.installer?
        exec(:delete, ElasticSearch.index_path(index_name, "_query"), :body => body.to_json)
      else
        aws_es.delete_by_query(index_name, body)
      end
    rescue => e
      Kernel.log_error(e, "Ignoring error while deleting project index")
    end

    def clean_site_documents(site_name)
      body = Namespace.delete_all_documents_query(site_name)
      if MingleConfiguration.installer?
        exec(:delete, ElasticSearch.index_path(ElasticSearch.index_name, "_query"), :body => body.to_json)
      else
        aws_es.delete_by_query(ElasticSearch.index_name, body)
      end
    rescue => e
      Kernel.log_error(e, "Ignoring error while deleting project index")
    end

    def reindex(id, body, index_name, type)
      namespace_doc = Namespace.doc(body)
      namespace_id = Namespace.id(id)
      if MingleConfiguration.installer?
        exec :put, ElasticSearch.index_path(index_name, type, namespace_id), :body => namespace_doc.to_json
      else
        aws_es.index(namespace_id, namespace_doc, index_name, type)
      end
    end

    def search(size_limit, body, index_name, type)
      if MingleConfiguration.installer?
        Rails.logger.info("Searching from elastic search cluster: #{body}")
        response = exec(:get, ElasticSearch.index_path(index_name, type, '_search'), :query => size_limit, :body => Namespace.search_query(body).to_json)
        Namespace.search_result(response)
      else
        Rails.logger.info("Searching from AWS elastic search service: #{body}")
        response = aws_es.search(index_name, Namespace.new_es_search_query(body))
        Namespace.new_search_result(response)
      end
    end
  end

  extend Indexing

  class << self
    def exec(method, uri_path, data={})
      MingleConfiguration.indexing_log { "exec #{method} => #{uri_path}, #{data.inspect}" }
      request(method, uri_path, data)
    rescue ElasticSearch::DisabledException
      Kernel.logger.debug("ElasticSearch is disabled. Ignoring #{method}: #{uri_path} with data: #{data.inspect}")
    end
  end

end
