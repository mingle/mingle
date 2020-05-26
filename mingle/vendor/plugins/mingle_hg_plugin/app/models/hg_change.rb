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

# HgChange provides the detail on a single file change within an HgChangeset.
#
# Required by Mingle: file?, path, path_components, action, 
# action_class, binary?, modification?, html_diff
class HgChange
  
  # construct an HgChange from an HgGitChange. changeset_index is the index
  # of this change within the changeset and is used in diff styling
  def initialize(git_change, changeset_index)
    @git_change = git_change
    @changeset_index = changeset_index
  end

  # required by mingle
  # *returns*: whether change is a file. always true for mercurial
  def file?
    true
  end

  # required by mingle
  # *returns*: the path of the file change, relative to the repository root
  def path
    @git_change.path
  end
  
  # *returns*: the old path of the file if change is a rename; nil if not a rename
  def renamed_from_path
    @git_change.renamed_from_path
  end
  
  # required by mingle
  def path_components
    @path_components ||= path.split('/')
  end
  
  # required by mingle
  # *returns*: the type of change as single-letter representation for use in mingle feed rendering.
  def action
    @git_change.change_type.map{|ct| ct.to_s[0..0].upcase}.join
  end

  # required by mingle
  # *returns*: the type of change as a css classname for use in revision show page.
  def action_class
    # todo (med) shouldn't we move this logic into mingle??
    # must combine to single class since it's driving a bg image
    @git_change.change_type.join('-') 
  end

  # required by mingle
  # *returns*: whether this file has binary content
  def binary?
    @git_change.binary?
  end

  # required by mingle
  # *returns*: whether this change was a modification
  def modification?
    @git_change.change_type.include?(:modified)
  end
  
  # required by mingle
  # *returns*: whether this change was a file deletion 
  def deleted?
    @git_change.change_type.include?(:deleted)
  end
  
  # required by mingle
  # *returns*: whether this change was a rename
  def renamed?
    @git_change.change_type.include?(:renamed)
  end
  
  # required by mingle
  # *returns*: html snippet containing a diff of this change
  def html_diff
    HgHtmlDiff.new(@git_change, @changeset_index).content
  end
  
end
