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
  class RequestSigner
    BLACKLIST_HEADERS = ['cache-control', 'content-length', 'expect', 'max-forwards', 'pragma', 'te', 'if-match',
                         'if-none-match', 'if-modified-since', 'if-unmodified-since', 'if-range', 'accept', 'authorization',
                         'proxy-authorization', 'from', 'referer', 'user-agent']

    def initialize(credentials, service_name, region)
      @service_name = service_name
      @credentials = credentials
      @region = region
    end

    def sign(req)
      datetime = Time.now.utc.strftime('%Y%m%dT%H%M%SZ')
      uri = URI(req.path)
      body_digest = req['X-Amz-Content-Sha256'] || hexdigest(req.body || '')
      req['X-Amz-Date'] = datetime
      req['Host'] = host(uri)
      req['X-Amz-Security-Token'] = @credentials.session_token if @credentials.session_token
      req['X-Amz-Content-Sha256'] ||= body_digest
      req['Authorization'] = authorization(req, datetime, body_digest)
      req
    end

    private

    def authorization(request, datetime, body_digest)
      parts = []
      parts << "AWS4-HMAC-SHA256 Credential=#{credential(datetime)}"
      parts << "SignedHeaders=#{signed_headers(request)}"
      parts << "Signature=#{signature(request, datetime, body_digest)}"
      parts.join(', ')
    end

    def credential(datetime)
      "#{@credentials.access_key_id}/#{credential_scope(datetime)}"
    end

    def signature(request, datetime, body_digest)
      k_secret = @credentials.secret_access_key
      k_date = hmac('AWS4' + k_secret, datetime[0, 8])
      k_region = hmac(k_date, @region)
      k_service = hmac(k_region, @service_name)
      k_credentials = hmac(k_service, 'aws4_request')
      hexhmac(k_credentials, string_to_sign(request, datetime, body_digest))
    end

    def string_to_sign(request, datetime, body_digest)
      parts = []
      parts << 'AWS4-HMAC-SHA256'
      parts << datetime
      parts << credential_scope(datetime)
      parts << hexdigest(canonical_request(request, body_digest))
      parts.join("\n")
    end

    def credential_scope(datetime)
      parts = []
      parts << datetime[0, 8]
      parts << @region
      parts << @service_name
      parts << 'aws4_request'
      parts.join('/')
    end

    def canonical_request(request, body_digest)
      uri = URI(request.path)
      [
          request.method,
          path(uri),
          normalized_querystring(uri.query || ''),
          canonical_headers(request) + "\n",
          signed_headers(request),
          body_digest
      ].join("\n")
    end

    def path(uri)
      path = uri.path == '' ? '/' : uri.path
      if @service_name == 's3'
        path
      else
        uri_path_escape(path)
      end
    end

    def uri_escape(string)
      CGI.escape(string.encode('UTF-8')).gsub('+', '%20').gsub('%7E', '~')
    end

    def uri_path_escape(path)
      path.gsub(/[^\/]+/) { |part| uri_escape(part) }
    end

    def normalized_querystring(querystring)
      params = querystring.split('&')
      params = params.map { |p| p.match(/=/) ? p : p + '=' }
      params = params.each.with_index.sort do |a, b|
        a, a_offset = a
        a_name = a.split('=')[0]
        b, b_offset = b
        b_name = b.split('=')[0]
        if a_name == b_name
          a_offset <=> b_offset
        else
          a_name <=> b_name
        end
      end.map(&:first).join('&')
    end

    def signed_headers(request)
      signed_headers = []
      request.each_key do |header_key|
        header_key = header_key.downcase
        signed_headers << header_key unless BLACKLIST_HEADERS.include?(header_key)
      end
      signed_headers.sort.join(';')
    end

    def canonical_headers(request)
      headers = []
      request.each_header do |k, v|
        k = k.downcase
        headers << [k, v] unless BLACKLIST_HEADERS.include?(k)
      end
      headers = headers.sort_by(&:first)
      headers.map { |k, v| "#{k}:#{canonical_header_value(v.to_s)}" }.join("\n")
    end

    def canonical_header_value(value)
      value.match(/^".*"$/) ? value : value.gsub(/\s+/, ' ').strip
    end

    def host(uri)
      if standard_port?(uri)
        uri.host
      else
        "#{uri.host}:#{uri.port}"
      end
    end

    def standard_port?(uri)
      (uri.scheme == 'http' && uri.port == 80) ||
          (uri.scheme == 'https' && uri.port == 443)
    end

    def hexdigest(value)
      if File === value || Tempfile === value
        OpenSSL::Digest::SHA256.file(value).hexdigest
      elsif value.respond_to?(:read)
        sha256 = OpenSSL::Digest::SHA256.new
        update_in_chunks(sha256, value)
        sha256.hexdigest
      else
        OpenSSL::Digest::SHA256.hexdigest(value)
      end
    end

    def update_in_chunks(digest, io)
      while (chunk = io.read(CHUNK_SIZE))
        digest.update(chunk)
      end
      io.rewind
    end

    def hmac(key, value)
      OpenSSL::HMAC.digest(OpenSSL::Digest.new('sha256'), key, value)
    end

    def hexhmac(key, value)
      OpenSSL::HMAC.hexdigest(OpenSSL::Digest.new('sha256'), key, value)
    end
  end
end
