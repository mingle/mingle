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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class CTATest < ActiveSupport::TestCase
  def setup
    @project = card_query_project
    @project.activate
    login_as_member
  end

  def test_can_parse_property_name_starting_with_is
    with_new_project do |project|
      setup_managed_text_definition('IsFaded', ['Yes', 'No', 'Maybe'])
      assert_equal ['=', 'IsFaded', 'Yes'], CTA.parse('where isfaded = Yes')
      assert_equal ['=', 'IsFaded', nil], CTA.parse('where isfaded is null')
      assert_equal ['!=', 'IsFaded', nil], CTA.parse('where isfaded is not null')
      assert_equal ['!=', 'IsFaded', 'No'], CTA.parse('where isfaded is not No')
      assert_equal ['!=', 'IsFaded', 'No'], CTA.parse('where isfaded not = No')
      assert_equal ['!=', 'IsFaded', 'Maybe'], CTA.parse('where IsFaded != Maybe')
    end
  end

  def test_enum_prop_value_comparison_falls_back_to_nil_on_invalid_value
    with_new_project do |project|
      setup_managed_text_definition('IsFaded', ['Yes', 'No', 'Maybe'])
      assert_equal ['=', 'IsFaded', nil], CTA.parse('where isfaded < Foo')
      assert_equal ['=', 'IsFaded', nil], CTA.parse('where isfaded <= Foo')
      assert_equal ['=', 'IsFaded', nil], CTA.parse('where isfaded > Foo')
      assert_equal ['=', 'IsFaded', nil], CTA.parse('where isfaded >= Foo')
    end
  end

  def test_only_output_where_condition
    assert_equal ['=', 'Status', 'new'], CTA.parse('select name from tree planning where status = new order by name')
    assert_equal nil, CTA.parse("select name as of '2010-01-11' group by name")
  end

  def test_or_condition
    expected = ['or', ['=', 'Feature', 'Applications'], ['=', 'Feature', 'Dashboard']]
    assert_equal expected, CTA.parse("where Feature = Applications OR Feature = 'Dashboard'")
  end

  def test_and_condition
    expected = ['and', ['=', 'Feature', 'Applications'], ['=', 'Feature', 'Dashboard']]
    assert_equal expected, CTA.parse("where Feature = Applications and Feature = 'Dashboard'")
  end

  def test_comparison_with_number_enum_prop
    assert_equal ['=', 'Size', '3'], CTA.parse('where Size = 3')
    assert_equal ['=', 'Size', '3'], CTA.parse('where Size is 3')
    assert_equal ['!=', 'Size', '3'], CTA.parse('where Size is not 3')
    assert_equal ['in', 'Size', ['4', '5']], CTA.parse('where Size > 3')

    expected = ['in', 'Size', [nil, '1', '2', '3']]
    assert_equal expected, CTA.parse('where Size <= 3')
  end

  def test_comparison_with_text_enum_prop
    assert_equal ['=', 'Status', 'Done'], CTA.parse('where Status is Done')
    assert_equal ['!=', 'Status', 'Done'], CTA.parse('where Status is not Done')

    assert_equal ['=', 'Status', 'Closed'], CTA.parse('where Status > Done')

    expected = ['in', 'Status', ['New', 'In Progress', 'Done', 'Closed']]
    assert_equal expected, CTA.parse('where Status > null')
    assert_equal false, CTA.parse('where Status > Closed')

    assert_equal ['=', 'Status', 'Closed'], CTA.parse('where Status >= Closed')
    assert_equal ['in', 'Status', ['Done', 'Closed']], CTA.parse('where Status >= Done')

    expected = ['in', 'Status', [nil, 'New', 'In Progress', 'Done', 'Closed']]
    assert_equal expected, CTA.parse('where Status >= null')

    expected = ['in', 'Status', [nil, 'New', 'In Progress']]

    assert_equal expected, CTA.parse('where Status < Done')
    assert_equal ['=', 'Status', nil], CTA.parse('where Status < New')
    assert_equal false, CTA.parse('where Status < null')

    expected = ['in', 'Status', [nil, 'New', 'In Progress', 'Done']]
    assert_equal expected, CTA.parse('where Status <= Done')

    expected = ['in', 'Status', [nil, 'New']]
    assert_equal expected, CTA.parse('where Status <= New')
    assert_equal ['=', 'Status', nil], CTA.parse('where Status <= null')
  end

  def test_comparison_with_text_free_prop
    assert_equal ['=', 'freetext1', 'hello world'], CTA.parse("where freetext1 = 'hello world'")
  end

  def test_expand_in_cond
    assert_equal ['in', 'freetext1', ['hello', 'world']], CTA.parse('where freetext1 in (hello, world)')
  end

  def test_comparison_with_card_data_type_plv
    related_card_property = @project.find_property_definition('related card')
    card = @project.cards.first
    @plv = create_plv!(@project,
                       :name => 'favorite - card',
                       :value => nil,
                       :data_type => ProjectVariable::CARD_DATA_TYPE,
                       :property_definition_ids => [related_card_property.id])

    expected = ['=', 'related card', nil]
    assert_equal expected, CTA.parse("where 'related card' = (favorite - card)")

    @plv.value = card.id
    @plv.save!
    @project.reload

    expected = ['=', 'related card', card]
    assert_equal expected, CTA.parse("where 'related card' = (favorite - card)")
  end

  def test_comparison_with_string_data_type_plv
    status = @project.find_property_definition('Status')
    @plv = create_plv!(@project,
                       :name => 'favorite',
                       :value => nil,
                       :data_type => ProjectVariable::STRING_DATA_TYPE,
                       :property_definition_ids => [status.id])

    expected = ['=', 'Status', nil]
    assert_equal expected, CTA.parse('where Status = (favorite)')

    @plv.value = 'Done'
    @plv.save!
    @project.reload

    expected = ['=', 'Status', 'Done']
    assert_equal expected, CTA.parse('where Status = (favorite)')

    expected = ['in', 'Status', [nil, 'New', 'In Progress']]
    assert_equal expected, CTA.parse('where Status < (favorite)')
  end

  def test_comparison_with_date_data_type_plv
    date_created = @project.find_property_definition('date_created')
    @project.date_format = Date::YEAR_MONTH_DAY
    @plv = create_plv!(@project,
                       :name => 'favorite',
                       :value => nil,
                       :data_type => ProjectVariable::DATE_DATA_TYPE,
                       :property_definition_ids => [date_created.id])

    expected = ['=', 'date_created', nil]
    assert_equal expected, CTA.parse('where date_created = (favorite)')

    ['01/24/2008', '24 Jan 2008', '2008/01/24'].each do |plv_value|
      @plv.value = plv_value
      @plv.save!
      @project.reload

      expected = ['=', 'date_created', Date.parse('2008-01-24')]
      assert_equal expected, CTA.parse('where date_created = (favorite)')
    end
  end

  def test_comparison_with_numeric_type_plv
    est = @project.find_property_definition('Size')
    @plv = create_plv!(@project,
                       :name => 'favorite',
                       :value => nil,
                       :data_type => ProjectVariable::NUMERIC_DATA_TYPE,
                       :property_definition_ids => [est.id])

    expected = ['=', 'Size', nil]
    assert_equal expected, CTA.parse('where Size = (favorite)')

    @plv.value = 3
    @plv.save!
    @project.reload

    expected = ['=', 'Size', '3']
    assert_equal expected, CTA.parse('where Size = (favorite)')
  end

  def test_comparison_with_date_user_type_plv
    owner = @project.find_property_definition('owner')
    @plv = create_plv!(@project,
                       :name => 'favorite',
                       :value => nil,
                       :data_type => ProjectVariable::USER_DATA_TYPE,
                       :property_definition_ids => [owner.id])

    expected = ['=', 'owner', nil]
    assert_equal expected, CTA.parse('where owner = (favorite)')

    @plv.value = User.current.id
    @plv.save!
    @project.reload

    expected = ['=', 'owner', User.current]
    assert_equal expected, CTA.parse('where owner = (favorite)')
  end

  def test_user_property
    expected = ['=', 'owner', User.find_by_login('member')]
    assert_equal expected, CTA.parse('where owner = member')

    expected = ['=', 'owner', nil]
    assert_equal expected, CTA.parse('where owner is null')

    expected = ['=', 'owner', User.current]
    assert_equal expected, CTA.parse('where owner is current user')
  end

  def test_card_property
    card = @project.cards.first
    expected = ['=', 'related card', card]
    assert_equal expected, CTA.parse("where 'related card' = NUMBER #{card.number}")
    assert_equal expected, CTA.parse("where 'related card' = #{card.name.inspect}")
    assert_raise CTA::UnsupportedSyntax do
      assert_equal expected, CTA.parse("where 'related card' numbers in (#{card.number})")
    end
  end

  def test_date_property
    expected = ['=', 'date_created', nil]
    assert_equal expected, CTA.parse('where date_created is null')
    expected = ['=', 'date_created', Date.parse('2015-01-22')]
    assert_equal expected, CTA.parse('where date_created = 2015-01-22')

    expected = ['=', 'date_created', Date.today]
    assert_equal expected, CTA.parse('where date_created = today')
  end
end
