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
  include HasManyWorks
  include Query
  include Constants

  belongs_to :program

  has_many :works, :dependent => :destroy

  validates_presence_of :start_at
  validates_presence_of :end_at
  validates_presence_of :program
  validate :end_at_date_should_be_after_start_at_date, :if => Proc.new {|obj| obj.start_at && obj.end_at}
  validate :plan_length_should_contain_all_objectives
  before_save :round_start_and_end_date
  before_validation :assign_default_plan_dates

  strip_on_write
  date_attributes :start_at, :end_at

  def assign_default_plan_dates
    if (self.start_at.nil? && self.end_at.nil?)
      self.start_at = Clock.now - 1.month
      self.end_at = Clock.now + 11.months
    end
  end

  def plan_length_should_contain_all_objectives
    objective_with_late_start_at = program.objectives.planned.select { |objective| objective.start_at < start_at }.sort {|o1,o2| o1.end_at <=> o2.end_at}.first
    errors.add(:start_at, "is later than Feature #{objective_with_late_start_at.name.bold} start date of #{format_date(objective_with_late_start_at.start_at).bold}. Please select an earlier date.") if objective_with_late_start_at

    objective_with_early_end_at = program.objectives.planned.select { |objective| objective.end_at > end_at }.sort {|o1,o2| o1.end_at <=> o2.end_at}.last
    errors.add(:end_at, "is earlier than Feature #{objective_with_early_end_at.name.bold} end date of #{format_date(objective_with_early_end_at.end_at).bold}. Please select an later date.") if objective_with_early_end_at
  end

  def end_at_date_should_be_after_start_at_date
    errors.add(:end_at, "should be after start date") if start_at > end_at
  end

  def date_format
    DATE_FORMAT
  end

  def format_date(date)
    date.blank? ? "" : date.strftime(self.date_format).strip
  end

  # this method rounds the start date to the closest monday before, and rounds
  # the end date to the closest sunday after, such that we have whole weeks.
  def round_start_and_end_date
    number_of_days_from_monday = (self.start_at.cwday - 1)
    number_of_days_to_sunday = (7 - self.end_at.cwday)
    self.start_at = self.start_at - number_of_days_from_monday
    self.end_at = self.end_at + number_of_days_to_sunday
  end

  def timeline_objectives
    self.program.objectives.planned.map { |objective| TimelineObjective.from(objective, self) }
  end

  def plan_backlog_objective(objective)
    timeline_position = next_available_position
    attrs = {:start_at => offset_date(Clock.now.beginning_of_month, 2, timeline_position),
             :end_at => offset_date(Clock.now.end_of_month, 6, timeline_position), :vertical_position => timeline_position,
             :status => Objective::Status::PLANNED}
    objective.update_attributes(attrs)
    objective.send(:default_to_top_position)

  end

  def next_available_position_between(start_date, end_date)
    existing_objectives = program.objectives.planned.between_dates(start_date, end_date).inject(Hash.new) do |objective_info, o|
      objective_info[o.vertical_position] = {:start_at => o.start_at, :end_at => o.end_at}
      objective_info
    end

    iterations = (TIMELINE_ROWS / 2) + 1
    iterations.times do |i|
      return position_above(i) unless (position_above(i) < 0) || position_occupied?(existing_objectives, position_above(i))
      return position_below(i) unless position_occupied?(existing_objectives, position_below(i))
    end
    VERTICALLY_MIDDLE_OF_TIMELINE
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

  def exists_in_current_month?(existing_objective)
    in_current_month?(existing_objective[:start_at]) ||
    in_current_month?(existing_objective[:end_at]) ||
    (existing_objective[:start_at] < Clock.today.beginning_of_month && existing_objective[:end_at] > Clock.today.end_of_month)
  end

  def existing_objective_information
    program.objectives.planned.in_current_month.all.each.inject(Hash.new) do |objective_info, o|
      objective_info[o.vertical_position] = {:start_at => o.start_at, :end_at => o.end_at}
      objective_info
    end
  end

end
