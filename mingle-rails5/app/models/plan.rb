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

class Plan < ActiveRecord::Base
  include Constants

  module Status
    PLANNED = 'PLANNED'
    BACKLOG = 'BACKLOG'
  end
  include Status

  belongs_to :program

  validates_presence_of :program
  validates_presence_of :start_at
  validates_presence_of :end_at
  validate :end_at_date_should_be_after_start_at_date, :if => Proc.new {|obj| obj.start_at && obj.end_at}
  before_validation :assign_default_plan_dates

  def plan_backlog_objective(objective)
    timeline_position = next_available_position
    objective.update_attributes(start_at: offset_date(Clock.now.beginning_of_month, 2, timeline_position),
                      end_at: offset_date(Clock.now.end_of_month, 6, timeline_position), vertical_position: timeline_position,
                      status: PLANNED)
    objective.send(:default_to_top_position)
    objective
  end

  def assign_default_plan_dates
    if (self.start_at.nil? && self.end_at.nil?)
      self.start_at = Clock.now - 1.month
      self.end_at = Clock.now + 11.months
    end
  end

  private

  def offset_date(default_date, offset_in_weeks, timeline_position)
    return default_date unless !program.objectives.newly_planned_objectives.empty? && timeline_position == VERTICALLY_MIDDLE_OF_TIMELINE
    latest_objective_start_at = program.objectives.newly_planned_objectives.sort{ |a, b| a.created_at <=> b.created_at }.collect(&:start_at).sort.last
    latest_objective_start_at.advance(:weeks => offset_in_weeks)
  end

  def next_available_position
    existing_objectives = existing_objective_information
    iterations = (TIMELINE_ROWS / 2) + 1
    iterations.times do |i|
      return position_above(i) unless (position_above(i) < 0) || occupied?(existing_objectives, position_above(i))
      return position_below(i) unless occupied?(existing_objectives, position_below(i))
    end
    VERTICALLY_MIDDLE_OF_TIMELINE
  end

  def position_above i
    VERTICALLY_MIDDLE_OF_TIMELINE - i
  end

  def position_below i
    VERTICALLY_MIDDLE_OF_TIMELINE + i
  end

  def position_occupied? existing_objectives, new_position
    existing_objectives.keys.include?(new_position)
  end

  def occupied? existing_objectives, new_position
    existing_objectives.keys.include?(new_position) && exists_in_current_month?(existing_objectives[new_position])
  end

  def in_current_month?(date)
    date.between?(Clock.now.beginning_of_month.to_date, Clock.now.end_of_month.to_date)
  end

  def existing_objective_information
    program.objectives.planned.in_current_month.all.each.inject(Hash.new) do |objective_info, o|
      objective_info[o.vertical_position] = {:start_at => o.start_at, :end_at => o.end_at}
      objective_info
    end
  end

  def exists_in_current_month?(existing_objective)
    in_current_month?(existing_objective[:start_at]) ||
      in_current_month?(existing_objective[:end_at]) ||
      (existing_objective[:start_at] < Clock.today.beginning_of_month && existing_objective[:end_at] > Clock.today.end_of_month)
  end

  def end_at_date_should_be_after_start_at_date
    errors.add(:end_at, "should be after start date") if start_at > end_at
  end

end
