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

require 'httparty'

class ElasticSearch

    include HTTParty
    format :json

    class << self
      def index_path(*path)
        path = [path].flatten.compact.join('/')
        "/#{path}"
      end

      #perform a request to the elasticsearch server
      def request(method, url, options = {})
        request_url = "#{elastic_search_server_url}#{url}"
        options = options.merge(auth_params)
        start = Time.now
        response = self.send(method, request_url, options)
        duration = Time.now - start
        Rails.logger.info "[LONG ELASTICSEARCH REQUEST]: #{duration} ms #{method} #{request_url} #{options.inspect}" if duration > 500
        Rails.logger.debug "elasticsearch request: #{method} #{request_url} #{options.inspect} #{" finished in #{response['took']}ms" if response['took']}"
        validate_response response
        response
      rescue Errno::ECONNREFUSED => e
        raise ElasticSearch::NetworkError.new(e)
      rescue => e
        Rails.logger.error "ElasticSearch response error for #{method}, #{url}, #{options.except(:basic_auth).inspect}"
        Rails.logger.error "ElasticSearch response error  #{e.message} thrown with #{e.backtrace.join("\n")}"
        raise ElasticSearch::ElasticError.new(e)
      end

      def auth_params
        password = System.getProperty("mingle.search.password")
        password.present? ? {:basic_auth => {:username => System.getProperty("mingle.search.user"),
                        :password => password}} : {}
      end

      DEFAULT_PORT = 9200
      DEFAULT_HOST = 'localhost'


      def elastic_search_server_url
        if search_url = System.getProperty("mingle.search.url")
          return search_url unless search_url.blank?
        end

        port = System.getProperty("mingle.search.port") || DEFAULT_PORT
        host = System.getProperty("mingle.search.host") || DEFAULT_HOST
        "http://#{host}:#{port}"
      end

      private
      # all elasticsearch rest calls return a json response when an error occurs.  ex:
      # {error: 'an error occurred' }
      def validate_response(response)
        error = response['error'] || "Error executing request: #{response.inspect}"
        raise ElasticSearch::ElasticError.from_response(error) if response['error'] || ![Net::HTTPOK, Net::HTTPCreated].include?(response.response.class)
      end

    end

end
