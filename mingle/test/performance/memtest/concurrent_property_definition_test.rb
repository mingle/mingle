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

require File.dirname(__FILE__) + '/../config/environment'

Project.transaction do
  old = Project.find_by_identifier('concurrent_property_definition')
  old.destroy if old
  User.first_admin.with_current do
    project = Project.create!(:name => 'concurrent_property_definition', :identifier => 'concurrent_property_definition')
  end
end

# need to fork this off as Rails does not support multiple threads
threads = []

# three creaters
threads << Thread.start do
  system("ruby #{File.dirname(__FILE__)}/concurrent_property_definition/create_cards.rb")
end
threads << Thread.start do
  system("ruby #{File.dirname(__FILE__)}/concurrent_property_definition/create_cards.rb")
end
threads << Thread.start do
  system("ruby #{File.dirname(__FILE__)}/concurrent_property_definition/create_cards.rb")
end

# three readers
threads << Thread.start do
  system("ruby #{File.dirname(__FILE__)}/concurrent_property_definition/select_cards.rb")
end
threads << Thread.start do
  system("ruby #{File.dirname(__FILE__)}/concurrent_property_definition/select_cards.rb")
end
threads << Thread.start do
  system("ruby #{File.dirname(__FILE__)}/concurrent_property_definition/select_cards.rb")
end

# three updaters
threads << Thread.start do
  system("ruby #{File.dirname(__FILE__)}/concurrent_property_definition/update_cards.rb")
end
threads << Thread.start do
  system("ruby #{File.dirname(__FILE__)}/concurrent_property_definition/update_cards.rb")
end
threads << Thread.start do
  system("ruby #{File.dirname(__FILE__)}/concurrent_property_definition/update_cards.rb")
end

# two property definers
threads << Thread.start do
  system("ruby #{File.dirname(__FILE__)}/concurrent_property_definition/create_property_definitions.rb")
end
threads << Thread.start do
  system("ruby #{File.dirname(__FILE__)}/concurrent_property_definition/create_property_definitions.rb")
end

threads.each(&:join)
