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

require 'time'
require 'fileutils'
require 'open3'
require 'timeout'

class GitClient
  
  DEFAULT_EXECUTION_TIMEOUT = 3600 #1 HOUR

  cattr_accessor :logging_enabled
  attr_accessor :execution_timeout
  attr_reader :clone_path, :file_index

  @@logging_enabled = (ENV["ENABLE_GIT_CLIENT_LOGGING"] && ENV["ENABLE_GIT_CLIENT_LOGGING"].downcase == 'true')
  
  def initialize(remote_master_info, clone_path)
    @remote_master_info = remote_master_info
    @clone_path = clone_path
    if @remote_master_info && @remote_master_info.path && @remote_master_info.path =~ /\//
      @clone_path += '/' + @remote_master_info.path.split('/').last.gsub(/.git$/,'') + '.git'
    end
    @clone_path = File.expand_path(@clone_path) if @clone_path
    @file_index = GitFileIndex.new(self)
  end
  
  def pull
    git("fetch -q \"#{@remote_master_info.path}\" refs/heads/master:refs/heads/master")
    @file_index.update
  end

  def ensure_local_clone
    git("clone --bare \"#{@remote_master_info.path}\" \"#{@clone_path}\"") unless File.file?(@clone_path + '/HEAD')
  end

  def repository_empty?
    Dir["#{@clone_path}/objects/*/*"].empty?
  end

  def log_for_rev(rev)
    rev = sanitize(rev)
    git_log("log --date=rfc #{rev} -1").first
  end

  def log_for_revs(from, to, limit=nil, &exclude_block)
    from = sanitize(from)
    to = sanitize(to)
    window = from.blank? ? to : "#{from}..#{to}"
    git_log("log --date=rfc --reverse #{window}", limit, &exclude_block)
  end

  def git_patch_for(commit_id, git_patch)
    commit_id = sanitize(commit_id)
    git("log -1 -p #{commit_id} -M") do |stdout|
      
      keep_globbing = true
      stdout.each_line do |line|
        (keep_globbing = false) if line.starts_with?('diff')
        line.chomp!
        git_patch.add_line(line) unless (keep_globbing || line.starts_with?('similarity index '))

      end
    end

    git_patch.done_adding_lines
  end

  def binary?(path, commit_id)
    mime_type = GitClientMimeTypes.lookup_for_file(path)
    !mime_type.start_with?('text/')
  end

  def cat(path, object_id, io)
    git("cat-file blob #{object_id}") do |stdout|
      io.write(stdout.read)
    end
  end

  def dir?(path, commit_id)
    return true if root_path?(path)
    tree = ls_tree(path, commit_id)
    (tree.size == 1) && (tree[path][:type] == :tree)
  end

  def ls_tree(path, commit_id, children = false)
    commit_id = sanitize(commit_id)
    tree = {}
    path += '/' if children && !root_path?(path)

    command = "ls-tree #{commit_id}"
    command << " \"#{path}\"" unless path.blank?
    git(command) do |stdout|
      stdout.each_line do |line|
        mode, type, object_id, path = line.split(/\s+/)
        type = type.to_sym
        tree[path] = {:type => type, :object_id => object_id}
      end
    end

    load_latest_commit_id(tree, commit_id)
  end


  def git(command, &block)

    git_prefix = "git --git-dir=\"#{@clone_path}\" --no-pager"

    if Array === command
      command = command.collect{ |cmd| "#{git_prefix}  #{cmd}" }.join(" && ")
    else
      command = "#{git_prefix}  #{command}"
    end

    execute(command, &block)
  end

  def execute(command, &block)
    ::Timeout.timeout(execution_timeout || DEFAULT_EXECUTION_TIMEOUT) do
      execute_without_timeout(command, &block)
    end
  end

  def execute_without_timeout(command, &block)
    sanitized_command = sanitize_logging(command)
    start = Time.now
    puts "Executing command:\n#{sanitized_command}" if GitClient.logging_enabled

    error = nil

    begin
      Open3.popen3(command) do |stdin, stdout, stderr|
        stdin.close

        yield(stdout) if block_given?

        stdout.readlines if !stdout.closed? && !block_given?
        stdout.close 

        error = stderr.readlines
      end
    ensure
      if GitClient.logging_enabled
        time_in_ms = ((Time.now - start)*1000).to_i
        puts "*** execute using #{time_in_ms}ms"
      end
    end

    sanitized_error = error.map{|e| sanitize_logging(e)}

    if error.any?
      puts
      puts "*** warning: the git client exited with an error:"
      puts sanitized_error
    end

    if error.any? { |e| e.strip.start_with?("fatal:") }
      raise StandardError.new("Could not execute \"#{sanitized_command}\". The error was:\n#{sanitized_error}" )
    end
  end
  
  private

  
  def root_path?(path)
    path == '.' || path.blank?
  end
  
  def git_log(command, limit=nil, &exclude_block)
    raise "Repository is empty!" if repository_empty?
    
    result = []

    git(command) do |stdout|
      log_entry = {}
      stdout.each_line do |line|
        line.chomp!
        if line.starts_with?('commit')
          return strip_desc(result) if limit && result.size == limit
          log_entry = {}
          log_entry[:commit_id] = line.sub(/commit /, '')
          log_entry[:description] = ''
          # the next line is a hack for tests.
          next if block_given? && exclude_block.call(log_entry)
          result << log_entry 
        elsif line.starts_with?('Author:')
          log_entry[:author] = line.sub(/Author: /, '')
        elsif line.starts_with?('Date:')
          log_entry[:time] = Time.rfc2822(line.sub(/Date:   /, ''))
        else
          log_entry[:description] << line[4..-1] + "\n" unless line.empty?
        end
      end
    end

    strip_desc(result)
  end
  
  def strip_desc(log_entries)
    log_entries.each{ |entry| entry[:description].chomp! }
  end
  
  def sanitize(commit_id_ish)
    return unless commit_id_ish
    commit_id_ish = commit_id_ish.downcase
    commit_id_ish == 'head' ? 'HEAD' : commit_id_ish
  end
  
  def load_latest_commit_id(tree, commit_id)
    commit_id = sanitize(commit_id)
    paths = tree.keys
    @file_index.last_commit_id(paths, commit_id).each_with_index do |path_commit_id, i|
      tree[paths[i]][:last_commit_id] = path_commit_id
    end
    
    tree
  end
  
  private
  
  def sanitize_logging(text)
    text.gsub(@remote_master_info.path, @remote_master_info.log_safe_path)
  end
end
