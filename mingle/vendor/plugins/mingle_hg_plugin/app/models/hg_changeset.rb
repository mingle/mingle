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

# HgChangeset represents a log entry for a single Hg changeset. Beyond the basic
# changeset attributes such as identifier and person, HgChangeset has a changes
# collection that contains a fair bit of detail about each path included in the changeset.
#
# HgChangeset attributes and methods are named according to Mercurial conventions. Mingle's requirements 
# are met by the  identifier, number, message, commit_message, version_control_user, and changed_paths aliases.
class HgChangeset
  
  # *returns*: the revision number, valid only in the local hg clone
  attr_reader :revision_number
  # *returns*: the global changeset identifier
  attr_reader :changeset_identifier
  # *returns*: the person portion of the changeset author
  attr_reader :person
  # *returns*: the time at which the changeset was committed
  attr_reader :time
  # *returns*: the commit message that describes this changeset
  attr_reader :desc
    
  # construct changeset from a hash of attribute values
  def initialize(attributes_map, repository)
    @repository = repository
    attributes_map.each do |k, v|
      instance_variable_set("@#{k}", v)
    end
  end

  # *returns*: an array of HgChange, one for each path included in the
  # changeset, each containing detail required to render Mingle's Revision 'show'
  # page as well as to populate the source browser cache
  def changes
    changeset_index = 0
    @repository.git_patch_for(self).changes.map do |git_change| 
      changeset_index += 1
      HgChange.new(git_change, changeset_index)
    end
  end
  
  # *returns*: the changeset with a rev number of (number - 1); nil if rev number is 0
  def previous
    @previous ||= (number == 0 ? nil : @repository.changeset(number - 1))
  end
  
  # need to this to populate source browser, since changes blows up with a Python OOM error
  # on gigantic changesets.  this is a workaround for a Mercurial issue.  
  def deleted_files
    @repository.dels_in(identifier)
  end
  
  # need to this to populate source browser, since changes blows up with a Python OOM error
  # on gigantic changesets.  this is a workaround for a Mercurial issue.
  def files
    @repository.files_in(identifier)
  end
  
  def to_s
    "HgChangeset[#{{:revision_number => revision_number, 
      :changeset_identifier => changeset_identifier, 
      :person => person, :time => time, :desc => desc}.inspect}]"
  end
  
  class << self
    def short_identifier(identifier)
      identifier[0...12]
    end
  end
  
  alias :identifier :changeset_identifier
  alias :number :revision_number
  alias :message :desc
  alias :version_control_user :person
  alias :changed_paths :changes

end
