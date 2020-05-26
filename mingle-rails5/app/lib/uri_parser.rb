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

# Namespaced under Mingle module because the OAuth provider plugin
# has its own version of URIParser

module Mingle

  module URIParser

    module_function
    def self.parse(url)
      java.net.URL.new(url)
    rescue java.net.MalformedURLException => e
      raise ::URI::InvalidURIError.new('URL is not valid')
    end

  end

  class java::net::URL
    alias :scheme :protocol
    def port
      p = getPort
      p == -1 ? getDefaultPort : p
    end
  end

end
