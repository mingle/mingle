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

class Deletion::Effect
  attr_reader :target_model
  
  def initialize(target_model, options={})
    @target_model = target_model
    @options = options
    raise "Cannot define a effect with both :count and :collection option absent" if count.nil?
  end
  
  def additional_notes
    @options[:additional_notes]
  end
  
  def collection
    @options[:collection]
  end
  
  def count
    @options[:count] || (collection && collection.size)
  end
  
  def render
    ("Used by #{@target_model.name.enumerate(count).bold}" << render_collection_info << render_action << '.' << render_additional_notes).html_safe
  end
  
  private
  
  def render_collection_info
    collection ? ": #{ collection.collect(&:name).sorted_bold_sentence }" : ""
  end
  
  def render_additional_notes    
    additional_notes ? " <div class=\"bullet-qualifier\">#{additional_notes}</div>" : ""
  end
  
  def render_action
    @options[:action] ? ". #{count > 1 ? 'These' : 'This'} will be #{@options[:action]}" : ""
  end
end
