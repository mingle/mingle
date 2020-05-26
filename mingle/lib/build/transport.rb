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

require 'net/ftp'
require 'net/https'
require 'uri'
require 'cgi'
require 'openssl'

module Mingle
  class JavaSsh
    def initialize(host, user, password)
      require 'java'
      $CLASSPATH << File.expand_path('../../../development/build_java/j2ssh-core-0.2.9.jar', __FILE__)
      java_import "com.sshtools.j2ssh.SshClient"
      java_import "com.sshtools.j2ssh.transport.IgnoreHostKeyVerification"
      java_import "com.sshtools.j2ssh.authentication.PasswordAuthenticationClient"
      java_import "com.sshtools.j2ssh.authentication.AuthenticationProtocolState"
      java_import "com.sshtools.j2ssh.session.SessionChannelClient"
      java_import "com.sshtools.j2ssh.connection.ChannelState"
      java_import "com.sshtools.j2ssh.session.SessionOutputReader"
      java_import "com.sshtools.j2ssh.session.SessionOutputEcho"
      java_import "java.io.InputStream"
      java_import "java.io.OutputStream"
      java_import "java.lang.Byte"
      @host = host
      @user = user
      @password = password
    end

    def executeCommand(command, ignore_exit_code=false)
      ssh = SshClient.new
      ssh.connect(@host, IgnoreHostKeyVerification.new)
      pwd = PasswordAuthenticationClient.new
      pwd.setUsername(@user)
      pwd.setPassword(@password)
      if ssh.authenticate(pwd) != AuthenticationProtocolState::COMPLETE
         raise "The authentication failed"
      end

      session = ssh.openSessionChannel

      output_reader = SessionOutputReader.new(session)
      cmd_input = session.getOutputStream


      if !session.requestPseudoTerminal("vt100", 80, 24, 0, 0, "")
        puts "[warning] #{@host} dose not support starting pseudo terminal"
      end

      if !session.startShell
        puts "[warning] cannot start shell on #{@host}"
      end

      if command.is_a?(Array)
        command.each { |c| execute_single(cmd_input, output_reader, c, ignore_exit_code) }
      else
        execute_single(cmd_input, output_reader, command, ignore_exit_code)
      end
    ensure
      unless session.nil?
        session.close
      end
      unless ssh.nil?
        ssh.disconnect
      end
    end

    private

    def execute_single(cmd_input, output_reader, command, ignore_exit_code)
      output_reader.markCurrentPosition

      push_command(cmd_input, command)
      push_command(cmd_input, "echo [$?] end of single ssh `echo command`")
      cmd_input.flush

      wait_for_single_command_end(output_reader)
      marked = output_reader.getMarkedOutput
      exitcode = -1
      exitcode_first = marked.scan(/^\[(\d+)\] end of single ssh command/).first
      unless exitcode_first.nil?
        exitcode_first_first = exitcode_first.first
        if (!exitcode_first_first.nil?)
          exitcode = exitcode_first_first.to_i
        else
          exitcode = exitcode_first.to_i
        end
      end

      if !ignore_exit_code && exitcode != 0
        raise "remote execution failed, exitcode is #{exitcode}. Try execute command on #{@host} by hand."
      end
    end

    def wait_for_single_command_end(output_reader)
      output_reader.wait_for_string("end of single ssh command") do |echo|
        print echo
      end
      print "\n"
    rescue  => e
      puts "[WARNING] you ssh output terminated with #{e.class.name} #{e}, it may not execute successfully, watch out."
    end

    def push_command(cmd_input, command)
      command_bytes = (command + "\n").to_java_bytes
      cmd_input.write(command_bytes, 0, command_bytes.length)
    end
  end

  class JavaSftp
    def initialize(host, user, password)
      require 'java'
      java_import "com.sshtools.j2ssh.SshClient"
      java_import "com.sshtools.j2ssh.transport.IgnoreHostKeyVerification"
      java_import "com.sshtools.j2ssh.authentication.PasswordAuthenticationClient"
      java_import "com.sshtools.j2ssh.authentication.AuthenticationProtocolState"
      java_import "com.sshtools.j2ssh.session.SessionChannelClient"
      java_import "com.sshtools.j2ssh.SftpClient"
      java_import "java.io.InputStream"
      java_import "java.io.OutputStream"
      java_import "java.lang.Byte"
      @host = host
      @user = user
      @password = password
    end
    def upload(src,dest)
      ssh = SshClient.new
      ssh.connect(@host, IgnoreHostKeyVerification.new)
      pwd = PasswordAuthenticationClient.new
      pwd.setUsername(@user)
      pwd.setPassword(@password)
      result = ssh.authenticate(pwd)
      if (result == AuthenticationProtocolState::COMPLETE)
        puts "The authentication is completed"
        sftp = ssh.openSftpClient
        sftp.put(src,dest)
        sftp.quit
        ssh.disconnect
      else
        puts "Cannot authenticate with remote server : #{@host}"
      end
    end

  end

  class MRISsh
    def initialize(host, user, password)
      require 'net/ssh'

      @host = host
      @user = user
      @password = password
    end

    def executeCommand(command)
      Net::SSH.start(@host, @user, :password => @password, verbose: :error, paranoid: false) do |session|
        if command.is_a?(Array)
          command.each { |c| puts session.exec!(c) }
        else
          puts session.exec!(command)
        end

      end
    end
  end

  Ssh = MRISsh


  class Ftp
    def initialize(connection_spec)
      @connection_spec = connection_spec
    end

    def upload(file)
      measuring "Uploading #{file}" do
        with_connection {|ftp| ftp.putbinaryfile(file) }
      end
    end

    def download(file, new_pos)
      measuring "Downloading #{file}" do
        FileUtils.mkdir_p(File.dirname(new_pos))
        with_connection {|ftp| ftp.getbinaryfile(file, new_pos) }
      end
    end

    def with_connection(&block)
      Net::FTP.open(@connection_spec[:host], @connection_spec[:user], @connection_spec[:password]) do |ftp|
        ftp.passive = true
        ftp.chdir(@connection_spec[:path]) if @connection_spec[:path]
        yield(ftp)
      end
    end

    private
    def measuring(title, &block)
      start_from = Time.now
      print(title)
      print('...')
      yield
      puts("finished using #{Time.now - start_from} seconds")
    end

  end


  module HttpDownloader
    def self.download(url, save_as=nil)
      uri = URI.parse(url)

      save_as ||= uri.path.split('/').last

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == "https"

      http.start do |http|
        req = Net::HTTP::Get.new(uri.path)
        if uri.user
          req.basic_auth(CGI.unescape(uri.user), CGI.unescape(uri.password))
        end

        http.request(req) do |resp|
          raise "error: #{resp.code}" unless resp.code == "200"
          size = 0
          File.open(save_as, "wb") do |file|
            resp.read_body do |seg|
              size += seg.size
              puts "downloaded #{ size / 1024 / 1024 } M" if (size % (1024 * 1024)) == 0
              file.write(seg)
            end
          end
        end
      end
      puts "Dowload succeed. Saved to file #{save_as} (#{File.size(save_as) /1024 / 1024}M)"
    end
  end
end
