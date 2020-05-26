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

class ConnectionTest < ActiveSupport::TestCase

  def setup
    @connection = ActiveRecord::Base.connection
  end

  def test_explain_sql
    with_first_project do |proj|
      r = @connection.explain(CardQuery.parse("SELECT name, count(*) GROUP BY name ORDER BY name").to_sql)
      for_oracle do
        assert_match /SORT GROUP BY/, r
      end
      for_postgresql do
        assert_match /GroupAggregate/, r
      end
    end
  end

  def test_should_not_raise_error_when_explain_failed
    assert_nil @connection.explain("create table HELLOWORLD (id number(38,0) not null primary key)", true)
    assert_nil @connection.explain("explain plan for\nselect haha wrong sql", true)

    assert_nil @connection.explain("select haha wrong sql", false)
  end

  def test_indexes
    for_oracle do
      indexes = @connection.indexes('deliverables').sort_by(&:name)
      assert_equal ["INDEX_PROJ2B8C5459FE63E6A1", "INDEX_PROJ5B4BF876347668A8"], indexes.map(&:name)
      assert_equal([["NAME", "TYPE"], ["IDENTIFIER", "TYPE"]], indexes.map{|i|i.columns.sort})
    end
  end

  def test_remove_index_should_only_remove_existing_index
    assert_nil @connection.remove_index(User.table_name, "index_not_exist")
  end

  def test_add_index_should_only_add_non_existing_index
    assert_nil @connection.add_index(User.table_name, :login)
  end

  def test_quote_column_will_quote_table_name_and_column_name_independently
    assert_equal "tablename.#{@connection.quote_column_name('column_name')}", @connection.quote_column_name("tablename.column_name")
  end

  def test_quote_column_name_accepts_symbols
    for_postgresql do
      assert_equal "\"column_name\"", @connection.quote_column_name(:column_name)
    end
  end

  def test_quote_column_will_quote_when_just_column_name_passed_in
    for_postgresql do
      assert_equal "\"column_name\"", @connection.quote_column_name("column_name")
    end
  end

  def test_quoting_a_column_name_twice_does_not_double_quote_it
    for_postgresql do
      assert_equal "\"column_name\"", @connection.quote_column_name(@connection.quote_column_name("column_name"))
    end
  end

  def test_as_padded_number_sticks_zeroes_on_the_end_of_decimal_areas
    for_postgresql do
      assert_equal "0.6700", @connection.select_value("SELECT #{@connection.as_padded_number("'0.67'", 4)}")
    end

    for_oracle do
      assert_equal "0.6700", @connection.select_value("SELECT #{@connection.as_padded_number("'0.67'", 4)} FROM dual")
    end
  end

  def test_quote_order_by_should_both_quote_column_and_table_name
    for_oracle do
      assert_equal "\"NUMBER\"", @connection.quote_order_by("number")
      assert_equal "\"NUMBER\" asc", @connection.quote_order_by("number asc")

      assert_equal "#{@connection.quote_table_name("mi_1235376313_property_definitions")}.name asc",
            @connection.quote_order_by("mi_1235376313_property_definitions.name asc")

      assert_equal "#{@connection.quote_table_name("mi_1235376313_property_definitions")}.name",
            @connection.quote_order_by("mi_1235376313_property_definitions.name")
    end
  end

  def test_quote_table_name_should_not_quote_again_when_it_is_already_quoted
    for_oracle do
      assert_equal '"TABLE_NAME"', @connection.quote_table_name('"TABLE_NAME"')
    end
  end

  def test_should_limit_max_precision_to_38
    assert_equal 38, @connection.max_precision
  end

  # Bug 6532. New sequences created in migration must be set to have is_called to true.
  def test_create_sequence_has_is_called_flag_turned_to_true
    for_postgresql do
      ActiveRecord::Base.connection.create_sequence('badri_seq', 1234)
      values = ActiveRecord::Base.connection.select_all "SELECT * FROM badri_seq"
      assert_equal '1235', ActiveRecord::Base.connection.select_value("SELECT nextval('badri_seq')")
    end
  end

  def test_sequence_exists
    sequence_name = "foo".uniquify[0..8]
    assert_false @connection.sequence_exists?(sequence_name)
    @connection.create_sequence(sequence_name, 1)
    assert @connection.sequence_exists?(sequence_name)
  end

  def test_cards_table_options_returns_correct_create_table_options
    assert_equal({}, ActiveRecord::Base.connection.cards_table_options)
  end

  def test_bulk_insert
    member1 = create_user!
    member2 = create_user!
    with_first_project do |project|
      @connection.bulk_insert(UserMembership, [
                                               {'user_id' => member1.id, 'group_id' => project.team.id},
                                               {'user_id' => member2.id, 'group_id' => project.team.id}
                                              ])
      project.reload
      assert project.member?(member1)
      assert project.member?(member2)
    end
  end

end
