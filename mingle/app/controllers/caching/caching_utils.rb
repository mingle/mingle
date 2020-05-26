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

module CachingUtils

  def join(*keys)
    keys.compact.map{|k| k.to_s.gsub(/ /, '_')}.join("/")
  end

  def generate_unique_key
    "aa".uniquify
  end

  def cached_unique_key(key_name)
    key = Cache.get(key_name) { generate_unique_key }
  end

  def digest(str)
    MD5::md5(str || "").hexdigest
  end

  module DatabaseFingerprinting
    # Fingerprint that changes on create, destroy or update
    def fingerprint(model, conditions)
      count = model.count(:conditions => conditions)
      last_modified = model.maximum(:updated_at, :conditions => conditions).to_f
      "#{count}_#{last_modified}"
    end

    # Fingerprint that changes only create and destroy
    def count_fingerprint(model, conditions)
      count = model.count(:conditions => conditions)
      last_created = model.maximum(:created_at, :conditions => conditions).to_f
      "#{count}_#{last_created}"
    end
  end

end
