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

require 'oauth2/provider/a_r_datasource'
require 'oauth2/provider/in_memory_datasource'
require 'oauth2/provider/model_base'
require 'oauth2/provider/clock'
require 'oauth2/provider/url_parser'
require 'oauth2/provider/configuration'

Oauth2::Provider::ModelBase.datasource = ENV["OAUTH2_PROVIDER_DATASOURCE"]

Dir[File.join(File.dirname(__FILE__), "..", "app", "**", '*.rb')].each do |rb_file|
  require File.expand_path(rb_file)
end

