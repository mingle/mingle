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

module ProfileServer
  class HttpWithSigning
    def initialize(access_key_id, access_secret_key, skip_ssl_verify=false)
      @access_key_id = access_key_id
      @access_secret_key = access_secret_key
      @skip_ssl_verify = skip_ssl_verify
    end

    def post(url, options={})
      process(Net::HTTP::Post, url, options[:headers], options[:body])
    end

    def put(url, options={})
      process(Net::HTTP::Put, url, options[:headers], options[:body])
    end

    def delete(url, options={})
      process(Net::HTTP::Delete, url, options[:headers])
    end

    def get(url, options={})
      process(Net::HTTP::Get, url, options[:headers])
    end

    private

    def process(request_class, url, headers, body=nil)
      uri = URI.parse(url)
      http = Net::HTTP.new(uri.host, uri.port)
      if uri.scheme == 'https'
        http.use_ssl = true

        Kernel.logger.info "*************************** skip_ssl_verify: #{@skip_ssl_verify.inspect}"
        http.verify_mode = OpenSSL::SSL::VERIFY_NONE if @skip_ssl_verify
      end

      request = request_class.new(uri.request_uri)
      request.body = body if body

      if headers
        headers.each do |key, value|
          request[key] = value
        end
      end

      ApiAuth.sign!(request, @access_key_id, @access_secret_key)

      response = http.request(request)
      error_message = "error[#{request_class.name}][#{url}][#{response.code}]: #{response.body}"
      raise NetworkError.new(error_message) if response.code.to_i > 501
      raise error_message if response.code.to_i >= 300

      to_canonical_response(response)
    rescue Errno::ECONNREFUSED => e
      raise NetworkError.new(e.message)
    end

    def to_canonical_response(response)
      headers = {}
      response.each_header {|key, value|  headers[key] = value }
      [response.code.to_i, response.body, headers]
    end

  end
end
