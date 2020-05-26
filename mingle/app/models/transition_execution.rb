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

class TransitionExecution
  include ::API::XMLSerializer
    
  attr_accessor :status
  
  v1_serializes_as :complete => [:id, :status]
  v2_serializes_as :complete => [:status]
    
  def initialize(project, attrs)
    @attrs = attrs || {}
    @status = 'new'
    if @attrs[:card].is_a?(Card)
      @card = @attrs[:card]
    elsif @attrs[:card]
      @card = project.cards.find_by_number(@attrs[:card])
    end
    @transition = load_transition(project, @attrs)
    @properties = @attrs[:properties] ? convert(@attrs[:properties]) : {}
    @comment = @attrs[:comment]
  end
    
  def id
    -1
  end

  def process!
    process
    if errors.any?
      raise errors.full_messages.join("; ")
    end
  end
  
  def process
    if validate
      @transition.execute_with_validation(@card, @properties, {:content => @comment})
      if @transition.errors.empty?
        @status = 'completed'
      else
        @transition.errors.full_messages.each do |message|
          errors.add_to_base message
        end
      end
    end
  end
  
  def validate
    if @card.nil?
      if @attrs[:card]
        errors.add_to_base "Couldn't find card by number #{@attrs[:card]}."
      else
        errors.add_to_base "Must provide number of card to execute transition on."
      end
    end
    if @transition.nil?
      if @attrs[:transition]
        errors.add_to_base "Couldn't find transition by name #{@attrs[:transition]}."
      elsif @attrs[:id]
        errors.add_to_base "Couldn't find transition with id #{@attrs[:id]}."
      else
        errors.add_to_base "Must specify transition to execute."
      end
    end
    errors.empty?
  end
  
  def errors
    @errors ||= ActiveRecord::Errors.new(self)
  end
  
  private
  
  def load_transition(project, attrs)
    raise "Should not supply both transition id and transition name." if attrs[:transition] && attrs[:id]
    if attrs[:transition]
      attrs[:transition].is_a?(String) ? load_transition_by_name(project, attrs[:transition]) : attrs[:transition]
    else
      load_transition_by_id(project, attrs[:id])
    end
  end
  
  def load_transition_by_name(project, name)
    project.transitions.find(:first, :conditions => ["LOWER(#{::Transition.table_name}.name) = LOWER(?)", name])
  end
  
  def load_transition_by_id(project, id)
    project.transitions.find_by_id(id)
  end

  def convert(properties)
    properties.inject({}) do |map, property|
      property.stringify_keys!
      map[property['name']] = property['value']
      map
    end
  end
end
