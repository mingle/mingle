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

# Copyright (c) 2010 ThoughtWorks Inc. (http://thoughtworks.com)
# Licenced under the MIT License (http://www.opensource.org/licenses/mit-license.php)

module Oauth2
  module Provider
    module Configuration
      def self.def_properties(*names)
        names.each do |name|
          class_eval(<<-EOS, __FILE__, __LINE__)
            @@__#{name} = nil
            def #{name}
              @@__#{name}.respond_to?(:call) ? @@__#{name}.call : @@__#{name}
            end

            def #{name}=(value_or_proc)
              @@__#{name} = value_or_proc
            end
            module_function :#{name}, :#{name}=
          EOS

          self.send(:module_function, name, "#{name}=")
        end
      end

      def_properties :ssl_base_url

      def self.ssl_base_url_as_url_options
        result = {:only_path => false}
        return result if ssl_base_url.blank?
        uri = URIParser.parse(ssl_base_url)
        raise "SSL base URL must be https" unless uri.scheme == 'https'
        result.merge!(:protocol => uri.scheme, :host => uri.host, :port => uri.port)
        result.delete(:port) if (uri.port == uri.default_port || uri.port == -1)
        result
      end
    end

  end
end
