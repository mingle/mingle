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

require 'ostruct'

class TfsscmRepository
  def initialize(tfs) @tfs = tfs end

  def revision(revision)
    Revision.new(@tfs.changesets(revision-1, 1).first)
  end

  def next_revisions(skip_up_to, limit)
    ask_for(skip_up_to || first, limit).map { |c| Revision.new(c) }
  end

  private
  def ask_for(from, limit)
    @tfs.changesets(Integer(from.identifier), limit)
  end

  def first() OpenStruct.new(:identifier=>'0') end

  class Revision
    def initialize(changeset) @changeset = changeset end

    def identifier
      @changeset[:id]
    end
    alias :number :identifier

    def message
      @changeset[:comment]
    end

    def version_control_user
      @changeset[:committer]
    end

    def time
      @changeset[:date]
    end

    def changed_paths
      @changeset[:changes].map { |c| Change.new(c) }
    end
  end

  class Change
    def initialize(change) @change = change end

    def path
      @change[:path]
    end

    def path_components
      path.split '/'
    end

    def file?
      @change[:item_type] == 'file'
    end

    # Diff and source code display has not yet been implemented. We
    # pretend that all files are binary, so that Mingle will not
    # display any links to diffs or source.
    def binary?
      true
    end

    def action() convert_change_type[:label] end
    def action_class() convert_change_type[:class] end
    def deleted?() convert_change_type[:deleted?] end
    def modification?() convert_change_type[:modification?] end

    def html_diff
      # Not yet implemented.
    end

    private
    def convert_change_type
      edit? && rename?          and return renamed_modifed
      delete? && source_rename? and return renamed
      delete?                   and return deleted
      rename?                   and return renamed
      add?                      and return added
      edit?                     and return modified
      undelete?                 and return added
      branch? && merge?         and return added
                                           unknown
    end

    def rename?() change_include?('rename') end
    def add?() change_include?('add') end
    def delete?() change_include?('delete') end
    def edit?() change_include?('edit') end
    def undelete?() change_include?('undelete') end
    def source_rename?() change_include?('source-rename') end
    def branch?() change_include?('branch') end
    def merge?() change_include?('merge') end

    def added()           {:label=>'A',  :class=>'added',            :deleted? => false, :modification? => false} end
    def deleted()         {:label=>'D',  :class=>'deleted',          :deleted? => true,  :modification? => false} end
    def modified()        {:label=>'M',  :class=>'modified',         :deleted? => false, :modification? => true} end
    def renamed()         {:label=>'R',  :class=>'renamed',          :deleted? => false, :modification? => false} end
    def renamed_modifed() {:label=>'RM', :class=>'renamed-modified', :deleted? => false, :modification? => true} end
    def unknown()         {:label=>'',   :class=>'',                 :deleted? => false, :modification? => false} end

    def change_include? type
      @change[:change_type].include?(type)
    end
  end
end
