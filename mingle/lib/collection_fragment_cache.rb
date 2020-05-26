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

class CollectionFragmentCache
  def initialize(key_generator, collection, cache_store)
    @key_generator = key_generator
    @collection = collection
    @cache_store = cache_store
  end

  def fragment_for(buffer, *element, &block)
    return yield unless ActionController::Base.perform_caching
    key = path_for(element)
    if content = contents_hash[key]
      buffer.safe_concat(content.html_safe)
    else
      pos = buffer.length
      yield
      write_fragment(key, buffer[pos..-1])
    end
  end

  private

  def write_fragment(key, content)
    content = content.html_safe.to_str if content.respond_to?(:html_safe)
    @cache_store.add(key, content)
  end

  def contents_hash
   @contents_hash ||= @cache_store.get_multi(all_keys)
  end

  def all_keys
    @collection.map {|element| path_for(element) }
  end

  def path_for(element)
    @key_generator.path_for(*element)
  end

end
