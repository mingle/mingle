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

class Work < ActiveRecord::Base

  belongs_to :plan, :class_name => '::Plan'
  belongs_to :objective, :class_name => '::Objective'
  belongs_to :project, :class_name => '::Project'
  named_scope :created_from, lambda { |project| { :conditions => { :project_id => project.id } } }
  named_scope :scheduled_in, lambda { |objective| { :conditions => { :objective_id => objective.id } } }
  named_scope :completed, :conditions => { :completed => true }

  self.resource_link_route_options = proc {|work| { :number => work.card_number, :project_id => work.project.identifier } }

  validates_presence_of :project

  v2_serializes_as :complete => [:completed, [:card_number, {:element_name => 'number'}], :project],
                   :compact => [:completed, [:card_number, {:element_name => 'number'}], :project],
                   :element_name => 'card'

  named_scope :created_from_card, lambda { |card| { :conditions => { :card_number => card.number, :project_id => card.project_id } } }
  named_scope :created_from_cards, lambda { |project, query|
    { :conditions => { :project_id => project.id }, :joins => "INNER JOIN (#{query.find_card_numbers_sql}) card_numbers ON works.card_number = card_numbers.#{Work.connection.quote_column_name('number')}" }
  }
  named_scope :mismatch, lambda {|query| {:conditions => ["project_id = ? AND card_number not in (#{query.find_card_numbers_sql})", query.project.id]}}
  named_scope :completed_as_of, lambda { |plan, project, date|
      beginning_of_tomorrow = connection.datetime_insert_sql((date.tomorrow).to_s(:db))
      done_status_query = DoneStatusQuery.for(plan.program.program_project(project))
      quoted_number_column = connection.quote_column_name('number')

      # by aliasing the card_versions table as the cards table, we can reuse the
      # generated join_sql from DoneStatusQuery. this is most certainly a hack,
      # but it works for now.
      cards_table = project.cards_table

      join_sql = <<-SQL
      inner join (
        select m.#{quoted_number_column}
          from (
                select max(v.version) latest, v.#{quoted_number_column}
                  from #{project.card_versions_table} v
                 where v.updated_at < #{beginning_of_tomorrow}
              group by v.#{quoted_number_column}
               ) m,
               (
                select version, #{quoted_number_column}
                  from #{project.card_versions_table} #{cards_table}
             #{done_status_query.join_sql}
                 where #{done_status_query.where_condition}
               ) d
         where m.#{quoted_number_column} = d.#{quoted_number_column}
           and m.latest = d.version
      ) as_of
      on as_of.#{quoted_number_column} = works.card_number
      SQL

      {
        :joins => join_sql,
        :conditions => ["project_id = ? AND plan_id = ?", project.id, plan.id]
      }
    }
  named_scope :as_of, lambda { |date|
    beginning_of_tomorrow = (date.tomorrow).to_s(:db)
    {
      :conditions => "created_at < #{connection.datetime_insert_sql(beginning_of_tomorrow)}"
    }
  }

  before_create :copy_card_attributes
  validates_uniqueness_of :card_number, :scope => [:plan_id, :project_id, :objective_id]
  validate :validate_card_relationship_is_valid, :if => Proc.new { |work| work.project }

  def validate_card_relationship_is_valid
    project.with_active_project do
      card = project.cards.find_by_number(card_number)
      errors.add(:card_number, "##{card_number} does not exist") unless card
      errors.add(:card_name, "#{name.bold} does not match #{card.name.bold}") if card && card.name != name
    end
  end

  def copy_card(card)
    self.name = card.name
    self.completed = plan.work_completed?(card)
  end

  def auto_sync?
    ObjectiveFilter.exists?(:objective_id => objective_id, :project_id => project_id)
  end

  def in(objectives)
    objectives.map(&:id).include?(objective_id)
  end

  private
  def copy_card_attributes
    if self.card_number
      project.with_card(card_number) do |card|
        self.copy_card(card)
      end
    end
    # have to return true, otherwise won't save
    true
  end

end
