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

require 'erb'
require 'tempfile'
require 'build/transport'

module Mingle
  class Cluster

    class SCError < StandardError
      def initialize(error_code, message)
        @error_code = error_code
        super(message)
      end

      def service_not_been_started_error?
        @error_code == 1062
      end
    end
    
    class ExecError < StandardError
      def initialize(error_code, message)
        @error_code = error_code
        super(message)
      end

      def file_missing?
        @error_code == 9
      end
    end
    
    class ExecReceipt
      def initialize(&block)
        yield self if block_given?
      end

      def block_till_finished(tolerant)
        return unless @finish_condition
        puts "waiting for \"#{@desc}\"" if @desc
        Timeout::timeout(tolerant) do
          while !@finish_condition.call
            sleep 2
          end
        end
        puts "\"#{@desc}\" is done" if @desc
      end

      def finish_on(&condition)
        @finish_condition = Proc.new(&condition)
      end
      
      def desc(text)
        @desc = text
      end
    end
    
    module WSH
      def self.exec(host, command)
        puts "[#{host}]$> #{command}"
        out = script("exec.vbs", host, command)
        if out =~ /Process created: (\d+)/
          ExecReceipt.new do |r|
            r.desc("#{command} on #{host}")
            r.finish_on { pid_not_exists($1.strip.to_i, host) }
          end
        else
          raise ExecError.new($?.exitstatus, "cannot execute command #{command} on #{host}, output is: \n #{out}")
        end
      end
      
      private
      
      def self.pid_not_exists(pid, host)
        !pids(host).include?(pid)
      end
      
      def self.pids(host)
        script("ps.vbs", host).split.collect(&:to_i).reject{|pid| pid == 0}
      end
      
      def self.script(script, *args)
        arg_line = args.collect { |arg| '"' + arg + '"'}.join(" ")
        `cscript //Nologo script\\#{script} #{arg_line}`
      end
    end
    
    
    module Utils
      def file_join(left, right)
        left + '\\' + right
      end
      
      def to_unc(host, local_path)
        path = local_path.gsub(/([a-z]):/i, '\1$' )
        "\\\\#{@host}\\#{path}"
      end
    end
    
    
    class Node
      include Utils
      
      attr_reader :host
      
      def initialize(host, type, home_dir)
        @host = host
        @home_dir = home_dir
        @type = type
      end
      
      def stop_service(service)
        puts "Stoping service #{@host} #{service}"
        sc "stop #{service}"
      rescue SCError => e
        if e.service_not_been_started_error?
          puts "#{service} on #{@host} is not started"
        else
          raise
        end
      end

      def stop_mingle_service
        mingle_services.each do |service|
         stop_service(service)
        end
      end
      
      def uninstall_mingle
        exec("#{install_dir}\\uninstall.exe -q")
      rescue Mingle::Cluster::ExecError => e
        if e.file_missing? 
          puts "[WARN] cannot find uninstall.exe under #{@host}: #{install_dir}, maybe it already been uninstalled?"
        else
          raise
        end
      end
      
      def copy_installer(remote_installer_file)
        rcopy remote_installer_file, local_installer
      end
      
      def install_mingle
        exec "#{local_installer} -q -dir #{install_dir}"
      end
      
      def configure
        rmkdir(config_dir) 
        rcopy render_file("Mingle.vmoptions").path, file_join(install_dir, 'Mingle.vmoptions')
        rcopy render_file("mingle.properties").path, file_join(config_dir, 'mingle.properties')
        rcopy render_file("database.yml").path, file_join(config_dir, 'database.yml')
        rcopy render_file("auth_config.yml").path, file_join(config_dir, 'auth_config.yml')
      end
      
      def unc_data_dir
        to_unc(@host, data_dir)
      end
      
      private
      def render_file(template)
        str = File.read(File.join(File.dirname(__FILE__), "templates", template + '.erb'))
        file = Tempfile.new("mingle") 
        file.puts(ERB.new(str).result(binding))
        file
      ensure
        file.close
      end
      
      def rcopy(src, dest)
        cmd "copy /Y \"#{src}\" \"#{to_unc(@host, dest)}\""
      end

      def rmkdir(dir)
        cmd "md #{to_unc(@host, dir)}" rescue nil # may already exists
      end
      
      def cmd(cmd_line)
        puts "[Cluster Controller]$> #{cmd_line}"
        output = `#{cmd_line}`        
        raise output if $?.exitstatus != 0
        return ExecReceipt.new
      end
      
      def install_dir
        file_join @home_dir, "mingle"
      end
      
      def config_dir
        file_join @home_dir, "config"
      end
      
      def data_dir
        @type.data_dir(@home_dir)
      end
      
      def swap_dir
        file_join data_dir, "tmp"
      end
      
      def memcached_host
        @type.memcached_host
      end
      
      def local_installer
        "C:\\mingle_installer.exe"
      end
      
      def exec(command)
        WSH.exec(@host, command)
      end

      def mingle_services
        sc("query").scan(/^SERVICE_NAME: (MingleServer.*)/).collect do |line|
          line.split(': ').last
        end
      end
      
      def sc(cmd)
        Timeout::timeout(30) do
          cmd_line = "SC \\\\#{@host} #{cmd}"
          puts "[SERVICES(#{@host})]$> #{cmd}"
          output = `#{cmd_line}`

          if output =~ /^\[SC\].*FAILED (\d+):/
            raise SCError.new($1.to_i, output)
          end
          output
        end
      end
    end
    
    module NodeType      
      class Master
        include Utils

        def data_dir(home_dir)
          file_join home_dir, "data"          
        end
        
        def memcached_host
          '127.0.0.1'
        end
      end
      
      class Slave        
        def initialize(master)
          @master = master
        end
        
        def data_dir(home_dir)
          @master.unc_data_dir
        end
        
        def memcached_host
          @master.host
        end
      end
    end
    
    
    def initialize(config_file)
      @config = YAML.load(File.read(config_file))
      @master = Node.new(@config["master"], NodeType::Master.new, @config["mingle_home_dir"])
      @slaves = @config["slaves"].collect { |s| Node.new(s, NodeType::Slave.new(@master), @config["mingle_home_dir"]) }
    end
    
    def stop
      @master.stop_service("Apache2.2")
      (@slaves + [@master]).each(&:stop_mingle_service)
    end
    
    def backup_db
      dump_file = "mingle09_#{Time.now.utc.strftime("%Y%m%d%H%M%S")}_utc.dmp"

      ssh = Mingle::Ssh.new(db_config["host"], db_config["ssh_login"], db_config["ssh_password"])
      ssh.executeCommand([
        "exp mingle02/mingle02 file=#{dump_file} owner=mingle02",
        "tar cvf - #{dump_file} | gzip -c9 > #{dump_file}.tar.gz",
        "rm #{dump_file}"
      ])
    end
    
    def download_installer  
      Mingle::HttpDownloader.download(installer_download_url, installer_save_as)
      execute_on_each_node do |node|
        node.copy_installer(installer_save_as)
      end
    end
        
    def uninstall_mingle
      execute_on_each_node do |node|
        node.uninstall_mingle
      end
    end
    
    def install_mingle
      execute_on_each_node(5 * 60) do |node| 
        node.install_mingle
      end
      nodes.map(&:stop_mingle_service)
    end
    
    def configure
      nodes.map(&:configure)
    end
    
    private
    
    def nodes
      [@master] + @slaves
    end
    
    def execute_on_each_node(timeout=120, &block)
      receipts = nodes.map(&block)
      receipts.compact.each do |receipt|
        receipt.block_till_finished(timeout)
      end
    end
    
    def db_config
      @config["database"]
    end
    
    def installer_download_url
      @config["installer_download_url"]
    end
    
    def installer_save_as
      @config["installer_save_as"]
    end
  end
end
