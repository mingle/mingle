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

module ThreadLocalCache
  class << self
    def get(key, &block)
      return get_thread_cache(key) if get_thread_cache(key)
      return set_thread_cache(key, yield) if block_given?
    end

    # cache associations of the model in thread local
    # to avoid SQL n+1 problem
    # example:
    #    1. ThreadLocalCache.get_assn(model, :project)
    #       is a cached version of model.project
    #    2. ThreadLocalCache.get_assn(user_membership, :group, :deliverable)
    #       will get a cached version of user_membership.group.deliverable
    #       if group or deliverable is cached already
    # The cache key is association name + association id
    def get_assn(m, *associations)
      assn = associations.shift
      assn_id = "#{assn}_id"
      result = if m.respond_to?(assn_id)
                 get("#{assn}_#{m.send(assn_id)}") { m.send(assn) }
               else
                 m.send(assn)
               end
      if associations.empty?
        result
      else
        get_assn(result, *associations)
      end
    end

    def set(key, value)
      set_thread_cache(key, value)
    end

    def clear!
      Thread.current.keys.each do |key|
        Thread.current[key] = nil if key.to_s =~ /^mingle_cache_/
      end
    end

    def clear(key)
      set_thread_cache(key, nil)
    end

    private
    def get_thread_cache(key)
      Thread.current["mingle_cache_#{MingleConfiguration.app_namespace}_#{key}"]
    end

    def set_thread_cache(key, value)
      Thread.current["mingle_cache_#{MingleConfiguration.app_namespace}_#{key}"] = value
    end
  end

end
