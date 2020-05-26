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

class BacklogObjective < ActiveRecord::Base
  belongs_to :backlog
  auto_strip_attributes :name, nullify: false

  validates :name, presence: true, uniqueness: { scope: :backlog_id, case_sensitive: false, message: 'already used for an existing Objective in your Backlog.'}, length: {maximum: 80}
  validate :uniqueness_of_objective_name_in_plan
  after_create :default_to_top_position
  after_destroy :update_positions
  before_create :assign_number
  before_save :sanitize_value_statement
  after_find :format_text

  scope :after, ->(backlog_objective) { where("position > ?", backlog_objective.position) }

  default_scope -> { order(:position) }

  def uniqueness_of_objective_name_in_plan
    return if backlog.program.plan.nil?
    errors.add(:name, "already used for an existing Objective in your Plan.") if name_used_in_plan?
  end

  private
  def assign_number
    self.number ||= backlog.program.next_backlog_objective_number
  end

  def name_used_in_plan?
    backlog.program.plan.objectives.exists?(["lower(name) = ?", name.downcase])
  end

  def default_to_top_position
    all = backlog.backlog_objectives
      update_attribute(:position, 1)
      others = all - [self]
      others.each_with_index do |backlog_objective, index|
        backlog_objective.update_attribute(:position, index + 2)
      end
  end

  def update_positions
    backlog.backlog_objectives.after(self).each do |backlog_objective|
      backlog_objective.update_attribute(:position, backlog_objective.position - 1)
    end
  end

  def sanitize_value_statement
    self.value_statement = HtmlSanitizer.new.sanitize value_statement
  end

  def format_text
    return self unless self.respond_to?(:value_statement)
    return self if self.value_statement.blank?
    if Nokogiri.parse(self.value_statement).text.blank?
      self.value_statement = self.value_statement.split("\n").map do |line|
        line = line.gsub(/\s+/) do |white_spaces|
          white_spaces = "&nbsp;" * white_spaces.length if white_spaces.length > 1
          white_spaces
        end
        "<p>#{line}</p>"
      end.join("</br>")
    end
    self
  end
end
