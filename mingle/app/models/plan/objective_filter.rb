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

class ObjectiveFilter < ActiveRecord::Base
  belongs_to :project
  belongs_to :objective
  serialize :params
  validates_uniqueness_of :project_id, :scope => :objective_id
  before_create :set_not_synced
  validate :validate_card_filter_params, :if => lambda {|filter| filter.params.present? }
  
  named_scope :for_project, lambda {|project| {:conditions => {:project_id => project.id}}}

  def self.sync
    conditions = (scope(:find) || {})[:conditions]
    with_scope(:find => {:conditions => conditions}) do
      all.each { |f| 
        f.sync_work && f.save!
      }
    end
  end

  def sync_work
    return false unless card_filter.valid?
    remove_mismatched_work
    add_matching_cards
    self.synced = true
  end

  def message
    Messaging::SendingMessage.new(:project_id => self.project_id)
  end

  def card_filter
    params[:filters] ? Filters.new(project, params[:filters]) : MqlFilters.new(project, params[:mql])
  end

  def url_params(options={})
    {:objective_id => objective.to_param, :project_id => project.identifier}.tap do |result|
      result.merge!(params) if valid?
      result.merge!(options)
    end
  end

  private
  def remove_mismatched_work
    objective.works.mismatch(query).bulk_delete
  end

  def add_matching_cards
    plan.assign_cards(project, query, objective)
  end

  def validate_card_filter_params
    project.with_active_project do |project|
      errors.add("params", card_filter.errors.join(", ")) unless card_filter.valid?
    end
  end

  def plan
    objective.program.plan
  end

  def query
    card_filter.as_card_query
  end

  def set_not_synced
    self.synced = false
    true
  end

end
