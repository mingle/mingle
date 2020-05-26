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

# HgGitChange parses an individual file segement of a git-style patch.
# The git style of patch is used in order to capture renames.
class HgGitChange
  
  class Factory

    class << self
      def construct(changeset_identifier, change_lines, repository, truncated)
        factory = new(change_lines[0..4], changeset_identifier, repository)
        
        # right now, mingle will not attempt to display an html diff if a file is binary
        # of if the change type is not modification, so we'll use those attributes to 
        # determine which type of change to construct.  this seems a bit fragile.
        if !factory.binary? && factory.modify?
          HgGitChange::Diffable.new(factory.path, change_lines, factory.change_type, factory.renamed_from_path, truncated)
        else
          HgGitChange::NotDiffable.new(factory.path, factory.binary?, factory.change_type, factory.renamed_from_path)
        end    
      end
    end  
    
    def initialize(lines, changeset_identifier, repository)
      @lines = lines
      @changeset_identifier = changeset_identifier
      @repository = repository
    end  
    
    def path
      if rename?
        @lines[2] =~ /(^rename\sto\s)(.*$)/
        $2
      elsif copy?
        @lines[2] =~ /(^copy\sto\s)(.*$)/
        $2
      else
        a_and_b_paths = @lines[0][11..-1]
        a_and_b_paths[2..(a_and_b_paths.size-3)/2].to_s
      end
    end
    
    def renamed_from_path
      if rename?
        @lines[1] =~ /(^rename\sfrom\s)(.*$)/
        $2
      else
        nil
      end
    end

    def add?
      @lines[1] =~ /^new\sfile/ || copy?
    end

    def delete?
      @lines[1] =~ /^deleted\sfile/
    end

    def modify?
      !add? && !delete? && ((a_line && b_line) || binary_patch?)
    end
    
    def copy?
      @lines[2] =~ /^copy\sto/
    end

    def rename?
      @lines[2] =~ /^rename\sto/
    end

    def binary?
      return @binary if defined?(@binary)
      @binary = if delete?
        @lines[2] =~ /^Binary\sfile/
      elsif rename? && !modify?
        # no diff content, so we need to go back to the repository to check ....
        @repository.binary?(path, @changeset_identifier)
      elsif add? || delete? || modify?
        binary_patch?
      else
        true
      end
    end

    def change_type
      @change_type ||= returning [] do |result|
        result << :added if add?
        result << :deleted if delete?
        result << :renamed if rename?
        result << :modified if modify?
      end
    end  

    def binary_patch?
      @lines.any?{|line| line =~ /^GIT\sbinary\spatch/}
    end
  
    def a_line
      @lines.find{|line| line =~ /^\-\-\-/}
    end

    def b_line
      @lines.find{|line| line =~ /^\+\+\+/}
    end
  end  
  
  class Diffable
    attr_accessor :path, :lines, :change_type, :renamed_from_path
    
    def initialize(path, lines, change_type, renamed_from_path, truncated)
      @path = path
      @lines = lines
      @change_type = change_type
      @renamed_from_path = renamed_from_path
      @truncated = truncated
    end      
    
    def binary?
      false
    end
    
    def truncated?
      @truncated
    end
  end
  
  # NotDiffable exists so that we do not hold change lines in memory
  # if we're never going to render a diff.  This is to avoid memory spikes
  # while caching large changesets, such as initial imports.  lines and truncated?
  # are not implemented here as we're not expecting them to be called (see inline comment
  # in construct method above).
  class NotDiffable
    attr_accessor :path, :change_type, :renamed_from_path
    
    def initialize(path, is_binary, change_type, renamed_from_path)
      @path = path
      @is_binary = is_binary
      @change_type = change_type
      @renamed_from_path = renamed_from_path
    end      
    
    def binary?
      @is_binary
    end
    
  end

end
