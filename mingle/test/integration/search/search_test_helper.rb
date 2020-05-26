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


puts "\nStarting ElasticSearch server...\n"
java.lang.System.set_property("mingle.dataDir", File.expand_path(File.join(File.dirname(__FILE__), "..", "..", "..", "tmp")))
java.lang.System.set_property("es.foreground", "yes")
org.elasticsearch.bootstrap.Elasticsearch.main([])

at_exit {
  puts "\nShutting down ElasticSearch server...\n"
  org.elasticsearch.bootstrap.Elasticsearch.close([])
}

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../messaging/messaging_test_helper')

class ActiveSupport::TestCase
  self.use_memcached_stub
  include MessagingTestHelper
end
