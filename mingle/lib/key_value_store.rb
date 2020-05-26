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

module KeyValueStore
  class CachedSource
    def initialize(source, namespace)
      @source = source
      @namespace = namespace
    end

    def [](cache_key)
      Cache.get(keyname(cache_key)) do
        @source[cache_key]
      end
    end

    def []=(cache_key, config)
      @source[cache_key] = config
      delete_cache(cache_key)
    end

    def delete(cache_key)
      @source.delete(cache_key)
      delete_cache(cache_key)
    end

    def clear
      @source.clear
      Cache.flush_all
    end

    def names
      Cache.get(all_names_key, 15.minutes) do
        @source.names
      end
    end

    def all_items
      @source.all_items
    end

    private

    def delete_cache(cache_key)
      Cache.delete(keyname(cache_key))
      Cache.delete(all_names_key)
    end

    def keyname(cache_key)
      CGI.escape("multitenancy/#{@namespace}/#{cache_key}_configs")
    end

    def all_names_key
      "multitenancy/#{@namespace}/all_cache_keys"
    end

    def all_items_key
      "multitenancy/#{@namespace}/all_items"
    end
  end

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
