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

require "sql_helper"

module DevOracleHelper

  PRIVILEGES = [
    "CREATE SESSION",
    "ALTER SESSION",
    "RESTRICTED SESSION",
    "CREATE TABLESPACE",
    "ALTER TABLESPACE",
    "MANAGE TABLESPACE",
    "DROP TABLESPACE",
    "UNLIMITED TABLESPACE",
    "CREATE USER",
    "BECOME USER",
    "ALTER USER",
    "DROP USER",
    "CREATE ROLLBACK SEGMENT",
    "ALTER ROLLBACK SEGMENT",
    "DROP ROLLBACK SEGMENT",
    "CREATE TABLE",
    "CREATE ANY TABLE",
    "ALTER ANY TABLE",
    "BACKUP ANY TABLE",
    "DROP ANY TABLE",
    "LOCK ANY TABLE",
    "COMMENT ANY TABLE",
    "SELECT ANY TABLE",
    "INSERT ANY TABLE",
    "UPDATE ANY TABLE",
    "DELETE ANY TABLE",
    "CREATE CLUSTER",
    "CREATE ANY CLUSTER",
    "ALTER ANY CLUSTER",
    "DROP ANY CLUSTER",
    "CREATE ANY INDEX",
    "ALTER ANY INDEX",
    "DROP ANY INDEX",
    "CREATE SYNONYM",
    "CREATE ANY SYNONYM",
    "DROP ANY SYNONYM",
    "CREATE PUBLIC SYNONYM",
    "DROP PUBLIC SYNONYM",
    "CREATE VIEW",
    "CREATE ANY VIEW",
    "DROP ANY VIEW",
    "CREATE SEQUENCE",
    "CREATE ANY SEQUENCE",
    "ALTER ANY SEQUENCE",
    "DROP ANY SEQUENCE",
    "SELECT ANY SEQUENCE",
    "CREATE DATABASE LINK",
    "CREATE PUBLIC DATABASE LINK",
    "DROP PUBLIC DATABASE LINK",
    "CREATE ROLE",
    "DROP ANY ROLE",
    "ALTER ANY ROLE",
    "AUDIT ANY",
    "FORCE TRANSACTION",
    "FORCE ANY TRANSACTION",
    "CREATE PROCEDURE",
    "CREATE ANY PROCEDURE",
    "ALTER ANY PROCEDURE",
    "DROP ANY PROCEDURE",
    "EXECUTE ANY PROCEDURE",
    "CREATE TRIGGER",
    "CREATE ANY TRIGGER",
    "ALTER ANY TRIGGER",
    "DROP ANY TRIGGER",
    "CREATE PROFILE",
    "ALTER PROFILE",
    "DROP PROFILE",
    "ALTER RESOURCE COST",
    "ANALYZE ANY",
    "CREATE MATERIALIZED VIEW",
    "CREATE ANY MATERIALIZED VIEW",
    "ALTER ANY MATERIALIZED VIEW",
    "DROP ANY MATERIALIZED VIEW",
    "DROP ANY DIRECTORY",
    "CREATE TYPE",
    "CREATE ANY TYPE",
    "ALTER ANY TYPE",
    "DROP ANY TYPE",
    "EXECUTE ANY TYPE",
    "UNDER ANY TYPE",
    "CREATE LIBRARY",
    "CREATE ANY LIBRARY",
    "ALTER ANY LIBRARY",
    "DROP ANY LIBRARY",
    "EXECUTE ANY LIBRARY",
    "CREATE OPERATOR",
    "CREATE ANY OPERATOR",
    "ALTER ANY OPERATOR",
    "DROP ANY OPERATOR",
    "EXECUTE ANY OPERATOR",
    "CREATE INDEXTYPE",
    "CREATE ANY INDEXTYPE",
    "ALTER ANY INDEXTYPE",
    "DROP ANY INDEXTYPE",
    "UNDER ANY VIEW",
    "QUERY REWRITE",
    "GLOBAL QUERY REWRITE",
    "EXECUTE ANY INDEXTYPE",
    "UNDER ANY TABLE",
    "CREATE DIMENSION",
    "CREATE ANY DIMENSION",
    "ALTER ANY DIMENSION",
    "DROP ANY DIMENSION",
    "MANAGE ANY QUEUE",
    "ENQUEUE ANY QUEUE",
    "DEQUEUE ANY QUEUE",
    "CREATE ANY CONTEXT",
    "DROP ANY CONTEXT",
    "CREATE ANY OUTLINE",
    "ALTER ANY OUTLINE",
    "DROP ANY OUTLINE",
    "ADMINISTER RESOURCE MANAGER",
    "ADMINISTER DATABASE TRIGGER",
    "MERGE ANY VIEW",
    "ON COMMIT REFRESH",
    "EXEMPT ACCESS POLICY",
    "RESUMABLE",
    "SELECT ANY DICTIONARY",
    "DEBUG CONNECT SESSION",
    "DEBUG ANY PROCEDURE",
    "FLASHBACK ANY TABLE",
    "GRANT ANY OBJECT PRIVILEGE",
    "CREATE EVALUATION CONTEXT",
    "CREATE ANY EVALUATION CONTEXT",
    "ALTER ANY EVALUATION CONTEXT",
    "DROP ANY EVALUATION CONTEXT",
    "EXECUTE ANY EVALUATION CONTEXT",
    "CREATE RULE SET",
    "CREATE ANY RULE SET",
    "ALTER ANY RULE SET",
    "DROP ANY RULE SET",
    "EXECUTE ANY RULE SET",
    "EXPORT FULL DATABASE",
    "IMPORT FULL DATABASE",
    "CREATE RULE",
    "CREATE ANY RULE",
    "ALTER ANY RULE",
    "DROP ANY RULE",
    "EXECUTE ANY RULE",
    "ANALYZE ANY DICTIONARY",
    "ADVISOR",
    "CREATE JOB",
    "CREATE ANY JOB",
    "EXECUTE ANY PROGRAM",
    "EXECUTE ANY CLASS",
    "MANAGE SCHEDULER",
    "SELECT ANY TRANSACTION",
    "DROP ANY SQL PROFILE",
    "ALTER ANY SQL PROFILE",
    "ADMINISTER SQL TUNING SET",
    "ADMINISTER ANY SQL TUNING SET",
    "CREATE ANY SQL PROFILE",
    "EXEMPT IDENTITY POLICY",
    "MANAGE FILE GROUP",
    "MANAGE ANY FILE GROUP",
    "CHANGE NOTIFICATION",
    "CREATE ANY EDITION",
    "DROP ANY EDITION",
    "ALTER ANY EDITION",
    "CREATE ASSEMBLY",
    "CREATE ANY ASSEMBLY",
    "ALTER ANY ASSEMBLY",
    "DROP ANY ASSEMBLY",
    "EXECUTE ANY ASSEMBLY",
    "EXECUTE ASSEMBLY",
    "CREATE MINING MODEL",
    "CREATE ANY MINING MODEL",
    "DROP ANY MINING MODEL",
    "SELECT ANY MINING MODEL",
    "ALTER ANY MINING MODEL",
    "COMMENT ANY MINING MODEL",
    "CREATE CUBE DIMENSION",
    "ALTER ANY CUBE DIMENSION",
    "CREATE ANY CUBE DIMENSION",
    "DELETE ANY CUBE DIMENSION",
    "DROP ANY CUBE DIMENSION",
    "INSERT ANY CUBE DIMENSION",
    "SELECT ANY CUBE DIMENSION",
    "CREATE CUBE",
    "ALTER ANY CUBE",
    "CREATE ANY CUBE",
    "DROP ANY CUBE",
    "SELECT ANY CUBE",
    "UPDATE ANY CUBE",
    "CREATE MEASURE FOLDER",
    "CREATE ANY MEASURE FOLDER",
    "DELETE ANY MEASURE FOLDER",
    "DROP ANY MEASURE FOLDER",
    "INSERT ANY MEASURE FOLDER",
    "CREATE CUBE BUILD PROCESS",
    "CREATE ANY CUBE BUILD PROCESS",
    "DROP ANY CUBE BUILD PROCESS",
    "UPDATE ANY CUBE BUILD PROCESS",
    "UPDATE ANY CUBE DIMENSION",
    "ADMINISTER SQL MANAGEMENT OBJECT",
    "ALTER PUBLIC DATABASE LINK",
    "ALTER DATABASE LINK",
    "FLASHBACK ARCHIVE ADMINISTER",
    "EXEMPT REDACTION POLICY",
  ]

  def recreate_users(schemas)
    ActiveRecord::Base.establish_connection(:admin)
    connection = ActiveRecord::Base.connection

    schemas.each do |schema|
      user = [ENV["USER"][0..20], schema.to_s].join("_").downcase

      puts "Recreating #{user}"

      drop_user = SqlHelper.sanitize_sql("DROP USER #{user} CASCADE")
      create_user = SqlHelper.sanitize_sql("CREATE USER #{user} IDENTIFIED BY mingle")
      grant_privs = PRIVILEGES.map { |privilege| SqlHelper.sanitize_sql("GRANT #{privilege} TO #{user}") }
      connection.execute(drop_user) if connection.schema_exists?(user)

      ([create_user] + grant_privs).each do |sql|
        begin
            connection.execute sql
        rescue => e
            puts "Error : #{e}"
        end
      end
    end

    puts "done"
  ensure
    ActiveRecord::Base.establish_connection(Rails.env.to_sym)
  end

  def drop_users(schemas)
    ActiveRecord::Base.establish_connection(:admin)
    connection = ActiveRecord::Base.connection

    schemas.each do |schema|
      user = [ENV["USER"][0..20], schema.to_s].join("_").downcase

      puts "Dropping #{user}"

      connection.execute(SqlHelper.sanitize_sql("DROP USER #{user} CASCADE")) if connection.schema_exists?(user)
    end

    puts "done"
  ensure
    ActiveRecord::Base.establish_connection(Rails.env.to_sym)
  end

  module_function :recreate_users, :drop_users
end
