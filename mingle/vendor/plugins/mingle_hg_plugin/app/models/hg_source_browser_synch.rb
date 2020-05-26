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

# Copyright 2010 ThoughtWorks, Inc. Licensed under the Apache License, Version 2.0.

# HgSourceBrowserSynch is HgRepository decorator that 
# keeps the source browser in synch with the repository
class HgSourceBrowserSynch
  
  def initialize(repository, source_browser)
    @repository = repository
    @source_browser = source_browser
  end
  
  def method_missing(method, *args)
    result = @repository.send(method, *args)
    synch(args[0], result) if (method.to_sym == :next_revisions) 
    result
  end
  
  def synch(skip_up_to, most_recently_cached_changesets)
    return if skip_up_to.nil? && most_recently_cached_changesets.empty?
           
    # check that previously cached changesets are still OK
    last_rev_number = if most_recently_cached_changesets.last
      most_recently_cached_changesets.last.number
    else
      skip_up_to.number
    end
    0.upto(last_rev_number) do |rev_number|
      unless @source_browser.cached?(rev_number)
         @source_browser.ensure_file_cache_synched_for(rev_number) 
      end       
    end
    
    # check that any old caches are cleaned up as the cache uses a lot of disk space
    @source_browser.clean_up_obsolete_cache_files
    
  end
  
end
