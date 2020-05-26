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

class TransitionsExporter < BaseDataExporter

  def name
    'Transitions'
  end

  def export(sheet)
    index = 1
    sheet.add_headings(sheet_headings)
    Project.current.transitions.order_by_name.each do |transition|
      restriction_info = restriction_info(transition)
      required_properties_and_values = required_properties_and_values(transition)
      actions_and_values = actions_and_values(transition)
      sheet.insert_row(index, [transition.name, transition_card_type(transition),
                               restriction_info[:restriction],
                               restriction_info[:restricted_to],
                               transition.require_comment ? 'Yes': 'No' ,
                               required_properties_and_values[:properties],
                               required_properties_and_values[:values],
                               actions_and_values[:properties],
                               actions_and_values[:values]]
                      )
      index = index.next
    end
    Rails.logger.info("Exported transitions to sheet")
  end

  def exportable?
    Project.current.transitions.count > 0
  end

  private
  def transition_card_type(transition)
    return '(any)' if transition.card_type.nil?
    transition.card_type.name
  end

  def headings
    ['Transition name', 'Card type', 'Restriction', 'Restricted to', 'Require murmur', 'Properties as pre-conditions to the transition', 'Initial property values', 'Properties to be set on transition', 'Final property values']
  end

  def restriction_info(transition)
    group_prerequisites = transition.group_prerequisites
    user_prerequisites = transition.user_prerequisites

    if group_prerequisites.any?
      {:restriction => 'Select groups', :restricted_to => group_prerequisites.map { |prereq| prereq.group.name }.join("\n")}
    else
      user_prerequisites.any? ? {:restriction => 'Select members', :restricted_to => user_prerequisites.map { |prereq| prereq.user.name }.join("\n")} : {:restriction => 'All team members', :restricted_to => ''}
    end
  end

  def required_properties_and_values(transition)
    return {:properties => "Any value for any property", :values => ''} if transition.required_properties.empty? && transition.card_type == nil
    properties = transition.display_required_properties.map { |property| property.name}.join("\n")
    values = transition.display_required_properties.map { |property| property.display_value}.join("\n")
    {:properties => properties, :values => values}
  end

  def actions_and_values(transition)
    properties = transition.actions.map { |property| property.display_name}.join("\n")
    values = transition.actions.map { |property| property.display_value}.join("\n")
    {:properties => properties, :values => values}
  end
end
