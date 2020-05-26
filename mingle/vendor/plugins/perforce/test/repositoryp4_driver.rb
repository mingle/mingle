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

require 'rscm'
require 'fileutils'

class Repositoryp4Driver
  include FileUtils

  attr_reader :name

  def initialize(name)
    @name = name.gsub(/\W/, '_')
    rm_rf(tmp_files_dir)
    rm_rf(repos_dir)
    rm_rf(wc_dir)
  end

  def tmp_files_dir
    File.expand_path(RailsTmpDir.file_path('perforce'))
  end

  def client_name
    'client1'
  end

  def depot_name
    '//depot/...'
  end

  def create
    @perforce = RSCM::Perforce.new(repos_dir)
    @perforce.global_options = "-u ice_user -H localhost -p localhost:1666"
    @perforce.create
  end

  def teardown
    @perforce.shutdown
    P4CmdConfiguration.destroy
  end

  def import(dir, comment="Initial import")
    @perforce.import(dir, comment)
  end

  def checkout
    @perforce.checkout(wc_dir)
  end

  def repos_dir
    @repos_dir ||= RailsTmpDir::Repositoryp4Driver.repos(@name).pathname
  end

  def wc_dir
    @wc_dir ||= RailsTmpDir::Repositoryp4Driver.repos(@name).pathname
  end

  def checkout_dir
    wc_dir
  end

  def delete_file(file_name)
    @perforce.delete(checkout_dir, file_name)
  end

  def add_or_edit_file(relative_filename, content)
    existed = false
    absolute_path = File.expand_path(File.join(checkout_dir, relative_filename))
    FileUtils.mkpath(File.dirname(absolute_path))
    if File.exist?(absolute_path)
      edit_file(relative_filename, content)
    else
      add_file(relative_filename, content)
    end
  end

  def add_or_edit_and_commit_file(relative_filename, content)
    existed = add_or_edit_file(relative_filename, content)
    message = existed ? "editing" : "adding"
    commit("#{message} #{relative_filename}")
  end

  def unless_initialized
    yield
  end

  def add_file(file_name, content)
    file = File.expand_path(File.join(checkout_dir, file_name))
    File.open(file, "w+") do |io|
      io.write(content)
    end
    @perforce.add(checkout_dir, file_name)
  end

  def edit_file(file_name, content)
    file = File.expand_path(File.join(checkout_dir, file_name))
    @perforce.edit(file)
    File.open(file, "w") do |io|
      io.write(content)
    end
  end

  def append_to_file(file_name, content)
    file = File.expand_path(File.join(checkout_dir, file_name))
    if File.exists?(file)
      @perforce.edit(file)
      File.open(file, "a+") do |io|
        io.write("\n" << content)
      end
    else
      add_file(file_name, content)
    end
  end

  def commit(message)
    sleep(1)
    @perforce.commit(checkout_dir, message)
  end

  def create_changelist
    @perforce.create_changelist(checkout_dir)
  end

end

module RSCM

  class P4Client
    def add_file(absolute_path)
      absolute_path = PathConverter.filepath_to_nativepath(absolute_path, true)
      p4("add -f #{absolute_path}")
    end

    def delete(file_name)
      p4("delete #{File.join(@rootdir, file_name)}")
    end

    def create_changelist
      popen("change -i", "w+", changespec)
    end

    def changespec
      s = StringIO.new
      s.puts "Change: new"
      s.puts "Client: #{@name}"
      s.puts "User: ice_user"
      s.puts "Status: new"
      s.puts "Description: new changelist"
      s.string
    end

    def popen(cmd, mode, input)
      tmp_file = nil
      Tempfile.open("p4_driver") do |file|
	tmp_file = file
        file.write(input)
        file.close
        debug(%x[p4 #{global_options} #{cmd} < #{file.path}])
      end
    ensure
      FileUtils.rm_f(tmp_file.path) if tmp_file
    end

    def submit(comment)
      popen("submit -i", "w+", submitspec(comment))
    end
    #removed puts output code
    def checkout(to_identifier)
      cmd = to_identifier.nil? ? "sync" : "sync //...@#{to_identifier}"
      checked_out_files = []
      p4(cmd).split("\n").collect do |output|
        if(output =~ /.* - (added as|updating|deleted as) #{@rootdir}[\/|\\](.*)/)
          path = $2.gsub(/\\/, "/")
          checked_out_files << path
          yield path if block_given?
        end
      end
      checked_out_files
    end
  end

  class Perforce
    def add(checkout_dir, relative_filename)
      client(checkout_dir).add(relative_filename.gsub(/ /, "\\ "))
    end

    def create_changelist(checkout_dir)
      client(checkout_dir).create_changelist
    end
    def delete(checkout_dir, filename)
      client(checkout_dir).delete(filename)
    end

    def create
      P4Daemon.new(@depotpath).start
    end

    def shutdown
      P4Daemon.new(@depotpath).shutdown
    end

    class P4Daemon
      def launch
        mkdir_p(@depotpath)
        cd(@depotpath)
        debug "starting p4 server"
        shutdown rescue nil
        t = Thread.new do
          system("p4d 1>/dev/null")
        end
        t.wakeup rescue nil until running?
        at_exit { shutdown }
      end

      def assert_running
        raise "p4d did not start properly" unless running?
      end

      def shutdown
        `p4 -p 1666 admin stop 2>/dev/null`
      end

      def running?
        !`p4 -p 1666 info 2>/dev/null`.empty?
      end
    end
  end

  class P4Admin
    def create_client(rootdir, name = next_name)
      popen("client -i", "w+", clientspec(name, rootdir))
      client = P4Client.new(name, rootdir)
      client.global_options = global_options + ' -c ' + name
      client
    end

    def clientspec(name, rootdir)
      s = StringIO.new
      s.puts "Client: #{name}"
      s.puts "Owner: ice_user"
      s.puts "Host: localhost"
      s.puts "Description: another one"
      s.puts "Root: #{rootdir}"
      s.puts "Options: noallwrite noclobber nocompress unlocked nomodtime normdir"
      s.puts "LineEnd: local"
      s.puts "View: //depot/... //#{name}/..."

      rootdir = File.expand_path(rootdir) if rootdir=~ /\.\./
      FileUtils.mkdir_p(rootdir)
      s.string
    end

    def popen(cmd, mode, input)
      file_to_cleanup = nil
      Tempfile.open("p4_driver") do |file|
 	file_to_cleanup = file
        file.write(input)
        file.close
        %x[p4 #{global_options} #{cmd} < #{file.path}]
      end
    ensure
      FileUtils.rm_f(file_to_cleanup.path) if file_to_cleanup
    end

    def execute(cmd)
      cmd = "p4 #{global_options} #{cmd}"
      `#{cmd}`
    end
  end
end
