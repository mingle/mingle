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

module HistoryHelper
  include FeedHelper, NotificationHelper
    
  ATOM_STYLE_CHANGED = "background-color: LightGoldenRodYellow;"
  
  def url_for_current_history_page
    url_for(@history.to_params.merge(:page => @history.current_page))
  end
  
  def options_for_team
    @project.users.collect{|member| [member.name, member.id]}
  end  

  def link_to_period(period, options = params)
    description = History::NAMED_PERIODS[period].description.humanize
    comment_tag = History::NAMED_PERIODS[period].comment.blank? ? '' : content_tag('span', History::NAMED_PERIODS[period].comment, {:class => 'notes'})
    content = (description + comment_tag).html_safe
    if (@period != period)
      link_to(content, options.merge(:action => 'index', :period => period, :page => 1), {:class => 'history-link'})
    else
      content_tag('span', content, {:class => 'current'})
    end
  end
  
  def include_cards?
    (params['filter_types'] || {}).member?('cards')
  end  
  
  def include_pages?
    (params['filter_types'] || {}).member?('pages')
  end  
  
  def include_revisions?
    (params['filter_types'] || {}).member?('revisions')
  end  
  
  def tags_in(tags_and_values)
    tag_names = tags_and_values.select { |name| Tag.valid_tag?(name) }
    tag_names.collect do |name| 
      @project.tag_named(name)
    end.compact  
  end
  
  def property_definitions_for_filter(card_type_name=nil)
    if card_type_name
      @project.property_definitions_of_card_type(card_type_name).select(&:finite_valued?).reject(&:calculated?)
    else
      @project.property_definitions_in_smart_order.select(&:finite_valued?).reject(&:calculated?).unshift @project.card_type_definition
    end
  end
end
