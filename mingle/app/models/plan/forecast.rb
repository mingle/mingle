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

class Plan
  class Forecast
    HUNDRED_FIFTY_PERCENT_SCOPE_CHANGE = 2.5
    FIFTY_PERCENT_SCOPE_CHANGE = 1.5
    NO_SCOPE_CHANGE = 1.0

    class Base
      def to_json(options={})
        {
          :date => date,
          :no_velocity => no_velocity?,
          :late => late?,
          :scope => end_scope
        }.to_json(options)
      end
    end

    class Result < Base
      attr_reader :date, :deadline, :end_scope, :completed

      def initialize(forecasted_date, deadline, end_scope, completed)
        @date = forecasted_date
        @deadline = deadline
        @end_scope = end_scope
        @completed = completed
      end

      def no_velocity?
        false
      end

      def late?
        (@completed != @end_scope) && (@date && @date.beginning_of_day > @deadline.beginning_of_day)
      end
    end

    class NoVelocity < Base
      include Singleton
      def date; end
      def no_velocity?; true; end
      def late?; false; end
      def deadline; end
      def end_scope; end
    end

    extend Forwardable

    attr_reader :date

    def_delegator :@objective, :end_at, :end_date_of_objective

    def initialize(objective)
      @objective = objective
    end

    def for(project)
      snapshots = ObjectiveSnapshot.snapshots_till_date(@objective, project)
      
      velocity = Velocity.new(snapshots.map(&:completed), snapshots.map{|s| utc_time(s.dated).to_i })
      
      if velocity.invalid?
        {
          :name        => project.name.escape_html,
          :likely      => NoVelocity.instance,
          :less_likely => NoVelocity.instance,
          :not_likely  => NoVelocity.instance
        }
      else
        scope_values = snapshots.map(&:total)
        last_snapshot_date = utc_time(snapshots.last.dated)
        {
          :name        => project.name.escape_html,
          :likely      => convert(last_snapshot_date, *velocity.forecast(scope_values, HUNDRED_FIFTY_PERCENT_SCOPE_CHANGE)),
          :less_likely => convert(last_snapshot_date, *velocity.forecast(scope_values, FIFTY_PERCENT_SCOPE_CHANGE)),
          :not_likely  => convert(last_snapshot_date, *velocity.forecast(scope_values, NO_SCOPE_CHANGE))
        }
      end
    end

    def latest_date
      latest_completing_project = @objective.projects.max do |project1, project2|
        work_completion_date_for(project1) <=> work_completion_date_for(project2)
      end
      
      work_completion_date_for(latest_completing_project) if latest_completing_project
    end

    private
    def convert(last_snapshot_date, time_to_reach, end_scope, completed)
      Result.new(Time.at(last_snapshot_date.to_i + time_to_reach).utc.send(:to_date), end_date_of_objective, end_scope, completed)
    end
    
    def work_completion_date_for(project)
      self.for(project)[:not_likely].date || @objective.end_at
    end
    
    def utc_time(dated)
      ::Time.send("utc_time", dated.year, dated.month, dated.day)    
    end
  end
end
