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

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class TabsTest < Test::Unit::TestCase

  class ControllerStub

    def initialize(project)
      @project = project
    end

    def card_context
      CardContext.new(@project, [])
    end
  end

  def test_all_tabs
    Project.find_by_identifier('mingle01').with_active_project do |project|
      controller = ControllerStub.new(project)
      100.downto(0) do
        tabs = DisplayTabs.new(project, controller)
        tabs.send(:collect_tabs)  #it's actually CardListView.consruct_from_params that is crazy slow
      end
    end
  end

end
