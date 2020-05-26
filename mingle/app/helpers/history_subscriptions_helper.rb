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

module HistorySubscriptionsHelper
  
  def user_subscriptions_sorted_by_project(subscription_type)
    @subscriptions ||= @user.history_subscriptions.find(:all, :include => {:project => :tags}).smart_sort_by { |subscription| subscription.project.name }    
    @subscriptions.find_all(&:"#{subscription_type}?")
  end

  def filter_types_or_anything(filter_types)
    filter_types.blank? ? '(anything)' : filter_types.to_sentence(:last_word_connector => ' and ')
  end
  
  def involved_filter_as_sentence(subscription)
    filter_properties_and_tags_as_sentence(subscription.project, subscription.involved_filter_properties, subscription.involved_filter_tags)
  end
  
  def acquired_filter_as_sentence(subscription)
    filter_properties_and_tags_as_sentence(subscription.project, subscription.acquired_filter_properties, subscription.acquired_filter_tags)    
  end
  
  def filter_properties_and_tags_as_sentence(project, properties, tags)
    project.with_active_project do |project|
      list_of_properties = properties.map do |property, value|
        value = project.property_value(property,value).display_value if project.find_property_definition_or_nil(property)
        "#{property} is #{value.bold}"
      end
      
      result = (list_of_properties + [list_of_tags_as_sentence(tags)]).reject(&:blank?).map { |element| '<div>' + ERB::Util.h(element) + '</div>' }.join
      result = '(anything)' if result.blank?
      result.html_safe
    end
  end
  
  def list_of_tags_as_sentence(tags)
    return unless tags && tags.any?
    result = Array(tags).map { |tag| tag.bold }.to_sentence(:last_word_connector => ' and ')
    "Tagged with #{result}"
  end
  
  def link_to_unsubscribe(subscription, spinner_dom_id)
    link_to_remote 'Unsubscribe', :url => { :controller => 'history', :action => 'delete', :project_id => subscription.project.identifier, :id => subscription.id, :user_id => subscription.user_id },
                                  :before   => show_spinner(spinner_dom_id),
                                  :complete => hide_spinner(spinner_dom_id)
  end

end
