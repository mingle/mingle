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

class ProgramProject < ActiveRecord::Base
  belongs_to :project
  belongs_to :program
  belongs_to :done_status, :class_name => 'EnumerationValue'
  belongs_to :status_property, :class_name => 'EnumeratedPropertyDefinition'

  validates_uniqueness_of :project_id, :scope => :program_id
  before_destroy :delete_work
  before_destroy :delete_objective_filters

  named_scope :using_status_property, lambda { |property_definition| { :conditions => { :status_property_id => property_definition.id } } }

  def works
    program.plan.works.created_from(self.project)
  end

  def mapping_configured?
    status_property.present?
  end
  
  def done_status_definition
    DoneStatusDefinition.new(completed_status_property_value) if completed_status_property_value
  end
  
  def completed?(card)
    return false unless self.mapping_configured?
    done_status_definition.includes?(status_property.value(card))
  end
  
  def completed_status_property_value
    if status_property
      PropertyValue.new(status_property, done_status.value)
    end
  end
  
  def refresh_completed_status_of_work!
    return unless mapping_configured?
    done_status = completed_status_property_value
    
    works.each do |work|
      project.with_active_project do |p|
        card = p.cards.find_by_number(work.card_number)
        work.completed = program.plan.work_completed?(project.cards.find_by_number(work.card_number))
        work.save if work.changed?
      end
    end
  end
  
  def update_completion_values
    if status_property_id.blank? || done_status_id.blank?
      Work.bulk_update("completed", false, SqlHelper.sanitize_sql('project_id = ? AND completed = ?', project_id, true))
    else
      reset_completion_value
      done_status_query = DoneStatusQuery.for(self)

      done_cards_subquery = <<-SQL
        SELECT #{connection.quote_column_name("number")} FROM #{project.cards_table}
          #{done_status_query.join_sql}
        WHERE #{done_status_query.where_condition}
      SQL

      cards_sql = <<-SQL
          UPDATE #{Work.table_name}
            SET completed = ?
          WHERE project_id = ? AND plan_id = ?
            AND card_number IN (#{done_cards_subquery})
      SQL

      connection.execute SqlHelper.sanitize_sql(cards_sql, true, project_id, program.plan.id)
    end

    works.map(&:objective).uniq.each do |objective|
      ObjectiveSnapshotProcessor.enqueue(objective.id, project_id)
    end
  end

  private
  
  def reset_completion_value
    reset_sql = <<-SQL
      UPDATE #{Work.table_name} SET completed = ?
        WHERE project_id = ? AND plan_id = ?
    SQL
    connection.execute SqlHelper.sanitize_sql(reset_sql, false, project_id, program.plan.id)
  end

  def delete_work
    Work.delete_all(:project_id => project_id, :plan_id => program.plan.id)
  end

  def delete_objective_filters
    program.objectives.planned.each do |objective|
      ObjectiveFilter.delete_all(:project_id => project_id, :objective_id => objective.id)
    end
  end
end
