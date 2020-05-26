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

class ObjectiveSnapshot < ActiveRecord::Base
  def self.enqueue_snapshot_for(plan)
    plan.program.objectives.started_before(Clock.now.beginning_of_day).each do |objective|
      plan.program.projects_with_work_in(objective).each do |project|
        ObjectiveSnapshotProcessor.enqueue(objective.id, project.id)
      end
    end
  end

  def self.rebuild_snapshots_for(objective_id, project_id)
    objective = Objective.find_by_id objective_id
    unless objective
      Rails.logger.warn("Abandoning snapshot rebuild for objective #{objective_id} because it no longer exists")
      return
    end
    project = Project.find project_id

    (objective.start_at.to_date..Clock.now.yesterday.to_date).to_a.each do |date|
      create_snapshot_for objective, project, date
    end
  end
  
  def self.create_snapshot_for(objective, project, date, plan=objective.program.plan)
    new_snapshot = take_from_version(objective, project, date, plan)
    return unless new_snapshot
    return if new_snapshot.work_completed_and_previous_snapshots_already_completed?
    new_snapshot.save!
  end

  def self.take_from_version(objective, project, as_of, plan=objective.program.plan)
    total = plan.works.scheduled_in(objective).created_from(project).as_of(as_of).count
    completed = recalculate_completed(plan, objective, project, as_of)

    new_snapshot = self.new(:objective => objective, :project => project, :total => total, :completed => completed, :dated => as_of)

    existing = objective.objective_snapshots.find_by_project_id_and_dated(project.id, as_of)

    return new_snapshot unless existing
    return if new_snapshot.eql?(existing)
    existing.total = total
    existing.completed = completed
    existing
  end

  def self.recalculate_completed(plan, objective, project, as_of)
    if plan.program.program_projects.find_by_project_id(project.id).mapping_configured?
      plan.works.scheduled_in(objective).created_from(project).completed_as_of(plan, project, as_of).count
    else
      0
    end
  end

  def self.current_state(objective, project)
    program = objective.program
    total = program.plan.works.scheduled_in(objective).created_from(project).count
    completed = 0

    if program.program_projects.find_by_project_id(project.id).mapping_configured?
      completed = program.plan.works.scheduled_in(objective).created_from(project).completed.count
    end

    new_snapshot = self.new(:objective => objective, :project => project, :total => total, :completed => completed, :dated => Clock.today)
  end

  def self.snapshots_till_date(objective, project)
    snapshots = objective.ordered_snapshots(project)
    latest_snapshot = current_state(objective, project)
    append_latest_snapshot(snapshots, latest_snapshot)
    snapshots
  end

  def self.append_latest_snapshot(snapshots, current_snapshot)
    unless current_snapshot.work_completed_and_previous_snapshots_already_completed?
      snapshots << current_snapshot
    end
  end

  belongs_to :objective
  belongs_to :project

  validates_presence_of :total, :completed
  
  def work_completed?
    total != 0 && completed != 0 && total == completed
  end
  
  def eql?(other_snapshot)
    if other_snapshot
      dated == other_snapshot.dated &&
      total == other_snapshot.total &&
      completed == other_snapshot.completed &&
      objective_id == other_snapshot.objective_id &&
      project_id == other_snapshot.project_id
    end
  end

  def same_state?(other_snapshot)
    other_snapshot.total == self.total && other_snapshot.completed == self.completed if other_snapshot
  end

  def work_completed_and_previous_snapshots_already_completed?
    previous_snapshot = objective.ordered_snapshots(project).last
    return work_completed? && previous_snapshot.work_completed? && same_state?(previous_snapshot) if previous_snapshot
    false
  end

end
