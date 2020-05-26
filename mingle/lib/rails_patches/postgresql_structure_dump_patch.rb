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

require "uri"
if RUBY_PLATFORM =~ /java/
  module ::JdbcSpec::PostgreSQL
    def structure_dump
      abcs = ActiveRecord::Base.configurations

      url = URI.parse(abcs[Rails.env]["url"].match(/^jdbc:(.+)$/)[1])
      database = url.path.gsub(/^\/+/,"")

      raise "Could not figure out what database this url is for #{abcs[Rails.env]["url"]}" if database.blank?

      ENV['PGHOST']     = url.host if url.host
      ENV['PGPORT']     = url.port.to_s if url.port
      ENV['PGPASSWORD'] = abcs[Rails.env]["password"].to_s if abcs[Rails.env]["password"]

      @connection.connection.close
      begin
        file = "db/#{Rails.env}_structure.sql"
        `pg_dump -h "#{url.host}" -U "#{abcs[Rails.env]["username"]}" -s -x -O -f #{file} #{database}`
        raise "Error dumping database - if this is a RDS instance, did you change the ownership of plpgsql?" if $?.exitstatus == 1

        # need to patch away any references to SQL_ASCII as it breaks the JDBC driver
        lines = File.readlines(file)
        File.open(file, "w") do |io|
          lines.each do |line|
            line.gsub!(/SET search_path =.*$/, "")
            line.gsub!(/SET row_security =.*$/, "") # not supported by PostgreSQL < 9.5
            line.gsub!(/SET idle_in_transaction_session_timeout =.*$/, "") # not supported by PostgreSQL < 9.6
            line.gsub!(/SQL_ASCII/, 'UNICODE')
            line.gsub!(/public\./, '') # pg_dump adding public prefix to table names, removing that
            line.gsub!(/UTF8/, 'UNICODE')
            line.gsub!(/^(-- (?:.+))(?: Schema: public;)(.+)$/, '\1\2')
            line.gsub!(/^(-- (?:.+))(?:; Tablespace:[^;]+)(.*)$/, '\1\2')
            line.gsub!(/CREATE PROCEDURAL LANGUAGE plpgsql.*$/, "")
            # filter out because RDS user is not owner of the extension. This is useless anyway.
            line.gsub!(/COMMENT ON EXTENSION plpgsql.*$/, "")
            io.write(line)
          end
        end
      ensure
        reconnect!
      end
    end
  end
end
