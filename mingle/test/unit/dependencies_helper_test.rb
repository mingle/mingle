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

require File.expand_path("../unit_test_helper", File.dirname(__FILE__))

#include ApplicationHelper, CardsHelper, ActionView::Helpers::JavaScriptHelper, ActionView::Helpers::TagHelper, ActionView::Helpers::FormTagHelper, ActionView::Helpers::FormOptionsHelper, TreeFixtures::PlanningTree, ActionView::Helpers::TextHelper

class DependenciesHelperTest < ActionView::TestCase
  include DependenciesHelper

  def test_formatted_date_returns_not_set_if_no_date_exists
    assert_equal("(not set)", formatted_date(nil, first_project))
  end

  def test_formatted_date_returns_unformatted_date_when_project_does_not_exist
    date = Date.today
    assert_equal(date, formatted_date(date, nil))
  end

  def test_formatted_date_returns_date_in_project_format
    date = Date.parse("01-01-2015")
    project = Project.new(:name => "foo", :identifier => "foo_bar", :date_format => Date::DAY_LONG_MONTH_YEAR)
    assert_equal("01 Jan 2015", formatted_date(date, project))
  end
end
