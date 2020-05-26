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
  class Row
    attr_reader :cells
    attr_accessor :visible
    delegate :url_identifier, :db_identifier, :identifier, :header_card, :to => :first_cell

    def initialize(project, group)
      @project = project
      @group = group
      @cells = []
      @visible = false
    end

    def axis
      "row"
    end

    # no cell, no row
    def first_cell
      @cells[0]
    end

    def title
      @cells[0].header
    end

    def <<(cell)
      @cells << cell
    end

    def cards
      @cells.collect(&:cards).flatten
    end

    def aggregate_value
      Aggregate.value(@project, @group.to_params, :row, cards)
    end

    def html_id
       "row_#{Digest::MD5::new.update(db_identifier.to_s)}"
    end

    def can_hide?
      @group.supports_direct_manipulation?(:row) && !sole_row?
    end

    def can_reorder?
      false
    end

    private

    def sole_row?
      @group.visibles(:row).map(&:identifier) == [self.identifier]
    end

  end
end
