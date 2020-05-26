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

module FeedsHelper
  def write_atom_link(xml, href, rel, type, title)
    options = {:href => href, :rel => rel, :type => type}
    options = options.merge(:title => title) if title
    xml.link(options)
  end

  def write_entry_links(xml, resource_link, rel)
    return unless resource_link

    if href = resource_link.xml_href(self, 'v2')
      write_atom_link(xml, href, rel, 'application/vnd.mingle+xml', resource_link.title)
    end

    if href = resource_link.html_href(self)
      write_atom_link(xml, href, rel, 'text/html', resource_link.title)
    end
  end
end
