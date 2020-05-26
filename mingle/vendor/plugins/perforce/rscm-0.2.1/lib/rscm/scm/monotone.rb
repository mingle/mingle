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

require 'fileutils'
require 'rscm'

module RSCM
  class Monotone < AbstractSCM
    register self

    ann :description => "Database file"
    attr_accessor :db_file

    ann :description => "Branch"
    attr_accessor :branch

    ann :description => "Key"
    attr_accessor :key

    ann :description => "Passphrase"
    attr_accessor :passphrase

    ann :description => "Keys file"
    attr_accessor :keys_file

    def initialize(server="", port="5253", db_file="MT.db", branch="", key="", passphrase="", keys_file="")
      @db_file = File.expand_path(db_file)
      @branch = branch
      @key = key
      @passphrase = passphrase
      @keys_file = keys_file
    end

    def name
      "Monotone"
    end

    def add(checkout_dir, relative_filename)
      with_working_dir(checkout_dir) do
        monotone("add #{relative_filename}")
      end
    end

    def create
      FileUtils.mkdir_p(File.dirname(@db_file))
      monotone("db init")
      monotone("read") do |io|
        io.write(File.open(@keys_file).read)
        io.close_write
      end
    end

    def transactional?
      true
    end

    def import(dir, message)
      dir = File.expand_path(dir)

      # post 0.17, this can be "cd dir && cmd add ."

      files = Dir["#{dir}/*"]
      relative_paths_to_add = to_relative(dir, files)

      with_working_dir(dir) do
        monotone("add #{relative_paths_to_add.join(' ')}")
        monotone("commit '#{message}'", @branch, @key) do |io|
          io.puts(@passphrase)
          io.close_write
          io.read
        end
      end
    end

    def checked_out?(checkout_dir)
      File.exists?("#{checkout_dir}/MT")
    end

    def uptodate?(checkout_dir, from_identifier)
      if (!checked_out?(checkout_dir))
        false
      else
        lr = local_revision(checkout_dir)
        hr = head_revision(checkout_dir)
        lr == hr
      end
    end

    def local_revision(checkout_dir)
      local_revision = nil
      rev_file = File.expand_path("#{checkout_dir}/MT/revision")
      local_revision = File.open(rev_file).read.strip
      local_revision
    end
    
    def head_revision(checkout_dir)
      # FIXME: this will grab last head if heads are not merged.
      head_revision = nil
      monotone("heads", @branch) do |stdout|
        stdout.each_line do |line|
          next if (line =~ /^monotone:/)
          head_revision = line.split(" ")[0]
        end
      end
      head_revision
    end

    def changesets(checkout_dir, from_identifier, to_identifier=Time.infinity)
      from_identifier = Time.epoch if from_identifier.nil?
      to_identifier = Time.infinity if to_identifier.nil?
      with_working_dir(checkout_dir) do
        monotone("log", @branch, @key) do |stdout|
          MonotoneLogParser.new.parse_changesets(stdout, from_identifier, to_identifier)
        end
      end
    end

    def commit(checkout_dir, message)
      with_working_dir(checkout_dir) do
        monotone("commit '#{message}'", @branch, @key) do |io|
          io.puts(@passphrase)
          io.close_write
          io.read
        end
      end
    end

  protected

    # Checks out silently. Called by superclass' checkout.
    def checkout_silent(checkout_dir, to_identifier)
      checkout_dir = PathConverter.filepath_to_nativepath(checkout_dir, false)
      if checked_out?(checkout_dir)
        with_working_dir(checkout_dir) do
          monotone("update")
        end
      else
        monotone("checkout #{checkout_dir}", @branch, @key) do |stdout|
          stdout.each_line do |line|
            # TODO: checkout prints nothing to stdout - may be fixed in a future monotone.
            # When/if it happens we may want to do a kosher implementation of checkout
            # to get yields as checkouts happen.
            yield line if block_given?
          end
        end
      end
    end

    # Administrative files that should be ignored when counting files.
    def ignore_paths
      return [/MT/, /\.mt-attrs/]
    end

  private
  
    def monotone(monotone_cmd, branch=nil, key=nil)
      branch_opt = branch ? "--branch=\"#{branch}\"" : ""
      key_opt = key ? "--key=\"#{key}\"" : ""
      cmd = "monotone --db=\"#{@db_file}\" #{branch_opt} #{key_opt} #{monotone_cmd}"
      safer_popen(cmd, "r+") do |io|
        if(block_given?)
          return(yield(io))
        else
          # just read stdout so we can exit
          io.read
        end
      end
    end
  
  end
end
