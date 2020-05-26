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

module ServerStarter
  APP_CONTEXT = ENV["APP_CONTEXT"] || "/"

  def start(options = {})
    RailsEnvironment.start(options)
  end

  def stop
    RailsEnvironment.stop
  end

  def with_mingle_server(additional_system_properties={}, &block)
    RailsEnvironment.with_mingle_server additional_system_properties, &block
  end

  def ip
    RailsEnvironment.ip
  end

  def port
    RailsEnvironment.port
  end

  def base_url
    context = (APP_CONTEXT.end_with?("/") ? APP_CONTEXT : "#{APP_CONTEXT}/").chomp("/")
    "http://#{ip}:#{port}#{context}".tap { |url| puts ">>> selenium base_url: #{url.inspect}" }
  end

  module_function :start, :stop, :with_mingle_server, :ip, :port, :base_url

  class JRuby
    @@server = nil
    @ip = "localhost"
    @port = 8080

    class << self
      attr_accessor :port, :ip

      def with_mingle_server(additional_system_properties={}, &block)
        start(additional_system_properties)
        yield
      ensure
        self.stop
      end

      def start(options = {})
        @port = options[:port] if options.has_key? :port
        @ip = options[:ip] if options.has_key? :ip
        @startup_hooks = options[:startup_hooks] || []
        puts "Starting your JRuby application at #{@ip}:#{@port}..."
        start_application(options)
        return [@ip, @port]
      end

      def stop
        puts "Shutting down your JRuby application..."
        @@server.stop unless @@server.nil?
        puts "DONE"
      rescue Exception => e
        puts "Failed to close your JRuby application, maybe it already closed?: #{e.message}"
        puts e.backtrace.join("\n")
      end

      private

      def setup_config_dir
        config_dir = File.expand_path("../tmp/tests/config", File.dirname(__FILE__))
        FileUtils.rm_rf config_dir
        FileUtils.mkdir_p config_dir
        FileUtils.cp(Rails.root.join("config", "auth_config.yml"), config_dir)
        FileUtils.cp(Rails.root.join("config", "smtp_config.yml"), config_dir)
        FileUtils.cp(Rails.root.join("config", "database.yml"), File.join(config_dir))
      end


      def start_application(options={})
        setup_config_dir
        @@server = create_server(system_properties(options))
        @@server.start

        wait_for_app_server
        wait_for_ready_state
        @startup_hooks.each { |hook| hook.call(@ip, @port) }
        wait_for_memcached_server_ready
        puts "\nJRuby application started."
      end

      def create_server(system_properties)
        ENV['TEST_DUAL_APP'] ? DualAppServer.new(system_properties) : Java::ComThoughtworksMingle::Server::testInstance(system_properties)
      end


      def wait_for_memcached_server_ready
        puts ""
        puts "Wait for memcached server ready"
        retryable(:tries => 600, :sleep => 0.1) do |retries, exception|
          CACHE.get("hello")
        end
      end

      def wait_for_app_server
        puts "[#{Time.now}] Start waiting for Mingle server start"

        Timeout.timeout(600) do
          sleep 1 while @@server.getStatus.downcase != "started"
        end
      rescue => e
        puts "[#{Time.now}] Waiting for Mingle server start failed #{e.message}"
        raise e
      end

      def wait_for_ready_state
        ready_states = %w(BOOTSTRAP_COMPLETED LICENSED_AND_READY)
        ready_state_uri = URI.join(ServerStarter.base_url, "bootstrap_status")
        puts "[#{Time.now}] Start waiting for Mingle bootstrap status"
        Timeout.timeout(600) do
          loop do
            puts "Get: #{ready_state_uri}"
            status = begin
              Net::HTTP.get(ready_state_uri)
            rescue
              nil
            end
            p status
            if ready_states.include?(status.to_s.strip)
              break
            end
            sleep 2
          end
        end
      rescue => e
        puts "[#{Time.now}] Waiting for Mingle bootstrap status failed #{e.message}"
        raise e
      end

      def system_properties(options={})
        sys_props = {}
        sys_props["mingle.dataDir"] = File.expand_path("../", File.dirname(__FILE__))
        sys_props["jruby.compat.version"] = "1.9"
        sys_props["mingle.configDir"] = "tmp/tests/config"
        sys_props["mingle.swapDir"] = "tmp"
        sys_props["mingle.port"] = @port.to_s
        sys_props["mingle.appContext"] = ServerStarter::APP_CONTEXT
        sys_props["mingle.noCleanup"] = "true"
        sys_props["mingle.web.xml"] = File.expand_path("../config/selenium_web.xml", File.dirname(__FILE__))
        sys_props["jruby.max.runtimes"] = "1"
        sys_props["jruby.min.runtimes"] = "1"
        sys_props["mingle.services"] = "amq.connection.factory, memcached, elastic_search"
        sys_props["mingle.siteURL"] = "http://#{Socket.gethostname}:#{@port}"
        sys_props["mingle.secureSiteURL"] = "http://#{Socket.gethostname}:8443"
        sys_props
      end
    end
  end

  RailsEnvironment = JRuby
end
