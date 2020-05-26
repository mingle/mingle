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

module Messaging
  module Adapters
    module JMS
      def load_config
        if Rails.env.production? && !Rails.env.acceptance_test?
          unless BrokerConfiguration.load
            BrokerConfiguration.create
          else
            BrokerConfiguration.load
          end
        else
          $jms_broker_config || {
            'username' => 'mingle',
            'password' => 'password',
            'uri' => 'vm://localhost?broker.persistent=false&jms.useAsyncSend=false'
          }
        end
      end

      module_function :load_config

      class BrokerConfiguration

        DEFAULTS = {
          :username => "mingle",
          :password  => "password",
          :uri => "vm://localhost?create=false&jms.prefetchPolicy.all=0"
        }

        class << self

          def create(file_name = BROKER_CONFIG_YML)
            FileUtils.mkpath(File.dirname(file_name))
            File.open(file_name, "w+") do |io|
              io.syswrite("username: #{DEFAULTS[:username]}\n")
              io.syswrite("password: #{DEFAULTS[:password]}\n")
              io.syswrite("uri: #{DEFAULTS[:uri]}\n")
            end
            load(file_name)
          end

          def load(config_file = BROKER_CONFIG_YML)
            if File.exist?(config_file)
              yaml_content = YAML::load_file(config_file)
              # there is random failure on installer test build, add more info when it fails again
              if !yaml_content.is_a?(Hash)
                raise "Borker config is invalid: file (#{config_file}), content: \n#{File.read(config_file)}"
              end

              disable_prefetch(config_file) if !prefetch_set?(yaml_content)
              YAML::load_file(config_file)
            else
              create(config_file)
            end
          end

          protected

          def disable_prefetch(file_name)
            prefetch_setting = "jms.prefetchPolicy.all=0"

            # instead of just writing out the YAML contents back to file
            # read each line so we preserve any comments
            file_content = File.read(file_name)
            result = []
            file_content.each_line do |line|
              if line.starts_with?('uri:')
                uri_value = line.gsub('uri:', '').strip
                host, query = parse_broker_uri(uri_value)
                query = "" == query ? "?#{prefetch_setting}" : query + "&#{prefetch_setting}"
                result << "uri: #{host}#{query}"
              else
                result << line
              end
            end
            File.open(file_name, "w+") { |file| file.write(result.join("\n")) }
          end

          def prefetch_set?(yaml_content)
            if uri_value = yaml_content['uri']
              # parsing with URI.parse doesn't work for broker urls using the
              # failover:() transport
              uri_value =~ /(\?|\&)jms\.prefetchPolicy\.all=/
            else
              false
            end
          end

          # this bit of hackery understands broker uris that contain multiple hosts
          # like the failover transport. example: failover:(host1, host2)?param1=foo&param2=bar
          def parse_broker_uri(uri_value)
            start_of_query = if index = uri_value.rindex(")")
                               index + 1
                             elsif index = uri_value.index("?")
                               index
                             else
                               uri_value.size
                             end
            [uri_value[0, start_of_query], uri_value[start_of_query, uri_value.size]]
          end

        end
      end
    end
  end
end
