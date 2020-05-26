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

require 'pstore'

class GitFileIndex
  attr_reader :commits, :files

  def initialize(git_client)
    @git_client = git_client
  end

  def last_commit_id(pathes, before_commit_id=nil)
    load_from_disk

    before_commit_index =  @commits.index(before_commit_id) || (@commits.size - 1)
    pathes.collect do |path|
      index = commit_list_for(path).reverse.detect { |i| i <= before_commit_index }
      index && @commits[index]
    end
  end

  def update
    load_from_disk
    need_update = false
    @git_client.git("log --pretty=oneline --name-only --reverse #{update_window}") do |stdout|
      current_commit = nil
      current_commit_index = @commits.size - 1

      stdout.each_line do |line|
        if current_commit = GitUtils.extract_leading_rev_hash(line)
          current_commit_index += 1
          @commits.push(current_commit)
          need_update = true
        else
          file_name = line.chomp
          tree = ""
          File.dirname(file_name).split('/').each do |part|
            next if part == '.'
            tree += part
            commit_list_for(tree).push(current_commit_index)
            tree += '/'
          end

          commit_list_for(file_name).push(current_commit_index)
        end
      end
    end

    save_to_disk if need_update
  end

  def clear
    FileUtils.rm_rf(pstore_file)
  end

  private

  def pstore
    @pstore ||= PStore.new(pstore_file)
  end

  def pstore_file
    File.join(@git_client.clone_path, "file-index.pstore")
  end

  def update_window
    @commits.empty? ? "HEAD" : "#{commits.last}..HEAD"
  end

  def commit_list_for(path)
    @files[path] ||= []
  end

  def save_to_disk
    pstore.transaction do
      pstore[:commits] = @commits
      pstore[:files] = @files
    end
  end

  def load_from_disk
    pstore.transaction(true) do
      @commits = pstore[:commits] || []
      @files = pstore[:files] || {}
    end
  end
end
