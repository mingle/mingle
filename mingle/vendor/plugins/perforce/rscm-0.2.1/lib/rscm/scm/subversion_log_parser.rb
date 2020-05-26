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

require 'rscm/parser'
require 'rscm/changes'

module RSCM

  class SubversionLogParser
    def initialize(io, path, checkout_dir)
      @io = io
      @changeset_parser = SubversionLogEntryParser.new(path, checkout_dir)
    end
    
    def parse_changesets(&line_proc)
      # skip over the first ------
      @changeset_parser.parse(@io, true, &line_proc)
      changesets = ChangeSets.new
      while(!@io.eof?)
        changeset = @changeset_parser.parse(@io, &line_proc)
        if(changeset)
          changesets.add(changeset)
        end
      end
      changesets
    end
  end
  
  class SubversionLogEntryParser < Parser

    def initialize(path, checkout_dir)
      super(/^------------------------------------------------------------------------/)
      @path = path ? path : ""
      @checkout_dir = checkout_dir
    end

    def parse(io, skip_line_parsing=false, &line_proc)
      # We have to trim off the last newline - it's not meant to be part of the message
      changeset = super
      changeset.message = changeset.message[0..-2] if changeset
      changeset
    end

  protected

    def parse_line(line)
      if(@changeset.nil?)
        parse_header(line)
      elsif(line.strip == "")
        @parse_state = :parse_message
      elsif(line =~ /Changed paths/)
        @parse_state = :parse_changes
      elsif(@parse_state == :parse_changes)
        change = parse_change(line)
        if change
          # This unless won't work for new directories or if changesets are computed before checkout (which it usually is!)
          fullpath = "#{@checkout_dir}/#{change.path}"
          @changeset << change unless File.directory?(fullpath)
        end
      elsif(@parse_state == :parse_message)
        @changeset.message << line.chomp << "\n"
      end
    end

    def next_result
      result = @changeset
      @changeset = nil
      result
    end

  private
  
    STATES = {"M" => Change::MODIFIED, "A" => Change::ADDED, "D" => Change::DELETED} unless defined? STATES

    def parse_header(line)
      @changeset = ChangeSet.new
      @changeset.message = ""
      revision, developer, time, the_rest = line.split("|")
      @changeset.revision = revision.strip[1..-1].to_i unless revision.nil?
      @changeset.developer = developer.strip unless developer.nil?
      @changeset.time = parse_time(time.strip) unless time.nil?
    end
    
    def parse_change(line)
      change = Change.new
      path_from_root = nil
      if(line =~ /^   [M|A|D|R] ([^\s]+) \(from (.*)\)/)
        path_from_root = $1
        change.status = Change::MOVED
      elsif(line =~ /^   ([M|A|D|R]) (.+)$/)
        status = $1
        path_from_root = $2
        change.status = STATES[status]
      else
        raise "could not parse change line: '#{line}'"
      end

      path_from_root.gsub!(/\\/, "/")
      return nil unless path_from_root =~ /^\/#{@path}/
      if(@path.length+1 == path_from_root.length)
        change.path = path_from_root[@path.length+1..-1]
      else
        change.path = path_from_root[@path.length+2..-1]
      end
      change.revision = @changeset.revision
      # http://jira.codehaus.org/browse/DC-204
      change.previous_revision = change.revision.to_i - 1;
      change
    end

    def parse_time(svn_time)
      if(svn_time =~ /(.*)-(.*)-(.*) (.*):(.*):(.*) (\+|\-)([0-9]*) (.*)/)
        year  = $1.to_i
        month = $2.to_i
        day   = $3.to_i
        hour  = $4.to_i
        min   = $5.to_i
        sec   = $6.to_i
        time = Time.utc(year, month, day, hour, min, sec)
        
        time = adjust_offset(time, $7, $8)
      else
        raise "unexpected time format"
      end
    end

    def adjust_offset(time, sign, offset)
      hour_offset = offset[0..1].to_i
      min_offset = offset[2..3].to_i
      sec_offset = 3600*hour_offset + 60*min_offset
      sec_offset = -sec_offset if(sign == "+")
      time += sec_offset
      time
    end
    
  end

end
