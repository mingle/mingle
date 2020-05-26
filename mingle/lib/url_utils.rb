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

require 'uri_parser'

module UrlUtils
  def url_as_url_options(url)
    result = {:only_path => false}
    return result if url.blank?
    mingle_uri = Mingle::URIParser.parse(url)
    result.merge!(:protocol => mingle_uri.scheme, :host => mingle_uri.host, :port => mingle_uri.port)
    result.delete(:port) if (mingle_uri.port == mingle_uri.default_port || mingle_uri.port == -1)
    result
  end

  def prepend_domain_in_url(url, prefix)
    u = URI.parse(url)
    u.host = "#{prefix}.#{u.host}"
    u.to_s
  end
  # options supported:
  # :allowed_protocols => list of protocols it support, e.g. ['http', 'https']
  # :disallow_localhost => whether disallow use localhost as host name
  #
  # returns array of errors, if errors is empty means url is valid
  #
  # note: because behaviors of Mingle::URIParser in MRI and JRuby is quite different,
  # so formats this validaiton accept are quite different. MRI URI.parse is dumb,
  # it can accept most URIs you throw at it.

  def validate_url(url, options={})
    begin
      uri = Mingle::URIParser.parse(url)
    rescue => e
      return ['Invalid URL']
    end

    if allowed_protocols = options[:allowed_protocols]
      return ["Invalid protocol: #{uri.scheme}. Only #{allowed_protocols.join(', ')} allowed."] unless allowed_protocols.include?(uri.scheme)
    end

    if options[:disallow_localhost]
      return ["localhost is not permitted. Please use an externally resolvable hostname."] if uri.host =~ /localhost/ || uri.host =~ /127.0.0.[0-9]{1,3}/
    end

    []
  end

end
