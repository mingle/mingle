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

require 'rscm'
require 'time'
require 'stringio'

module RSCM

  class MonotoneLogParser
  
    def parse_changesets(io, from_identifier=Time.epoch, to_identifier=Time.infinity)
      # skip first separator
      io.readline
      
      changesets = ChangeSets.new
      changeset_string = ""
      
      # hash of path => [array of revisions]
      path_revisions = {}
      io.each_line do |line|
        if(line =~ /-----------------------------------------------------------------/)
          changeset = parse_changeset(StringIO.new(changeset_string), path_revisions)
          changesets.add(changeset)
          changeset_string = ""
        else
          changeset_string << line
        end
      end
      changeset = parse_changeset(StringIO.new(changeset_string), path_revisions)
      if((from_identifier <= changeset.time) && (changeset.time <= to_identifier))
        changesets.add(changeset)
      end

      # set the previous revisions. most recent is at index 0.
      changesets.each do |changeset|
        changeset.each do |change|
          current_index = path_revisions[change.path].index(change.revision)
          change.previous_revision = path_revisions[change.path][current_index + 1]
        end
      end
      changesets
    end

    def parse_changeset(changeset_io, path_revisions)
      changeset = ChangeSet.new
      state = nil
      changeset_io.each_line do |line|
        if(line =~ /^Revision: (.*)$/ && changeset.revision.nil?)
          changeset.revision = $1
        elsif(line =~ /^Author: (.*)$/ && changeset.developer.nil?)
          changeset.developer = $1
        elsif(line =~ /^Date: (.*)$/ && changeset.time.nil?)
          changeset.time = Time.utc(
            $1[0..3].to_i,
            $1[5..6].to_i,
            $1[8..9].to_i,
            $1[11..12].to_i,
            $1[14..15].to_i,
            $1[17..18].to_i
          )
        elsif(line =~ /^ChangeLog:$/ && changeset.message.nil?)
          state = :message
        elsif(state == :message && changeset.message.nil?)
          changeset.message = ""
        elsif(state == :message && changeset.message)
          changeset.message << line
        elsif(line =~ /^Added files:$/)
          state = :added
        elsif(state == :added)
          add_changes(changeset, line, Change::ADDED, path_revisions)
        elsif(line =~ /^Modified files:$/)
          state = :modified
        elsif(state == :modified)
          add_changes(changeset, line, Change::MODIFIED, path_revisions)
        end
      end
      changeset.message.chomp!
      changeset
    end
    
  private

    def add_changes(changeset, line, state, path_revisions)
      paths = line.split(" ")
      paths.each do |path|
        changeset << Change.new(path, state, changeset.developer, nil, changeset.revision, changeset.time)

        # now record path revisions so we can keep track of previous rev for each path
        # doesn't work for moved files, and have no idea how to make it work either.
        path_revisions[path] ||= [] 
        path_revisions[path] << changeset.revision
      end
      
    end
  end

end
