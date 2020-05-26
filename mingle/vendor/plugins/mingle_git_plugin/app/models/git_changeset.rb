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
# Licenced under the Apache License, Version 2.0 (http://www.apache.org/licenses/LICENSE-2.0.txt)

# describes a git changeset
class GitChangeset

  attr_reader :commit_id
  attr_reader :description
  attr_reader :author
  attr_reader :time
  attr_accessor :number

  def initialize(attributes, repository)
    @repository = repository
    attributes.each do |k, v|
      instance_variable_set("@#{k}", v)
    end
  end
  
  def changes
    return @__changes if @__changes
    changeset_index = 0
    @__changes = @repository.git_patch_for(self).changes.map do |git_change|
      changeset_index += 1
      GitChange.new(git_change, changeset_index)
    end
    
    @__changes
  end
  
  alias :changed_paths :changes
  alias :identifier :commit_id
  alias :message :description
  alias :version_control_user :author
end
