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

# Copyright 2010 ThoughtWorks, Inc.  All rights reserved.

if RUBY_PLATFORM =~ /java/
#<snippet name="registration">
['app', 'lib', 'config'].each do |dir| 
  Dir[File.join(File.dirname(__FILE__), dir, '**', '*.rb')].each do |file| 
    require File.expand_path(file)
  end
end

begin
  require File.expand_path(File.join(File.dirname(__FILE__), 'app/models/hg_configuration'))
  MinglePlugins::Source.register(HgConfiguration)
rescue Exception => e
  ActiveRecord::Base.logger.error "Unable to register HgConfiguration. Root cause: #{e}"
end
#</snippet>

#<snippet name="xml_serialization">
  # use Mingle's XML serialization library when the plugin is deployed to a Mingle instance
  if defined?(RAILS_ENV)
    HgConfiguration.class_eval do
      include ::API::XMLSerializer
      serializes_as :id, :marked_for_deletion, :project, :repository_path, :username
    end
  end
#</snippet>
end
