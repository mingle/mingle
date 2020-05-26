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

require 'pstore'

module RailsTmpDir::ParalleledTestDatabase
  def self.file
    RailsTmpDir::RailsTmpFileProxy.new 'db_locks.pstore'
  end
end

class ParalleledTestDatabase
  MAX_DB_NUMBER = 9 unless defined?(MAX_DB_NUMBER)
  
  class ProcessLevelLocks
    def initialize(lock_file)
      FileUtils.mkdir_p(File.dirname(lock_file))
      @store = PStore.new(lock_file)
    end
    
    def find_available_one(candidates)
      @store.transaction do
        candidate = candidates.detect { |c| !locked?(c) }
        if candidate
          lock(candidate)
        end
        candidate
      end
    end
    
    private
    def lock(name)
      @store[name] = Process.pid
    end
    
    def unlock(name)
      @store[name] = nil
    end
    
    def locked?(name)
      pid = @store[name]
      pid && process_live?(pid)
    end
  
    def process_live?(pid)
      pid > 0 && Process.getpgid(pid) != -1 # ruby 1.6 will return -1 and >=1.7 will throw exception if process not exist
    rescue Errno::ESRCH 
      return false
    end
  end
    
  def self.connect
    unless defined?(@@db)
      @@db = self.new
      @@db.connect
    end
  end
  
  def initialize
    @locks = ProcessLevelLocks.new(lock_file)
  end
  
  def connect
    base_name = ActiveRecord::Base.configurations['test']['database']
    db_name = find_out_avail(base_name)
    puts "Using database #{db_name}"
    ActiveRecord::Base.configurations['test']['database'] = db_name
    ActiveRecord::Base.establish_connection(ActiveRecord::Base.configurations['test'])
  end
  
  private
  
  def lock_file
    RailsTmpDir::ParalleledTestDatabase.file.pathname
  end
  
  def find_out_avail(base_name)
    candidates = (0..MAX_DB_NUMBER).to_a.collect{ |i| base_name + "_#{i}" }
    candidates.unshift(base_name)
    if candidate = @locks.find_available_one(candidates)
      return candidate
    end
    
    raise "There is no test database available, maybe you should clean up the locks file: #{lock_file}"
  end
  
end

if !(RUBY_PLATFORM =~ /java/)
  ParalleledTestDatabase.connect
end
