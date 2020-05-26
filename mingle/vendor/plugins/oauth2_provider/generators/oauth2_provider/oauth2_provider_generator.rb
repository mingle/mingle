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

# Copyright (c) 2010 ThoughtWorks Inc. (http://thoughtworks.com)
# Licenced under the MIT License (http://www.opensource.org/licenses/mit-license.php)

class Oauth2ProviderGenerator < Rails::Generator::Base
  def manifest
    record do |m|
      m.template 'config/initializers/oauth2_provider.rb', "config/initializers/oauth2_provider.rb"

      m.directory 'db/migrate'
      ['create_oauth_clients', 'create_oauth_tokens', 'create_oauth_authorizations'].each_with_index do |file_name, index|
        m.template "db/migrate/#{file_name}.rb", "db/migrate/#{version_with_prefix(index)}_#{file_name}.rb", :migration_file_name => file_name
      end

    end
  end

  def after_generate
    puts "*"*80
    puts "Please edit the file 'config/initializers/oauth2_provider.rb' as per your needs!"
    puts "The readme file in the plugin contains more information about configuration."
    puts "*"*80
  end

  private
  def version_with_prefix(prefix)
    Time.now.utc.strftime("%Y%m%d%H%M%S") + "#{prefix}"
  end

end
