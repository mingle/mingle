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
require 'rscm/scm/cvs_log_parser'

module RSCM

  # RSCM implementation for CVS.
  #
  # You need a cvs executable on the PATH in order for it to work.
  #
  # NOTE: On Cygwin this has to be the win32 build of cvs and not the Cygwin one.
  class Cvs < AbstractSCM
    register self

    ann :description => "CVSROOT"
    attr_accessor :root

    ann :description => "Module"
    attr_accessor :mod

    ann :description => "Branch"
    attr_accessor :branch

    ann :description => "Password", :tip => "<b>Warning!</b> Password will be shown in cleartext in configuration files."
    attr_accessor :password

    def initialize(root=nil, mod=nil, branch=nil, password=nil)
      @root, @mod, @branch, @password = root, mod, branch, password
    end

    def name
      "CVS"
    end

    def import(dir, message)
      modname = File.basename(dir)
      cvs(dir, "import -m \"#{message}\" #{modname} VENDOR START")
    end

    def add(checkout_dir, relative_filename)
      cvs(checkout_dir, "add #{relative_filename}")
    end

    # The extra simulate parameter is not in accordance with the AbstractSCM API,
    # but it's optional and is only being used from within this class (uptodate? method).
    def checkout(checkout_dir, to_identifier=nil, simulate=false)
      checked_out_files = []
      if(checked_out?(checkout_dir))
        path_regex = /^[U|P] (.*)/
        cvs(checkout_dir, update_command(to_identifier), simulate) do |line|
          if(line =~ path_regex)
            path = $1.chomp
            yield path if block_given?
            checked_out_files << path
          end
        end
      else
        prefix = File.basename(checkout_dir)
        path_regex = /^[U|P] #{prefix}\/(.*)/
        # This is a workaround for the fact that -d . doesn't work - must be an existing sub folder.
        mkdir_p(checkout_dir) unless File.exist?(checkout_dir)
        target_dir = File.basename(checkout_dir)
        run_checkout_command_dir = File.dirname(checkout_dir)
        # -D is sticky, but subsequent updates will reset stickiness with -A
        cvs(run_checkout_command_dir, checkout_command(target_dir, to_identifier), simulate) do |line|
          if(line =~ path_regex)
            path = $1.chomp
            yield path if block_given?
            checked_out_files << path
          end
        end
      end
      checked_out_files
    end

    def checkout_commandline(to_identifier=Time.infinity)
      "cvs checkout #{branch_option} #{revision_option(to_identifier)} #{mod}"
    end

    def update_commandline
      "cvs update #{branch_option} -d -P -A"
    end

    def commit(checkout_dir, message, &proc)
      cvs(checkout_dir, commit_command(message), &proc)
    end

    def uptodate?(checkout_dir, since)
      if(!checked_out?(checkout_dir))
        return false
      end

      # simulate a checkout
      files = checkout(checkout_dir, nil, true)
      files.empty?
    end

    def changesets(checkout_dir, from_identifier, to_identifier=Time.infinity)
      checkout(checkout_dir) unless uptodate?(checkout_dir, nil) # must checkout to get changesets
      parse_log(checkout_dir, changes_command(from_identifier, to_identifier))
    end

    def diff(checkout_dir, change)
      with_working_dir(checkout_dir) do
        opts = case change.status
          when /#{Change::MODIFIED}/; "#{revision_option(change.previous_revision)} #{revision_option(change.revision)}"
          when /#{Change::DELETED}/; "#{revision_option(change.previous_revision)}"
          when /#{Change::ADDED}/; "#{revision_option(Time.epoch)} #{revision_option(change.revision)}"
        end
        # IMPORTANT! CVS NT has a bug in the -N diff option
        # http://www.cvsnt.org/pipermail/cvsnt-bugs/2004-November/000786.html
        cmd = command_line("diff -Nu #{opts} #{change.path}")
        safer_popen(cmd, "r", 1) do |io|
          return(yield(io))
        end
      end
    end

    def apply_label(checkout_dir, label)
      cvs(checkout_dir, "tag -c #{label}")
    end

    def install_trigger(trigger_command, trigger_files_checkout_dir)
      raise "mod can't be null or empty" if (mod.nil? || mod == "")

      root_cvs = create_root_cvs
      root_cvs.checkout(trigger_files_checkout_dir)
      with_working_dir(trigger_files_checkout_dir) do
        trigger_line = "#{mod} #{trigger_command}\n"
        File.open("loginfo", File::WRONLY | File::APPEND) do |file|
          file.puts(trigger_line)
        end
        begin
          commit(trigger_files_checkout_dir, "Installed trigger for CVS module '#{mod}'")
        rescue
          raise "Couldn't commit the trigger back to CVS. Try to manually check out CVSROOT/loginfo, " +
          "add the following line and commit it back:\n\n#{trigger_line}"
        end
      end
    end

    def trigger_installed?(trigger_command, trigger_files_checkout_dir)
      loginfo_line = "#{mod} #{trigger_command}"
      regex = Regexp.new(Regexp.escape(loginfo_line))

      root_cvs = create_root_cvs
      begin
        root_cvs.checkout(trigger_files_checkout_dir)
        loginfo = File.join(trigger_files_checkout_dir, "loginfo")
        return false if !File.exist?(loginfo)

        # returns true if commented out. doesn't modify the file.
        in_local_copy = LineEditor.comment_out(File.new(loginfo), regex, "# ", "")
        # Also verify that loginfo has been committed back to the repo
        entries = File.join(trigger_files_checkout_dir, "CVS", "Entries")
        committed = File.mtime(entries) >= File.mtime(loginfo)

        in_local_copy && committed
      rescue Exception => e
        $stderr.puts(e.message)
        $stderr.puts(e.backtrace.join("\n"))
        false
      end
    end

    def uninstall_trigger(trigger_command, trigger_files_checkout_dir)
      loginfo_line = "#{mod} #{trigger_command}"
      regex = Regexp.new(Regexp.escape(loginfo_line))

      root_cvs = create_root_cvs
      root_cvs.checkout(trigger_files_checkout_dir)
      loginfo_path = File.join(trigger_files_checkout_dir, "loginfo")
      File.comment_out(loginfo_path, regex, "# ")
      with_working_dir(trigger_files_checkout_dir) do
        commit(trigger_files_checkout_dir, "Uninstalled trigger for CVS mod '#{mod}'")
      end
      raise "Couldn't uninstall/commit trigger to loginfo" if trigger_installed?(trigger_command, trigger_files_checkout_dir)
    end

    def create
      raise "Can't create CVS repository for #{root}" unless can_create?
      FileUtils.mkpath(path)
      cvs(path, "init")
    end

    def can_create?
      begin
        local?
      rescue
        false
      end
    end

    def supports_trigger?
      true
    end

    def exists?
      if(local?)
        File.exists?("#{path}/CVSROOT/loginfo")
      else
        # don't know. assume yes.
        true
      end
    end

    def checked_out?(checkout_dir)
      rootcvs = File.expand_path("#{checkout_dir}/CVS/Root")
      File.exists?(rootcvs)
    end

  private

    def cvs(dir, cmd, simulate=false)
      dir = PathConverter.nativepath_to_filepath(dir)
      dir = File.expand_path(dir)
      execed_command_line = command_line(cmd, password, simulate)
      with_working_dir(dir) do
        safer_popen(execed_command_line) do |stdout|
          stdout.each_line do |progress|
            yield progress if block_given?
          end
        end
      end
    end

    def parse_log(checkout_dir, cmd, &proc)
      logged_command_line = command_line(cmd, hidden_password)
      yield logged_command_line if block_given?

      execed_command_line = command_line(cmd, password)
      changesets = nil
      with_working_dir(checkout_dir) do
        safer_popen(execed_command_line) do |stdout|
          parser = CvsLogParser.new(stdout)
          parser.cvspath = path
          parser.cvsmodule = mod
          changesets = parser.parse_changesets
        end
      end
      changesets
    end

    def changes_command(from_identifier, to_identifier)
      # https://www.cvshome.org/docs/manual/cvs-1.11.17/cvs_16.html#SEC144
      # -N => Suppress the header if no revisions are selected.
      "log #{branch_option} -N #{period_option(from_identifier, to_identifier)}"
    end

    def branch_specified?
      branch && branch.strip != ""
    end

    def branch_option
      branch_specified? ? "-r#{branch}" : ""
    end

    def update_command(to_identifier)
      "update #{branch_option} -d -P -A #{revision_option(to_identifier)}"
    end

    def checkout_command(target_dir, to_identifier)
      "checkout #{branch_option} -d #{target_dir} #{mod} #{revision_option(to_identifier)}"
    end

    def hidden_password
      if(password && password != "")
        "********"
      else
        ""
      end
    end

    def period_option(from_identifier, to_identifier)
      if(from_identifier.nil? && to_identifier.nil?)
        ""
      else
        "-d\"#{cvsdate(from_identifier)}<=#{cvsdate(to_identifier)}\" "
      end
    end

    def cvsdate(time)
      return "" unless time
      # CVS wants all dates as UTC.
      time.utc.strftime("%Y-%m-%d %H:%M:%S UTC")
    end

    def root_with_password(password)
      result = nil
      if local?
        result = root
      elsif password && password != ""
        protocol, user, host, path = parse_cvs_root
        result = ":#{protocol}:#{user}:#{password}@#{host}:#{path}"
      else
        result = root
      end
    end

    def command_line(cmd, password=nil, simulate=false)
      cvs_options = simulate ? "-n" : ""
      "cvs -f \"-d#{root_with_password(password)}\" #{cvs_options} -q #{cmd}"
    end

    def create_root_cvs
      Cvs.new(self.root, "CVSROOT", nil, self.password)
    end

    def revision_option(identifier)
      option = nil
      if(identifier.is_a?(Time))
        option = "-D\"#{cvsdate(identifier)}\""
      elsif(identifier.is_a?(String))
        option = "-r#{identifier}"
      else
        ""
      end
    end

    def commit_command(message)
      "commit -m \"#{message}\""
    end

    def local?
      protocol == "local"
    end

    def path
      parse_cvs_root[3]
    end

    def protocol
      parse_cvs_root[0]
    end

    # parses the root into tokens
    # [protocol, user, host, path]
    #
    def parse_cvs_root
      md = case
        when root =~ /^:local:/   then /^:(local):(.*)/.match(root)
        when root =~ /^:ext:/     then /^:(ext):(.*)@(.*):(.*)/.match(root)
        when root =~ /^:pserver:/ then /^:(pserver):(.*)@(.*):(.*)/.match(root)
      end
      result = case
        when root =~ /^:local:/   then [md[1], nil, nil, md[2]]
        when root =~ /^:ext:/     then md[1..4]
        when root =~ /^:pserver:/ then md[1..4]
        else ["local", nil, nil, root]
      end
    end
  end
end
