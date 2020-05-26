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

conf_dir = File.dirname(__FILE__)
jars = File.expand_path(File.join(conf_dir, "..", "vendor", "java", "**", "*.jar"))
start_jar = File.expand_path(File.join(conf_dir, "..", "lib", "start.jar"))
version_jar = File.expand_path(File.join(conf_dir, "..", "lib", "version.jar"))

$CLASSPATH ||= []
$CLASSPATH << start_jar if File.exist?(start_jar)
$CLASSPATH << version_jar if File.exist?(version_jar)

Dir[jars].each do |path|
  $CLASSPATH << path
end

$CLASSPATH << conf_dir

require 'rubygems'
require 'bundler/setup'

require 'rails2_rubygems2_compatibility'
