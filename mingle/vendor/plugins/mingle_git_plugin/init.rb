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

# Copyright (c) 2011 ThoughtWorks Inc. (http://thoughtworks.com)
# Licenced under the Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0.txt)

def load_all_files_in(dir)
  Dir[File.join(File.dirname(__FILE__), dir, '**', '*.rb')].each do |f|
    require f
  end
end

begin
  ['app/controllers', 'app/models', 'config'].each do |dir|
    load_all_files_in(dir)
  end
  
  MinglePlugins::Source.register(GitConfiguration)
rescue Exception => e
  ActiveRecord::Base.logger.error "Unable to register GitConfiguration. Root cause: #{e}"
end
  
if defined?(RAILS_ENV)
  GitConfiguration.class_eval do
    include ::API::XMLSerializer
    serializes_as :id, :marked_for_deletion, :project, :repository_path, :username
  end
end
