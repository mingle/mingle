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

module Api
  class BacklogObjectivesController < PlannerApplicationController
    before_action :ensure_objective_exists, only: [:show, :destroy, :update]
    privileges UserAccess::PrivilegeLevel::LIGHT_READONLY_TEAM_MEMBER => [:show]

    def show
      render json: @backlog_objective.to_params
    end

    def destroy
      @backlog_objective.destroy ? head(:no_content) : render(json: @backlog_objective.errors, status: :unprocessable_entity)
    end

    def update
      values = params[:backlog_objective]
      values[:value_statement].delete!("\r") if values[:value_statement]
      if @backlog_objective.update_attributes(backlog_objective_params)
        render json: @backlog_objective.to_params
      else
        render json: @backlog_objective.errors.full_messages.join("\n"), status: :unprocessable_entity
      end
    end

    def plan
      @backlog_objective = @program.objectives.backlog.find_by_number(params[:number])
      head(:not_found) and return unless  @backlog_objective
      planned_objective = @program.plan.plan_backlog_objective(@backlog_objective)
      render json: {'redirect_url': program_plan_index_path(@program.identifier,planned_objective: planned_objective.name)}, status: :ok
    end

    def change_plan
      planned_objective = @program.objectives.planned.find_by_number(params[:number])
      head(:not_found) and return unless  planned_objective
      render json: {'redirect_url': program_plan_index_path(@program.identifier,planned_objective: planned_objective.name)}, status: :ok
    end

    def reorder
      @program.reorder_objectives(params[:ordered_backlog_objective_numbers])
      render json: @program.objectives.all_objectives, only: [:name, :number, :position, :status]
    end

    def create
      @backlog_objective = @program.objectives.backlog.create(backlog_objective_params.except(:property_definitions))

      if @backlog_objective.valid?
        @backlog_objective.create_property_value_mappings(backlog_objective_params[:property_definitions])
        render json: @backlog_objective.to_params
      else
        render json: @backlog_objective.errors.full_messages.join("\n"), status: :unprocessable_entity
      end
    end

    private

    def ensure_objective_exists
      @backlog_objective = @program.objectives.find_by_number(params[:number])
      head(:not_found) unless  @backlog_objective
    end

    def backlog_objective_params
      objective_params = params.require(:backlog_objective).permit(:name, :value_statement)
      objective_params[:property_definitions] = params[:backlog_objective][:property_definitions]
      objective_params
    end
  end
end
