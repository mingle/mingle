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
require File.dirname(__FILE__) + '/config/environment'

map '/contextual_help' do
  app = lambda do |env|
    file_path = "#{File.join(Rails.root, 'public', 'contextual_help', env['PATH_INFO'])}.template"
    content = File.read(file_path).gsub(/\{%[^%]*%\}/, '')
    [200, {'Content-Type' => 'text/plain', 'Content-Length' => content.length.to_s}, [content]]
  end
  run app
end

map '/' do
  run ActionController::Dispatcher.new
end
