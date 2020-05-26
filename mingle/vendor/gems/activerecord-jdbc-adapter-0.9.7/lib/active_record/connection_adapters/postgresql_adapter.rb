tried_gem = false
begin
  require "jdbc/postgres"
rescue LoadError
  unless tried_gem
    require 'rubygems'
    begin
      gem "jdbc-postgres"
    rescue LoadError
      tried_gem = true
    end
    retry
  end
  # trust that the postgres jar is already present
end
require 'active_record/connection_adapters/jdbc_adapter'