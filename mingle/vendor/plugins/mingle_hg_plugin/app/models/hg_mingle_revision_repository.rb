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

class HgMingleRevisionRepository
  
  def initialize(project)
    @project = project
  end
  
  def sew_in_most_recent_changeset_data_from_mingle(children)
    mingle_revisions = @project.revisions.find_all_by_identifier(children.map(&:most_recent_changeset_identifier))
    mingle_revisions_by_identifier = {}
    mingle_revisions.each{|mrev| mingle_revisions_by_identifier[mrev.identifier] = mrev}
    children.each do |child|
      most_recent_revision = mingle_revisions_by_identifier[child.most_recent_changeset_identifier]
      if (!most_recent_revision.nil?)
        child.most_recent_committer = most_recent_revision.user
        child.most_recent_commit_time = most_recent_revision.commit_time
        child.most_recent_commit_desc = most_recent_revision.commit_message
      end
    end
  end
  
end
