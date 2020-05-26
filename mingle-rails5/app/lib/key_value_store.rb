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

require 'uuid'
require 'mingle_keyvalue_store'
module KeyValueStore

  module_function
  def create(table, keyname, value, saas_mode=false)
    source = if table && saas_mode && !Rails.env.test?
               Mingle::KeyvalueStore::DynamodbBased.new(table, keyname, value)
             else
               path = RailsTmpDir::RailsTmpFileProxy.new([Rails.env]).pathname
               table ||= UUID.generate(:compact)[0..8]
               FileUtils.mkdir_p path
               Mingle::KeyvalueStore::PStoreBased.new(path, table, keyname, value)
             end

    CachedSource.new(source, table)
  end

end
