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

Bulk::BulkDestroy # is there a better way to ensure class is loaded?
module Bulk
  class BulkDestroy
    def run_with_invalidate_renderable_content_cache(options)
      result = self.run_without_invalidate_renderable_content_cache(options)
      project.invalidate_renderable_content_cache('bulk destroy')
      result
    end
    alias_method_chain :run, :invalidate_renderable_content_cache

  end
end
