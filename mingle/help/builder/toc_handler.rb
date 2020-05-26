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

class TocHandler < ElementHandler
  @@file_root = {}

  attr_reader :current_entry_title

  def initialize(html, root)
    super(html, root)
  end

  def setCurrentEntryName(entryName)
    @current_entry_name = entryName
  end

  def handle_index(element)
    @html.element('ul', 'class' => 'toc') do
      apply(element)
    end
  end

  def handle_entry(element)
    @html.element('li') do
      ref = element.attributes['reference']
      actual_file = File.join(File.dirname(__FILE__), '..', 'topics', "#{ref}.xml")
      if File.exist?(actual_file)
        root = @@file_root[actual_file] ||= REXML::Document.new(File.new(actual_file)).root
        cssClass = ref == @current_entry_name ? 'current' : ''
        if ref == @current_entry_name
          @current_entry_title = root.attributes['title']
        end
        @html.element('a', {'href' => "#{ref}.html", 'class' => cssClass}){@html.text(root.attributes['title'])}
      else
        title = ref.gsub(/_/, ' ')
        title = title[0...1].upcase + title[1...-1]
        @html.element('a', 'href' => "under_construction.html"){@html.text(title)}
      end
      if element.elements.size > 0
        @html.element('ul') do
          apply(element)
        end
      else
        apply(element)
      end
    end
  end
end
