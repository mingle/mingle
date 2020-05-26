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

require 'tempfile'
require 'open3'

class OpenStruct
  def parse(str)
    return if str.blank?
    key, value = str.split(' ', 2)
    self.send("#{key.underscore}=", value)
  end
end

class P4

  HEAD = 'now'

  ROOT_PATH = '//'

  PATH_WILDCARDS_REGEX = /(\*|\.\.\.)$/

  FileSpec = Struct.new(:path, :revision, :status)

  class Changelist

    STATUS = { "add" => 'A', "edit" => 'M', "delete" => 'D' }

    attr_reader :number, :developer, :message, :time, :files

    def initialize(log)
      if (log =~ /^Change (\d+) by (.*) on (.*)$/)
        if MingleUpgradeHelper.ruby_1_9?
          @number, @developer, @time = $1.to_i, $2, DateTime.parse($3).to_time
        else
          @number, @developer, @time = $1.to_i, $2, Time.local(*ParseDate.parsedate($3))
        end
      else
        raise "Bad log format: '#{log}'"
      end

      if log =~ /Change (.*)(\n\n|\r\n\r\n)(.*)(\n\n|\r\n\r\n)Affected/m
        @message = $3.strip.gsub(/\n\t/, "\n")
      end

      @files = []
      log.split("\n").each do |line|
        if line =~ /^\.\.\. (.+)#(\d+) (.+)/
          file_path, file_revision, file_status = $1, $2.to_i, STATUS[$3.strip]
          @files << FileSpec.new(file_path, file_revision, file_status)
        end
      end
    end

    def <=>(other)
      @time <=> other.time
    end

    def hash
      [:number, :developer, :message, :time].collect { |attr| self.send(attr).hash }.inject(17) do |res, c|
        res = 37 * res + c
      end
    end

    def eql?(other)
      [:number, :developer, :message, :time].all? { |attr| self.send(attr) == other.send(attr) }
    end

    def ==(other)
      self.eql?(other)
    end
  end

  def self.available?
    system("#{P4CmdConfiguration.configured_p4_cmd} -V")
  end

  def self.to_location(path)
    remove_path_wildcards(path).gsub(/\/$/, '') + '/'
  end

  def self.remove_path_wildcards(path)
    path.gsub(PATH_WILDCARDS_REGEX, '')
  end

  def initialize(global_options)
    @global_options = global_options
  end

  def changelists(paths, from_identifier, to_identifier)
    changes(paths, "#{from_identifier},#{to_identifier}")
  end

  def youngest_changelist(paths, changelist_number=HEAD)
    changes(paths, changelist_number, '-m 1').sort!.reverse!.first
  end

  def youngest_changelist_number(paths, changelist_number=HEAD)
    change_lines = changes_log(paths, changelist_number, '-m 1').split("\n")
    numbers = change_lines.collect { |change_line| change_line =~ /^Change (\d+) /; $1.to_i }
    numbers.max.to_i
  end

  def files(path, changelist_number)
    try_paths = [path]
    unless include_path_wildcards?(path)
      try_paths << escape(path)
      try_paths << File.join(escape(path), '*')
    end
    try_harder(*try_paths) do |try_path|
      clear_descriptive_logs(p4(["-s", "files", "#{try_path}@#{changelist_number}"]))
    end
  end

  #From p4 doc: Use p4 dirs to find the immediate subdirectories of any depot directories provided as arguments. Any directory argument must be provided in depot syntax and must end with the * wildcard. If you use the "..." wildcard, you will receive the wrong results!
  def dirs(path, changelist_number)
    try_harder(File.join(to_location(path), '*'), File.join(escape(to_location(path)), '*')) do |try_path|
      clear_descriptive_logs(p4(["-s", "dirs", "#{try_path}@#{changelist_number}"]))
    end
  end


  def depot?(path, changelist_number=HEAD)
    depot_name = path.gsub(/^\/+/, '').gsub(/\/+$/, '')
    return false if depot_name.include?('\\')
    depots = p4(["depots"]).split("\n")
    depots.any?{|depot| depot.split[1] == depot_name}
  end

  def dir?(path, changelist_number=HEAD)
    return true if path == ROOT_PATH
    path = to_location(path).gsub(/\/$/, '')
    parent_path = path.split('/')[0..-2].join('/')
    return depot?(path, changelist_number) if parent_path ==  '/'
    dirs(parent_path, changelist_number).split("\n").any? do |dir|
      dir.strip == path
    end
  end

  def file(path, changelist_number=HEAD)
    try_harder(path, escape(path)) do |try_path|
      clear_descriptive_logs(p4(["-s", "files", "#{try_path}@#{changelist_number}"]))
    end
  end

  def file?(path, changelist_number=HEAD)
    log = file(path, changelist_number)
    log =~ /^#{path}#/ || log =~ /^#{escape(path)}#/
  end

  #a location should end with '/' and can be used to identify a directory in the repository
  #the path should be a directory
  #so that we can easily to use it for matching sub-dir files
  def to_location(path)
    self.class.to_location(path)
  end

  def file_contents(path, file_revision, output=nil)
    path = escape(path)
    PerforceOutputFile::with_temporary_storage(path, file_revision) do |tmp_file_path|
      p4(print_command(tmp_file_path, path, file_revision))
      File.open(tmp_file_path) do |stream|
        if output
          begin
            while buffer = stream.read(1024) do
              output.write(buffer)
              break if buffer.size < 1024
            end
          rescue TypeError => e
          end
        else
          stream.read
        end
      end
    end
  end

  #only support file specified diff
  def diff2(path, file_revision)
    file_revision = file_revision.to_i
    version = file_revision == 1 ? 1 : file_revision - 1
    path = escape(path)
    p4(["diff2", "-du", "#{path}##{version}", "#{path}##{file_revision}"])
  end

  def fstat(path, changelist_number)
    logs = clear_descriptive_logs(p4(["-s", "fstat", "-Osl", "#{escape(path)}@#{changelist_number}"]))
    state = nil
    logs.split("\n").inject([]) do |memo, line|
      if line.starts_with?("depotFile")
        state = OpenStruct.new
        memo << state
      end
      state.parse(line)
      memo
    end
  end

  def server_running?
    !p4(['info']).empty?
  end

  def escape(path)
    # @  %40
    # #  %23
    # *  %2a
    # %  %25
    path.gsub(/%(?!(25|40|23|2a))/i, '%25').gsub(/@/, '%40').gsub(/#/, '%23').gsub(/\*(?!$)/, '%2A')
  end

  private

  def include_path_wildcards?(path)
    path =~ PATH_WILDCARDS_REGEX
  end

  def try_harder(*args, &block)
    result = nil
    args.uniq.each do |arg|
      result = block.call(*arg)
      unless result.blank?
        break
      end
    end
    result
  end

  def changes(path, range_option, option="")
    changes_log(path, range_option, option).split("\n").collect { |line| to_changelist(line) }.compact.uniq
  end

  def changes_log(paths, range_option, option="")
    paths = paths.split(' ')
    paths = paths.collect{|path|"#{include_path_wildcards?(path) ? path : File.join(escape(path), '...')}@#{range_option}"}
    clear_descriptive_logs(p4(["-s", "changes", "-s", "submitted", "#{option}"] + paths))
  end

  def describe(chnum)
    p4(["describe", "-s", chnum])
  end

  def p4(cmd_array)
    command = p4cmd(cmd_array)
    stdin, stdout, stderr = Open3.popen3(*command)
    result = stdout.read
    error = stderr.read
    PerforceConfiguration.logger.info("Perforce error executing '#{command.join(' ')}': #{error}") unless error.blank?
    result
  end

  def p4cmd(cmd_array)
    options = [P4CmdConfiguration.configured_p4_cmd]
    options << "-P" << @global_options[:password]  unless @global_options[:password].blank?
    options << "-u" << @global_options[:username]  unless @global_options[:username].blank?
    options << "-p" << "#{@global_options[:host]}:#{@global_options[:port]}" unless @global_options[:host].blank? || @global_options[:port].blank?
    options + cmd_array
  end

  def to_changelist(line)
    if line =~ /^Change (\d+) /
      log = describe($1)
      Changelist.new(log) unless log.blank?
    end
  end

  def clear_descriptive_logs(str)
    str.split("\n").delete_if{|line| line !~ /^info/}.collect{|line| line.strip.gsub(/^info\d*: /, '')}.join("\n").strip
  end

  def print_command(tmp_file_path, path, file_revision)
    ["print", "-o" ,tmp_file_path, "#{path}##{file_revision}"]
  end


end
