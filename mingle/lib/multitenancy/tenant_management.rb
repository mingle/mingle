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

module Multitenancy
  class TenantManagement
    def initialize(app)
      @app = app
    end

    def call(env)
      name = extract_tenant_name(env)
      return @app.call(env) if name =~ /localhost/
      if !Multitenancy.tenant_exists?(name)
        Rails.logger.warn("Unknown tenant name #{name.inspect} from REMOTE_HOST: #{env['REMOTE_HOST'].inspect} REMOTE_ADDR: #{env['REMOTE_ADDR'].inspect}")
        return [ 404, {}, ["Could not find #{name}"] ]
      end

      Multitenancy.activate_tenant(name) { @app.call(env) }
    end

    def extract_tenant_name(env)
      return nil if env['HTTP_HOST'].nil?
      host_name = env['HTTP_HOST'].split(':').first
      host_name.split('.').first
    end
  end
end
