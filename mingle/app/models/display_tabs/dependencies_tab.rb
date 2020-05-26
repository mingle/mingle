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

class DisplayTabs

  class DependenciesTab < PredefinedTab

    NAME = 'Dependencies'

    def name
      NAME
    end

    def initialize(project, controller)
      super(project, "d", "dependencies-tab")
      @session = controller.session
    end

    def params
      {:controller => "dependencies", :action => "index", :project_id => @project.identifier}
    end

    def counter
      count = @project.new_waiting_resolving_count
      count >= 1 ? count : nil
    end

    def tooltip
      "#{counter} new #{'dependency'.plural(counter)} to accept"
    end

  end
end
