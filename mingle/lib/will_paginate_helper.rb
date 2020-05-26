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

module WillPaginateHelper
  # entries interface: count & paginate
  def paginate(entries, options={})
    raise "Should not include conditions in options" if options[:conditions]
    paginator = Paginator.create_with_current_page(entries.count, :page => options[:page] || params[:page])
    entries.paginate(options.merge(:total_entries => paginator.item_count, :per_page => paginator.items_per_page, :page => paginator.current_page))
  end

end
