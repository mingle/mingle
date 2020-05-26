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

# HgRepository is the object by which Mingle interacts with a Mercurial repository.
#
# Required by Mingle: empty?, revision, next_revisions, node
class HgRepository
      
  PER_FILE_PATCH_TRUNCATION_THRESHOLD = 1001  # see task #61 to fix off by 1 issue
  
  def initialize(hg_client, source_browser)
    @hg_client = hg_client
    @source_browser = source_browser
  end
  
   
  # *returns*: whether repository has any revisions
  def empty?
    @hg_client.repository_empty?
  end
  
  # *returns*: the HgChangeset identified by changeset_identifier.  will work for rev number, 
  # short identifier, long identifier. raises error if changset does not exist.
  def changeset(changeset_identifier)
    construct_changeset(*@hg_client.log_for_rev(changeset_identifier))
  end
  alias :revision :changeset

  # *returns*: the next _limit_ changesets, starting with the changeset beyond _skip_up_to_,
  # which is the last Revision that Mingle has cached. _skip_up_to_ is an actual Revision
  # object from the Mingle model.
  def next_changesets(skip_up_to, limit)
    return [] if empty?    
    tip_number, tip_identifier, the_rest = @hg_client.log_for_rev('tip')
    return [] if skip_up_to && skip_up_to.number.to_i == tip_number.to_i
    from = skip_up_to.nil? ? 0 : skip_up_to.number + 1
    to = [from + limit - 1, tip_number.to_i].min
    log_entries = @hg_client.log_for_revs(from, to)
    log_entries.map{|log_entry| construct_changeset(*log_entry)}
  end
  alias :next_revisions :next_changesets
  
  # *returns* the HgFileNode or HgDirNode for _path_ for consumption by the source browser pages
  # todo: need to co-ordinate with Mingle guys to remove dependency on Repository::NoSuchRevisionError
  def node(path, changeset_identifier = 'tip')
    changeset_identifier = 'tip' if ['tip', 'head'].any?{|tip_id| tip_id == changeset_identifier.to_s.downcase}
        
    begin
      proper_changeset = changeset(changeset_identifier)
    rescue StandardError => e 
      ActiveRecord::Base.logger.warn( %{
        HgRepository unable to find changeset #{changeset_identifier}: #{e}.
        This could be OK if the #{changeset_identifier} is indeed a bogus changeset.
      })     
      raise Repository::NoSuchRevisionError.new
    end
    
    begin
      if changeset_identifier == 'tip'
        @source_browser.tip_node(path, proper_changeset.number, proper_changeset.identifier)
      else
        @source_browser.node(path, proper_changeset.number, proper_changeset.identifier)
      end
    rescue StandardError => e
      ActiveRecord::Base.logger.warn(%{
        HgRepository unable to build node for changeset #{changeset_identifier}. 
        This could be OK if the #{changeset_identifier} is indeed a bogus changeset.
        Otherwise, the changeset is likely still being cached by Mingle.
        This is quite likely in the case of the initial caching of a large Hg repository.
      })
      raise Repository::NoSuchRevisionError.new
    end
  end
  
  #:nodoc:
  def git_patch_for(changeset, truncation_threshold = PER_FILE_PATCH_TRUNCATION_THRESHOLD)
    git_patch = HgGitPatch.new(changeset.identifier, self, truncation_threshold)
    @hg_client.git_patch_for(changeset.identifier, git_patch)
    git_patch
  end
  
  #:nodoc:
  def files_in(changeset_identifier)
    @hg_client.files_in(changeset_identifier)
  end
    
  #:nodoc:
  def dels_in(changeset_identifier)
    @hg_client.dels_in(changeset_identifier)
  end

  #:nodoc:
  def binary?(path, changeset_identifier)
    @hg_client.binary?(path, changeset_identifier)
  end
    
  #:nodoc:
  def pull
    return if @pulled
    @hg_client.pull
    @pulled = true
  end 
  
  #:nodoc:
  def ensure_local_clone
    @hg_client.ensure_local_clone
  end   
    
  #:nodoc:
  def construct_changeset(number, changeset_identifier, commit_time, committer, message)
    HgChangeset.new({
      :revision_number => number.to_i,
      :changeset_identifier => changeset_identifier,
      :person => committer,
      :time => Time.at(commit_time.to_i),
      :desc => message
    }, self)
  end 
    
end

