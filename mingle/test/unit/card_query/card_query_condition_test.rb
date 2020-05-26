# -*- coding: utf-8 -*-

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


require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class CardQueryConditionTest < ActiveSupport::TestCase
  def setup
    @project = card_query_project
    @project.activate
    @member = login_as_member
  end

	def test_collect_columns_from_condition
    card_query = CardQuery.parse("WHERE iteration > '1' AND (iteration < '3' OR status = 'done' OR tagged with 'magic')")
    assert_equal ['Iteration', 'Status'], card_query.conditions.columns.map(&:name).uniq
	end
end
