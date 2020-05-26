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

class LiveFiltersTest < ActiveSupport::TestCase
  def setup
    @project = card_query_project
    @project.activate
    login_as_member
  end

  def test_user_property
    expected = ["=", "owner", User.find_by_login("member").id.to_s]
    assert_equal expected, LiveFilters.parse("where owner = member")

    expected = ["=", "owner", nil]
    assert_equal expected, LiveFilters.parse("where owner is null")

    expected = ["=", "owner", User.current.id.to_s]
    assert_equal expected, LiveFilters.parse("where owner is current user")
  end

  def test_card_property
    card = @project.cards.first
    expected = ["=", "related card", card.id.to_s]
    assert_equal expected, LiveFilters.parse("where 'related card' = NUMBER #{card.number}")
    assert_equal expected, LiveFilters.parse("where 'related card' = #{card.name.inspect}")
  end

  def test_date_property
    expected = ["=", "date_created", nil]
    assert_equal expected, LiveFilters.parse("where date_created is null")
    expected = ["=", "date_created", "2015-01-22"]
    assert_equal expected, LiveFilters.parse("where date_created = 2015-01-22")

    expected = ["=", "date_created", Date.today.to_s]
    assert_equal expected, LiveFilters.parse("where date_created = today")
  end

  def test_comparison_with_plv
    setup_card_plv
    setup_user_plv
    @project.reload

    expected = [
                 "and",
                   ["=", "related card", @project.cards.first.id.to_s],
                   ["=", "owner", User.current.id.to_s]
               ]
    assert_equal expected, LiveFilters.parse("where 'related card' = (favorite - card) and owner = (favorite)")
  end

  private

  def setup_card_plv
    related_card_property = @project.find_property_definition("related card")
    card = @project.cards.first
    create_plv!(@project,
      :name => "favorite - card",
      :value => card.id,
      :data_type => ProjectVariable::CARD_DATA_TYPE,
      :property_definition_ids => [related_card_property.id])
  end

  def setup_user_plv
    owner = @project.find_property_definition("owner")
    create_plv!(@project,
      :name => "favorite",
      :value => User.current.id,
      :data_type => ProjectVariable::USER_DATA_TYPE,
      :property_definition_ids => [owner.id])
  end

end
