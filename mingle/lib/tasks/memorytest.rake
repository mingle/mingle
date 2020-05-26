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
namespace :memorytest do

    require 'net/http'
    require 'uri'
    require 'fileutils'
    require 'net/https'
  
    MEMTEST_SPEC = {
      :mingle_port =>'8080',
      :host => ENV["MEMTEST_HOST"] || "localhost",
      :port => ENV["MEMTEST_HOST_PORT"] || '8080',
      :auth_user => ENV["MEMTEST_USER"] || 'mingleadmin',
      :auth_passwd => ENV["MEMTEST_PASSWD"] || 'password',
      :httperf_log_root => ENV["HTTPERF_LOG_ROOT"] || "/var/lib/cruise-agent/performance-httperf",
      :httperf_sessions => (ENV["HTTPERF_SESSIONS"] || "1"),
      :jmx_port => ENV["MEMTEST_JMX_PORT"] || "1098"
    }
  
    SSH_CON_SPEC = [
      ENV["SSH_SPEC_HOST"] || "sfsstdmngbgr07.thoughtworks.com",
      ENV["SSH_SPEC_ACCOUNT"] || "cruise",
      ENV["SSH_SPEC_PASSWORD"] || "tw0rk3r"]
  
    task :startApp => ['environment','force_kill_application','install_mingle','create_mingle_config','db_prepare_from_dump','application_start_production_mode','server_warmup']
    task :stopApp => ['environment','application_stop_production_mode','force_kill_application']
   
    task :test do
      # Why do we need a fake test task???
    end
    
    task :server_warmup do
      sleep 60
      # update eula
      `psql mingle_memory_test -c "update licenses set eula_accepted='t'"`
      # Tell server we are ready 
      sleep 10
      puts "Hit the server"
      5.times do
        `curl http://#{MEMTEST_SPEC[:host]}:#{MEMTEST_SPEC[:port]} -d \"value=foo\"`
        #http = Net::HTTP.new(MEMTEST_SPEC[:host],MEMTEST_SPEC[:port])
        #resp, body = http.post("/startup","value=foobar")
        sleep 2
      end
      sleep 120
    end
    
    task :force_kill_application do
      `/bin/ps auxwww | /bin/grep MingleServer | /bin/grep -v grep | /bin/cut -c10-14 | /usr/bin/xargs kill -9`
      `/bin/rm -f /tmp/i4jdaemon*`
    end
    
    task :application_start_production_mode do
      `#{MINGLE_SERVER_ROOT}/mingle_#{ENV["INSTALLER_VERSION"]}/MingleServer start --mingle.dataDir=#{MINGLE_SERVER_ROOT}/data`
    end
  
    task :application_stop_production_mode do
      `#{MINGLE_SERVER_ROOT}/mingle_#{ENV["INSTALLER_VERSION"]}/MingleServer stop --mingle.dataDir=#{MINGLE_SERVER_ROOT}/data`
    end
  
    task :db_prepare_from_dump do
      ENV['PGHOST'] = 'localhost'
      ENV['PGPORT'] = '5432'
      ENV['PGPASSWORD'] = 'mingle'
      ENV['PGUSER'] = 'mingle'
      `dropdb mingle_memory_test`
      `createdb -O mingle -E UTF-8 mingle_memory_test`
      `gunzip -c "#{MEMTEST_SPEC[:httperf_log_root]}/db/mingle_performance.sql.gz" | psql mingle_memory_test`
    end
  
    task :install_mingle do
      MINGLE_SERVER_ROOT=ENV["MINGLE_SERVER_ROOT"] || "/var/lib/cruise-agent/mingle"
      INSTALLER_PATH=ENV["INSTALLER_PATH"] || "/var/lib/cruise-agent/installers"
      INSTALLER_VERSION=ENV["INSTALLER_VERSION"] || raise("Please specify INSTALLER_VERSION as environment variable")
      `rm -rf "#{MINGLE_SERVER_ROOT}"/*`
      `tar zxvf "#{INSTALLER_PATH}/#{INSTALLER_VERSION}/mingle_unix_#{INSTALLER_VERSION}_#{MINGLE_REVISION}.tar.gz" -C "#{MINGLE_SERVER_ROOT}"`
    end
  
    task :create_mingle_config do
      
      MINGLE_SERVER_ROOT=ENV["MINGLE_SERVER_ROOT"] || "/var/lib/cruise-agent/mingle"
      `mkdir -p "#{MINGLE_SERVER_ROOT}/data/config"`
      mingle_properties = File.new("#{MINGLE_SERVER_ROOT}/data/mingle.properties","w")
      mingle_properties.print "-Dmingle.swapDir=#{MINGLE_SERVER_ROOT}/data/tmp\n" 
      mingle_properties.print "-Dmingle.appContext=/\n"
      mingle_properties.print "-Dmingle.memcachedPort=11211\n"
      mingle_properties.print "-Dmingle.port=#{MEMTEST_SPEC[:port]}\n"
      mingle_properties.print "-Dmingle.logDir=#{MINGLE_SERVER_ROOT}/data/log\n"
      mingle_properties.print "-Dmingle.memcachedHost=127.0.0.1\n"
      mingle_properties.close
  
      auth_config = File.new("#{MINGLE_SERVER_ROOT}/data/config/auth_config.yml","w")
      auth_config.print "password_format: \n"
      auth_config.print "basic_authentication_enabled: true\n"
      auth_config.print "basic_authentication: \n"
      auth_config.print "authentication: \n"
      auth_config.print "ldap_settings:\n"
      auth_config.print "  #ldapserver: \n"
      auth_config.print "  #ldapport: \n"
      auth_config.print "  #ldapbinduser: \n"
      auth_config.print "  #ldapbindpasswd: \n"
      auth_config.print "  #ldapbasedn: \n"
      auth_config.print "  #ldapfilter: \n"
      auth_config.print "  #ldapobjectclass: \n"
      auth_config.print "  #ldap_map_fullname: \n"
      auth_config.print "  #ldap_map_mail: \n"
      auth_config.print "  #ldapgroupobjectclass: \n"
      auth_config.print "  #ldapgroupdn: \n"
      auth_config.print "  #ldapgroupattribute: \n"
      auth_config.print "cas_settings:\n"
      auth_config.print "  #cas_port: \n"
      auth_config.print "  #cas_host: \n" 
      auth_config.print "  #cas_uri: \n"
      auth_config.close 
  
      broker_yml = File.new("#{MINGLE_SERVER_ROOT}/data/config/broker.yml","w")
      broker_yml.print "username: mingle\n"
      broker_yml.print "password: password\n"
      broker_yml.print "uri: vm://localhost?create=false\n"
      broker_yml.close
  
      database_yml = File.new("#{MINGLE_SERVER_ROOT}/data/config/database.yml","w")
      database_yml.print "--- \n"
      database_yml.print "production: \n"
      database_yml.print "  driver: org.postgresql.Driver\n"
      database_yml.print "  password: \"\"\n"
      database_yml.print "  username: mingle\n"
      database_yml.print "  adapter: jdbc\n"
      database_yml.print "  url: jdbc:postgresql://localhost:5432/mingle_memory_test\n"
      database_yml.close  
  
      smtp_config = File.new("#{MINGLE_SERVER_ROOT}/data/config/smtp_config.yml","w")
      smtp_config.print "smtp_settings:\n"
      smtp_config.print "  #authentication: \n"
      smtp_config.print "  #user_name: \n"
      smtp_config.print "  #password: \n"
      smtp_config.print "  address: localhost\n"
      smtp_config.print "  port: 25\n"
      smtp_config.print "  domain: thoughtworks.com\n"
      smtp_config.print "  tls: false\n"
      smtp_config.print "site_url: http://sfsstdmngbgr07.thoughtworks.com:8080\n"
      smtp_config.print "sender:\n"
      smtp_config.print "  address: mingle-memory-test@thoughtworks.com\n"
      smtp_config.print "  name: Mingle Administrator\n"
      smtp_config.close
  
    end
  

end
