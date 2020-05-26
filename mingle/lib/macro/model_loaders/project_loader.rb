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

module MingleModelLoaders
  class ProjectLoader
    def initialize(project, macro_context=nil, alert_receiver=nil)
      @project = project
      @macro_context = macro_context
      @alert_receiver = alert_receiver
    end

    def project
      @proj ||= load
    end

    def load
      project = Mingle::Project.new(@project, :content_provider => @macro_context[:content_provider], :alert_receiver => @alert_receiver)
      project.card_types_loader = CardTypesLoader.new(@project)
      project.property_definitions_loader = PropertyDefinitionsLoader.new(@project)
      project.team_loader = TeamLoader.new(@project)
      project.project_variables_loader = ProjectVariablesLoader.new(@project)
      project
    end
  end
end
