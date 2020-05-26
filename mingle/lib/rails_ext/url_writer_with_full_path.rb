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

module UrlWriterWithFullPath
  def url_for(options)
    return options if options.is_a?(String)
    options.delete(:only_path)
    default_options = defined?(default_url_options) ? self.default_url_options : self.class.default_url_options
    options = default_options.merge(options)
    url = ''
    url << (options.delete(:protocol) || 'http')
    url << '://'
    raise "Missing host to link to! Please provide :host parameter or set default_url_options[:host]" unless options[:host]
    url << options.delete(:host)
    url << ":#{options.delete(:port)}" if options.key?(:port)
    url << CONTEXT_PATH
    url << ActionController::Routing::Routes.generate(options, {})
    url
  end

  def default_url_options
    MingleConfiguration.site_url_as_url_options
  end

end
