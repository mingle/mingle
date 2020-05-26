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

require 'rscm/abstract_scm'
require 'rscm/path_converter'
require 'rscm/line_editor'

require 'fileutils'
require 'socket'
require 'pp'
require 'parsedate' unless MingleUpgradeHelper.ruby_1_9?
require 'stringio'

module RSCM
  # RSCM implementation for Perforce.
  #
  # Understands operations against multiple client-workspaces
  # You need the p4/p4d executable on the PATH in order for it to work.
  #
  class Perforce < AbstractSCM
    register self

    include FileUtils

    ann :description => "Depot path", :tip => "The path to the Perforce depot"
    attr_accessor :depotpath, :global_options

    def initialize(repository_root_dir = "")
      @clients = {}
      @depotpath = repository_root_dir
      @global_options = ''
    end

    def create
      P4Daemon.new(@depotpath).start
    end

    def name
      "Perforce"
    end

    def transactional?
      true
    end

    def import(dir, comment)
      with_create_client(dir) do |client|
        client.add_all(list_files)
        client.submit(comment)
      end
    end

    def checkout(checkout_dir, to_identifier = nil, &proc)
      client(checkout_dir).checkout(to_identifier, &proc)
    end

    def add(checkout_dir, relative_filename)
      client(checkout_dir).add(relative_filename)
    end

    def commit(checkout_dir, message, &proc)
      client(checkout_dir).submit(message, &proc)
    end

    def changesets(checkout_dir, from_identifier, to_identifier=Time.infinity)
      client(checkout_dir).changesets(from_identifier, to_identifier)
    end

    def uptodate?(checkout_dir, from_identifier)
      client(checkout_dir).uptodate?
    end

    def edit(file)
      client_containing(file).edit(file)
    end

    def trigger_installed?(trigger_command, trigger_files_checkout_dir)
      p4admin.trigger_installed?(trigger_command)
    end

    def install_trigger(trigger_command, damagecontrol_install_dir)
      p4admin.install_trigger(trigger_command)
    end

    def uninstall_trigger(trigger_command, trigger_files_checkout_dir)
      p4admin.uninstall_trigger(trigger_command)
    end

    private

    def p4admin
      @p4admin ||= P4Admin.new
      @p4admin.global_options=global_options
      @p4admin
    end

    def client_containing(path)
      @clients.values.find {|client| client.contains?(path)}
    end

    def client(rootdir)
      @clients[rootdir] ||= create_client(rootdir)
    end

    def with_create_client(rootdir)
      raise "needs a block" unless block_given?
      rootdir = File.expand_path(rootdir)
      with_working_dir(rootdir) do
        client = create_client(rootdir)
        begin
          yield client
        ensure
          delete_client(client)
        end
      end
    end

    def delete_client(client)
      p4admin.delete_client(client.name)
    end

    def create_client(rootdir)
      rootdir = File.expand_path(rootdir) if rootdir =~ /\.\./
      mkdir_p(rootdir)
      p4admin.create_client(rootdir)
    end

    def list_files
      files = Dir["**/*"].delete_if{|f| File.directory?(f)}
      files.collect{|f| File.expand_path(f)}
    end

    class P4Daemon
      include FileUtils

      def initialize(depotpath)
        @depotpath = depotpath
      end

      def start
        shutdown if running?
        launch
        assert_running
      end

      def assert_running
        raise "p4d did not start properly" if timeout(10) { running? }
      end

      def launch
        fork do
          mkdir_p(@depotpath)
          cd(@depotpath)
          debug "starting p4 server"
          exec("p4d")
        end
        at_exit { shutdown }
      end

      def shutdown
        `p4 -p 1666 admin stop`
      end

      def running?
        !`p4 -p 1666 info`.empty?
      end
    end
  end

  # Understands p4 administrative operations (not specific to a client)
  class P4Admin
    @@counter = 0
    attr_accessor :global_options

    def create_client(rootdir, name = next_name)
      popen("client -i", "w+", clientspec(name, rootdir))
      P4Client.new(name, rootdir)
    end

    def delete_client(name)
      execute("client -d #{name}")
    end

    def trigger_installed?(trigger_command)
      triggers.any? {|line| line =~ /#{trigger_command}/}
    end

    def install_trigger(trigger_command)
      popen("triggers -i", "a+", triggerspec_with(trigger_command))
    end

    def uninstall_trigger(trigger_command)
      popen("triggers -i", "a+", triggerspec_without(trigger_command))
    end

    def triggerspec_with(trigger_command)
      new_trigger = " damagecontrol commit //depot/... \"#{trigger_command}\" "
      triggers + $/ + new_trigger
    end

    def triggerspec_without(trigger_command)
      triggers.reject {|line| line =~ /#{trigger_command}/}.join
    end

    def clientspec(name, rootdir)
      s = StringIO.new
      s.puts "Client: #{name}"
      s.puts "Owner: #{ENV["LOGNAME"]}"
      s.puts "Host: #{ENV["HOSTNAME"]}"
      s.puts "Description: another one"
      s.puts "Root: #{rootdir}"
      s.puts "Options: noallwrite noclobber nocompress unlocked nomodtime normdir"
      s.puts "LineEnd: local"
      s.puts "View: //depot/... //#{name}/..."
      s.string
    end

    def triggers
      execute("triggers -o")
    end

    def popen(cmd, mode, input)
      options = global_options.blank? ? "-p 1666 #{cmd}" : global_options
      IO.popen("p4 #{options}", mode) do |io|
        io.puts(input)
        io.close_write
        io.each_line {|line| debug(line)}
      end
    end

    def execute(cmd)
      options = global_options.blank? ? "-p 1666 #{cmd}" : global_options
      cmd = "p4 #{options} #{cmd}"
      Log.debug "> executing: #{cmd}"
      `#{cmd}`
    end

    def next_name
      "client#{@@counter += 1}"
    end
  end

  # Understands operations against a client-workspace
  class P4Client
    DATE_FORMAT = "%Y/%m/%d:%H:%M:%S"
    STATUS = { "add" => Change::ADDED, "edit" => Change::MODIFIED, "delete" => Change::DELETED }
    PERFORCE_EPOCH = Time.utc(1970, 1, 1, 6, 0, 1)  #perforce doesn't like Time.utc(1970)

    attr_accessor :name, :rootdir, :global_options

    def initialize(name, rootdir)
      @name = name
      @rootdir = rootdir
      @global_options = ''
    end

    def contains?(file)
      file = File.expand_path(file)
      file =~ /^#{@rootdir}/
    end

    def uptodate?
      p4("sync -n").empty?
    end

    def changesets(from_identifier, to_identifier)
      changesets = changelists(from_identifier, to_identifier).collect {|changelist| to_changeset(changelist)}
      ChangeSets.new(changesets)
    end

    def edit(file)
      file = File.expand_path(file)
      p4("edit #{file}")
    end

    def add(relative_path)
      add_file(@rootdir + "/" + relative_path)
    end

    def add_all(files)
      files.each {|file| add_file(file)}
    end

    def submit(comment)
      IO.popen(p4cmd("submit -i"), "w+") do |io|
        io.puts(submitspec(comment))
        io.close_write
        io.each_line {|progress| debug progress}
      end
    end

    def checkout(to_identifier)
      cmd = to_identifier.nil? ? "sync" : "sync //...@#{to_identifier}"
      checked_out_files = []
      p4(cmd).split("\n").collect do |output|
        Log.debug "output: '#{output}'"
        if (output =~ /.* - (added as|updating|deleted as) #{@rootdir}[\/|\\](.*)/)
          path = $2.gsub(/\\/, "/")
          checked_out_files << path
          yield path if block_given?
        end
      end
      checked_out_files
    end

    private

    def add_file(absolute_path)
      absolute_path = PathConverter.filepath_to_nativepath(absolute_path, true)
      p4("add #{absolute_path}")
    end

    def changelists(from_identifier, to_identifier)
      p4changes(from_identifier, to_identifier).collect do |line|
        if line =~ /^Change (\d+) /
          log = p4describe($1)
          P4Changelist.new(log) unless log == ""
        end
      end
    end

    def to_changeset(changelist)
      return nil if changelist.nil? # Ugly, but it seems to be nil some times on windows.
      changes = changelist.files.collect do |filespec|
        change = Change.new(filespec.path, changelist.developer, changelist.message, filespec.revision, changelist.time)
        change.status = STATUS[filespec.status]
        change.previous_revision = filespec.revision - 1
        change
      end
      changeset = ChangeSet.new(changes)
      changeset.revision = changelist.number
      changeset.developer = changelist.developer
      changeset.message = changelist.message
      changeset.time = changelist.time
      changeset
    end

    def p4describe(chnum)
      p4("describe -s #{chnum}")
    end

    def p4changes(from_identifier, to_identifier)
      if from_identifier.nil? || from_identifier.is_a?(Time)
        from_identifier = PERFORCE_EPOCH if from_identifier.nil? || from_identifier < PERFORCE_EPOCH
        to_identifier = Time.infinity if to_identifier.nil?
        from = from_identifier.strftime(DATE_FORMAT)
        to = to_identifier.strftime(DATE_FORMAT)
        p4("changes //...@#{from},#{to}")
      else
        p4("changes //...@#{from_identifier},#{from_identifier}")
      end
    end

    def p4(cmd)
      cmd = "#{p4cmd(cmd)}"
#      puts "> executing: #{cmd}"
      output = `#{cmd}`
      Log.debug output
      output
    end

    def p4cmd(cmd)
      if global_options.blank? #work with defaults
        "p4 -p 1666 -c #{@name} #{cmd}"
      else
        "p4 #{global_options} #{cmd}"
      end
    end

    def submitspec(comment)
      s = StringIO.new
      s.puts "Change: new"
      s.puts "Client: #{@name}"
      s.puts "Description: #{comment.gsub(/\n/, "\n\t")}"
      s.puts "Files: "
      p4("opened").split("\n").each do |line|
        if line =~ /^(.+)#\d+ - (\w+) /
          status, revision = $1, $2
          s.puts "\t#{status}       # #{revision}"
        end
      end
      s.string
    end

    FileSpec = Struct.new(:path, :revision, :status)
  end

end

module Kernel

  #todo: replace with logger
  def debug(msg)
    Log.debug msg
  end

end
