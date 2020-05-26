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

require 'rexml/document'
if MingleUpgradeHelper.ruby_1_9?
  require 'digest'
else
  require 'md5'
end

require File.expand_path(File.join(File.dirname(__FILE__), 'hg_java_env'))

# HgClient makes it easier to invoke the hg cmd line client
class HgClient

  def initialize(java_hg_client)
    @java_hg_client = java_hg_client
  end

  def repository_empty?
    @java_hg_client.repository_empty?
  end

  def log_for_rev(rev)
    log_for_revs(rev, rev).first
  end

  def log_for_revs(from, to)
    begin
      @java_hg_client.log_for_revs(from.to_s, to.to_s).map do |log_entry|
        [
          log_entry.rev_number,
          log_entry.identifier,
          log_entry.epoch_time,
          log_entry.committer,
          log_entry.description
        ]
      end
    rescue NativeException => e
      raise e.cause.message
    end
  end

  def git_patch_for(rev, git_patch)
    @java_hg_client.git_patch_for(rev, GitPatchLineHandler.new(git_patch))
    git_patch.done_adding_lines
  end

  def binary?(path, rev)
    @java_hg_client.binary?(path, rev)
  end

  def pull
    @java_hg_client.pull
  end

  def ensure_local_clone
    @java_hg_client.ensure_local_clone
  end

end

class GitPatchLineHandler
  include com.thoughtworks.studios.mingle.hg.cmdline::LineHandler

  def initialize(git_patch)
    @git_patch = git_patch
  end

  def handleLine(line)
    @git_patch.add_line(line)
  end

end
