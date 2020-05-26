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

# Copyright 2010 ThoughtWorks, Inc. Licensed under the Apache License, Version 2.0.

# HgGitPatch parses a git-style patch file in order to provide changeset details.
# The git style of patch is used in order to capture renames.
class HgGitPatch
    
  def initialize(changeset_identifier, repository, truncation_threshold = nil)
    @changeset_identifier = changeset_identifier
    @repository = repository
    @changes = []
    @current_change_lines = []
    @truncation_threshold = truncation_threshold
  end

  def changes
    @changes
  end
  
  def add_line(line)
    if (line =~ /^diff/ && @current_change_lines.size > 0)  
      add_current_change
    end
    
    if @truncation_threshold && @current_change_lines.size == @truncation_threshold
      @current_change_truncated = true
    end
    
    if @truncation_threshold.nil? || @current_change_lines.size < @truncation_threshold
      @current_change_lines << line
    end
  end

  def done_adding_lines
    add_current_change
  end
  
  def add_current_change
    #some repositories in the wild have empty changesets, so we only add if we have change lines
    if @current_change_lines.size > 1
      @changes << HgGitChange::Factory.construct(
        @changeset_identifier, 
        @current_change_lines,
        @repository, 
        @current_change_truncated
      )
    end
    @current_change_truncated = false
    @current_change_lines = []
  end
    
end
