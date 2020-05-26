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

module ActiveRecord
  module ConnectionAdapters # :nodoc:
    class AbstractAdapter
      def log_info(sql, name, runtime)
        return unless @logger
        @logger.debug(
          format_log_entry(
            "#{name.nil? ? "SQL" : name} (#{sprintf("%f", runtime)})",
            sql.gsub(/ +/, " ")
          )
        )
        if $tracing_sql
          @logger.debug(
                        caller.select { |line|
                          ['app', 'lib'].any? do |dir|
                            line.starts_with?(File.join(Rails.root, dir))
                          end
                        }.join("\n")
          )
        end
      end
    end
  end
end

def trace_sql(&block)
  $tracing_sql = true
  begin
    yield
  ensure
    $tracing_sql = false
  end
end
