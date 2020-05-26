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

class Entry
  attr_accessor :related_cards
  
  def initialize(event)
    @event = event
  end
  
  def updated
    @event.created_at
  end
  
  def author
    @event.author
  end
  
  def title
    "#{@event.origin_description} #{@event.action_description}".strip
  end
  
  def content_xml(view_helper, options={})
    options[:indent] ||= 2
    xml = options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])
    xml.changes :xmlns => Mingle::API.ns do
      xml.change :type => creation_category if @event.creation?
      @event.changes.sort_by(&:feed_category).each do |change|
        change.to_xml(:builder => xml, :skip_instruct => true, :api_version => 'v2', :view_helper => view_helper)
      end
    end
  end
  
  def categories
    result = @event.changes.collect(&:feed_category).flatten.sort
    result.unshift(creation_category) if @event.creation?
    result.unshift(@event.source_type)
    result.uniq
  end
  
  def related_card_numbers
    @__related_card_numbers ||= @event.changes.collect(&:related_card_numbers).flatten.collect(&:to_i)      
  end
  
  def id
    @event.id
  end
  
  def source_link
    @event.source_link
  end
  
  def version_link
    @event.version_link
  end
  
  private
  def creation_category
    "#{@event.source_type}-#{@event.creation_category}"
  end
end
