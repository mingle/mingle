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

class GitSourceBrowser
  
  def initialize(git_client)
    @git_client = git_client
  end

  def node(path, commit_id)
    node_class = @git_client.dir?(path, commit_id) ? GitDirNode : GitFileNode
    node_class.new(path, commit_id, @git_client)
  end
 
  class GitNode

    attr_reader :path, :commit_id, :last_commit_id, :git_client

    alias :display_path :path

    def initialize(path, commit_id, git_client, git_object_id=nil, last_commit_id=nil)
      @path = path.gsub(/\/$/, '')
      @commit_id = commit_id
      @git_client = git_client
      @git_object_id = git_object_id
      @last_commit_id = last_commit_id
    end

    def git_object_id
      @git_object_id ||= @git_client.ls_tree(path, commit_id)[path][:object_id]
    end

    def name
      path.split('/').last
    end

    def path_components
      path.split('/')
    end

    def most_recent_committer
      nil
    end

    def most_recent_commit_time
      nil
    end

    def most_recent_commit_desc
      nil
    end

    def most_recent_changeset_identifier
      @last_commit_id
    end

    def parent_path_components
      path_components[0..-2]
    end

    def parent_display_path
      parent_path_components.join('/')
    end

  end

  class GitDirNode < GitNode

    def children
      git_client.ls_tree(path, commit_id, true).collect do |child_path, desc|
        node_class = desc[:type] == :tree ? GitDirNode : GitFileNode
        node_class.new(child_path, commit_id, git_client, desc[:object_id], desc[:last_commit_id])
      end
    end

    def dir?
      true
    end

    def root_node?
      path.empty?
    end

  end

  class GitFileNode < GitNode

    def file_contents(io)
      @git_client.cat(path, git_object_id, io)
    end

    def dir?
      false
    end

    def binary?
      @git_client.binary?(path, commit_id)
    end

  end
end

