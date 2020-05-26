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

module Aws
  class HttpClient
    def initialize(base_url, service_name, region)
      @base_url = URI.parse base_url
      @service_name = service_name
      @region = region
    end

    class AWSRequestException < Exception
    end

    def perform_request(method, path, params, body)
      request = signed_request(method, path, params, body)
      response = SignedHttpResponse.new(client.request(request))
      # Dont raise exception if response is valid or is a 404 (used to check if index exists in client)
      unless response.status.to_s.match(/([2]\d{2})|(404)$/)
        raise AWSRequestException.new "Error while requesting AWS: #{response.body}"
      end
      response
    end

    private
    def signed_request(method, path, params={}, body)
      request_url = URI.parse("#{@base_url.to_s}/#{path}")
      request_url.query = params.to_query
      request = Net::HTTP.const_get(method.downcase.camelize).new(request_url.to_s)
      request.body = body
      request['Content-type'] = 'application/json'
      Aws::RequestSigner.new(Aws::Credentials.new, @service_name, @region).sign(request)
    end

    def client
      client = Net::HTTP.new(@base_url.host, @base_url.port)
      client.use_ssl = @base_url.scheme == 'https'
      client
    end
  end
end
