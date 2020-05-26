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

module CardView
  class UngroupLane
    include LaneSupport

    attr_reader :cards

    def initialize(project, cards, group)
      @project = project
      @cards = cards
      @group = group
    end

    def axis
      "lane"
    end

    def visible
      true
    end

    def title
      ""
    end

    def header_card(context = nil)
      nil
    end

    def html_id
      "ungrouped"
    end

    def identifier
      ""
    end
    alias :url_identifier :identifier
    alias :db_identifier :identifier

    def value
      ""
    end

    def cards
      @cards
    end

    def can_reorder?
      false
    end

    def can_hide?
      false
    end
  end
end
