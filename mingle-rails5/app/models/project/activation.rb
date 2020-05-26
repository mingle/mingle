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

class Project
  module Activation

    def self.included(base)
      base.class_eval do
        def self.clear_active_project!
          current.deactivate if activated?
        end

        def self.current_or_nil
          Thread.current['current_project']
        end

        def self.activated?
          Thread.current['current_project'] != nil
        end

        def self.current
          result = current_or_nil
          raise('No project activated') unless result
          result
        end

        def self.with_each_active_project(&block)
          find(:all, :conditions => ["hidden != ?", true]).shift_each! do |project|
            project.with_active_project(&block)
          end
        end

        def self.with_active_project(project_id)
          if project = Project.find_by_id(project_id)
            project.with_active_project do |project|
              yield(project)
            end
          end
        end
      end
    end

    # Makes this project the active one for this Ruby interpreter. Only one project
    # can be active at a time.
    def activate
      Thread.current['current_project'] = self
    end

    def deactivate
      unless @deactivate_callbacks.blank?
        @deactivate_callbacks.each(&:call)
        @deactivate_callbacks.clear
      end
      Thread.current['current_project'] = nil
    end

    def on_deactivate(&block)
      @deactivate_callbacks ||= []
      @deactivate_callbacks << block
    end

    def with_active_project
      previous_active_project = Thread.current['current_project']
      begin
        if previous_active_project
          previous_active_project.deactivate
        end
        activate
        yield(self)
      ensure
        deactivate
        if previous_active_project
          previous_active_project.activate
        end
      end
    end

    def with_card(number, &block)
      with_active_project do |project|
        if card = project.cards.find_by_number(number)
          yield(card)
        end
      end
    end
  end

end
