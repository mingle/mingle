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

require File.expand_path(File.dirname(__FILE__) + '/../../../unit_test_helper')

class ProjectCardQueryTest < ActiveSupport::TestCase
  def test_select_user_property
    login_as_admin
    with_new_project do |project|
      member = User.find_by_login('member')
      project.add_member(member)

      setup_user_definition("dev")

      create_card!(:name => 'card1', :dev => member.id)
      assert_equal [{'dev' => 'member@email.com (member)'}], query('select dEV where name = "card1"', :select_all)
      assert_equal [{'dev' => 'member@email.com (member)', 'created by' => 'admin@email.com (admin)'}], query('select dEV, "created by" where name = "card1"', :select_all)
    end
  end

  def test_user_property_as_condition
    login_as_admin
    with_new_project do |project|
      member = User.find_by_login('member')
      project.add_member(member)
      project.add_member(User.current)

      setup_user_definition("dev")

      create_card!(:name => 'card1', :dev => member.id)
      create_card!(:name => 'card2', :dev => User.current.id)
      create_card!(:name => 'card3', :dev => User.current.id)
      assert_equal [{'dev' => 'member@email.com (member)'}], query('SELECT DEV WHERE DEV = MEMBER', :select_all)
      assert_equal ['card1'], query('select name where dev = member').sort
      assert_equal ['1'], query('select count(*) where dev = member or dev = something')
      assert_equal ['2'], query('select count(*) where dev != member')
      assert_equal ['1'], query('select count(*) where dev != property "created by"')
      assert_equal ['2'], query('select count(*) where dev = property "modified by"')
    end
  end

  def test_current_user
    login_as_bob
    with_new_project do |project|
      member = User.find_by_login('member')
      project.add_member(member)

      bob = User.find_by_login('bob')
      project.add_member(bob)

      setup_user_definition("dev")

      create_card!(:name => 'card1', :dev => member.id)
      create_card!(:name => 'card2', :dev => bob.id)
      assert_equal [{'dev' => 'bob@email.com (bob)'}], query('SELECT DEV WHERE DEV = current user', :select_all)
      assert_equal [{'dev' => 'bob@email.com (bob)'}], query('SELECT DEV WHERE DEV = "current user"', :select_all)
      assert_equal ["card1"], query('select name where dev != current user').sort
      assert_equal ["card1"], query('select name where dev != "current user"').sort
    end
  end

  def test_should_be_invalid_when_compare_user_property_by_lt_gt_lteq_gteq_operator
    login_as_admin
    with_new_project do |project|
      member = User.find_by_login('member')
      project.add_member(member)

      setup_user_definition("dev")

      create_card!(:name => 'card1', :dev => member.id)
      lt_gt_lteq_gteq {|op| assert_operator_validation_error('dev', op) }
    end
  end

  def test_select_text_free_property
    login_as_admin
    with_new_project do |project|
      setup_text_property_definition("id")

      create_card!(:name => 'card1', :id => 'something')
      assert_equal ['something'], query('select id where name = "card1"')
    end
  end

  def test_free_text_property_as_condition
    login_as_admin
    with_new_project do |project|
      setup_text_property_definition("id")

      create_card!(:name => 'card1', :id => 'something')
      create_card!(:name => 'card2', :id => nil)
      assert_equal ['id' => 'something'], query('select ID where id = SOMETHING', :select_all)

      assert_equal ['card1'], query('select name where id = SOMETHING')
      assert_equal ['card1'], query('select name where id > SOME')
      assert_equal ['card1'], query('select name where id >= SOMETHING')
      assert_equal ['card1'], query('select name where id <= SOMETHING')
      assert_equal [],        query('select name where id < SOME')
      assert_equal ['1'], query('select count(*) where id = something or id = somethingelse')
      assert_equal ['1'], query('select count(*) where id != something')
      assert_equal ['2'], query('select count(*) where id != haha')
      assert_equal ['0'], query('select count(*) where id != property id')
      assert_equal ['2'], query('select count(*) where id = property id')
    end
  end

  def test_select_card_type
    login_as_admin
    with_new_project do |project|
      create_card!(:name => 'card1')
      assert_equal ['Card'], query('select type where name = "card1"')
    end
  end

  def test_card_type_as_condition
    login_as_admin
    with_new_project do |project|
      project.card_types.create!(:name => 'Story')
      project.card_types.create!(:name => 'Task')
      create_card!(:name => 'card1', :card_type_name => 'Card')
      create_card!(:name => 'card2', :card_type_name => 'Story')
      create_card!(:name => 'card3', :card_type_name => 'Task')

      assert_equal [{'type' => 'Story'}],  query('select TYPE where type = story', :select_all)
      assert_equal ['card1'], query('select name where type = card')
      assert_equal ['card3'], query('select name where type > Story')
      assert_equal ['card3'], query('select name where type >= task')
      assert_equal [],        query('select name where type > task')
      assert_equal ['card1'], query('select name where type <= Card')
      assert_equal ['card1'], query('select name where type < Story')
      assert_equal ['2'], query('select count(*) where type = story or type = card')
      assert_equal ['2'], query('select count(*) where type != story')
    end
  end

  def test_card_type_value_validation
    with_new_project do |project|
      assert_raise EnumeratedPropertyDefinition::ValueRestrictedException do
        query("select number where type = haha")
      end
    end
  end

  def test_enum_prop_value_validation
    with_new_project do |project|
      setup_managed_text_definition("Priority", ["lol", "roflmao"])
      assert_raise EnumeratedPropertyDefinition::ValueRestrictedException do
        query("select number where Priority > haha")
      end
    end
  end

  def test_select_any_number_prop
    login_as_admin
    with_new_project do |project|
      setup_numeric_text_property_definition('sid')
      create_card!(:name => 'card1', :sid => 1, :number => 1)
      assert_equal ['1'], query('select sid')
    end
  end

  def test_any_number_prop_in_where_cond
    login_as_admin
    with_new_project do |project|
      setup_numeric_text_property_definition('sid')
      create_card!(:name => 'card1', :sid => 1, :number => 1)
      create_card!(:name => 'card2', :sid => 2, :number => 3)
      assert_equal [{'sid' => '1'}],  query('select SID where sid = 1', :select_all)
      assert_equal ['card1'], query('select name where sid = 1')
      assert_equal ['card2'], query('select name where sid > 1.00')
      assert_equal ['card2'], query('select name where sid >= 2.000')
      assert_equal ['card1'], query('select name where sid <= 1.00')
      assert_equal [],        query('select name where sid < 1')
      assert_equal ['2'], query('select count(*) where sid = 1 or sid = 2')
      assert_equal ['1'], query('select count(*) where sid != 2')
      assert_equal ['2'], query('select count(*) where sid != 3')
      assert_equal ['1'], query('select count(*) where sid != property "number"')
      assert_equal ['1'], query('select count(*) where sid = property "number"')
      assert_raise Plan::Query::ProjectCardValidator::Error do
        query("select count(*) where sid = haha")
      end
    end
  end

  def test_numeric_formula_prop
    login_as_admin
    with_new_project do |project|
      setup_numeric_text_property_definition('sid')
      setup_formula_property_definition('sid plus one', 'sid + 1')
      create_card!(:name => 'card1', :sid => 1, :number => 1)
      create_card!(:name => 'card2', :sid => 2, :number => 3)
      assert_equal [{"sid plus one" => '2'}],  query('select "sid PLUS one" where "sid plus one" = 2', :select_all)
      assert_equal ['card1'], query('select name where "sid plus one" = 2')
      assert_equal ['card2'], query('select name where "sid plus one" > 2')
      assert_equal ['card2'], query('select name where "sid plus one" >= 3')
      assert_equal ['card1'], query('select name where "sid plus one" <= 2')
      assert_equal [],        query('select name where "sid plus one" < 2')
      assert_equal ['2'],     query('select count(*) where "sid plus one" = 2 or "sid plus one" = 3')
      assert_equal ['1'],     query('select count(*) where "sid plus one" != 3')
      assert_equal ['2'],     query('select count(*) where "sid plus one" != 5')
      assert_equal ['1'],     query('select count(*) where "sid plus one" != property "number"')
      assert_equal ['2'],     query('select count(*) where "sid plus one" != property sid')
      assert_equal ['1'],     query('select count(*) where "sid plus one" = property "number"')
      assert_raise Plan::Query::ProjectCardValidator::Error do
        query("select count(*) where 'sid plus one' = haha")
      end
    end
  end

  def test_date_formula_prop
    login_as_admin
    with_new_project do |project|
      setup_date_property_definition('date')
      setup_formula_property_definition('date plus one', 'date + 1')
      create_card!(:name => 'card1', :date => Date.parse('2010-10-21 00:00:00'), :number => 1)
      create_card!(:name => 'card2', :date => Date.parse('2010-10-22 00:00:00'), :number => 3)

      assert_equal [{"date plus one" => '2010-10-22'}],  query('select "date PLUS one" where "date plus one" = "2010-10-22"', :select_all)
      assert_equal ['card1'],       query('select name where "date plus one" = "2010-10-22"')
      assert_equal ['card2'],       query('select name where "date plus one" > "2010-10-22"')
      assert_equal ['card2'],       query('select name where "date plus one" >= "2010-10-23"')
      assert_equal ['card1'],       query('select name where "date plus one" <= "2010-10-22"')
      assert_equal [],              query('select name where "date plus one" < "2010-10-22"')
      assert_equal ['2'],           query('select count(*) where "date plus one" = "2010-10-22" or "date plus one" = "2010-10-23"')
      assert_equal ['1'],           query('select count(*) where "date plus one" != "2010-10-23"')
      assert_equal ['2'],           query('select count(*) where "date plus one" != "2010-10-25"')
      assert_equal ['2'],           query('select count(*) where "date plus one" < today')
      # CardQuery does not support the following mql, but good to have, right?
      assert_equal ['2'],           query('select count(*) where "date plus one" != property date')
      assert_equal ['0'],           query('select count(*) where "date plus one" = property date')

      create_card!(:name => 'card3', :date => nil, :number => 5)
      assert_equal ['2'],           query('select count(*) where "date plus one" != null')
      assert_equal ['1'],           query('select count(*) where "date plus one" = null')
    end
  end

  def xtest_card_prop
    login_as_admin
    with_new_project do |project|
      setup_card_relationship_property_definition('related card')
      card1 = create_card!(:name => 'card1')
      card2 = create_card!(:name => 'card2', :'related card' => card1.id)
      create_card!(:name => 'card3', :'related card' => card2.id)

      assert_equal [{"related card" => 'card1'}], query('select "RELATED Card" where "Related Card" = card1', :select_all)
      assert_equal ['card2'], query('SELECT NAME WHERE "RELATED CARD" = CARD1')
      assert_equal ['2'], query('select count(*) where "Related Card" = card1 or "Related Card" = card2')
      assert_equal ['0'], query('select count(*) where "Related Card" = card1 and "Related Card" = card2')
      assert_equal ['2'], query('select count(*) where "Related Card" != card1')
    end
  end

  def test_should_be_invalid_when_compare_card_property_by_lt_gt_lteq_gteq_operator
    login_as_admin
    with_new_project do |project|
      setup_card_relationship_property_definition('related card')
      lt_gt_lteq_gteq {|op| assert_operator_validation_error('related card', op) }
    end
  end

  def xtest_tree_prop
    login_as_admin
    with_three_level_tree_project do |project|
      assert_equal [{"planning iteration" => 'iteration1'}], query('select "PLANNING iteration" where "Planning iteration" = iteration1 and name=story1', :select_all)

      assert_equal ['2'], query('SELECT COUNT(*) WHERE "PLANNING ITERATION" = ITERATION1')
      assert_equal ['0'], query('select count(*) where "Planning iteration" = iteration2')
      assert_equal ['2'], query('select count(*) where "Planning iteration" = iteration1 or "Planning iteration" = iteration2')
      assert_equal ['0'], query('select count(*) where "Planning iteration" = iteration1 and "Planning iteration" = iteration2')
      assert_equal ['3'], query('select count(*) where "Planning iteration" != iteration1')
    end
  end

  def test_tree_aggregate_prop
    login_as_admin
    with_three_level_tree_project do |project|
      @sum_of_size = project.find_property_definition('sum of size')
      project.cards.each do |card|
        value = @sum_of_size.compute_card_aggregate_value(card)
        @sum_of_size.update_card(card, value)
        card.save!
      end

      assert_equal [{"sum of size" => '4'}], query('select "SUM of size" where "Sum of size" = 4', :select_all)

      assert_equal ['1'], query('SELECT COUNT(*) WHERE "SUM OF SIZE" = 4')
      assert_equal ['0'], query('SELECT COUNT(*) WHERE "Sum of size" < 4')
      assert_equal ['0'], query('SELECT COUNT(*) WHERE "Sum of size" > 4')
      assert_equal ['4'], query('SELECT COUNT(*) WHERE "Sum of size" != 4')
      assert_equal ['1'], query('SELECT COUNT(*) WHERE "Sum of size" <= 4')
      assert_equal ['1'], query('SELECT COUNT(*) WHERE "Sum of size" >= 4')
      assert_equal ['5'], query('SELECT COUNT(*) WHERE "Sum of size" != 1')
      assert_equal ['5'], query('SELECT COUNT(*) WHERE "Sum of size" != 0')
      assert_equal ['0'], query('SELECT COUNT(*) WHERE "Sum of size" = 0')
      assert_equal ['4'], query('SELECT COUNT(*) WHERE "Sum of size" is null')
    end
  end

  def test_select_2_same_aggregate_function_with_different_properties
    login_as_admin
    with_new_project do |project|
      setup_numeric_property_definition("Release", [1, 2, 3])

      create_card!(:name => "card1")
      create_card!(:name => "card2")

      assert_equal [{'max(release)' => nil, 'max(number)' => '2'}], query('select max(Release), max(number)', :select_all)
      assert_equal [{'count(*)' => '2', 'count(number)' => '2'}], query('select count(*), count(number)', :select_all)
    end
  end

  def test_should_be_invalid_to_compare_2_unmatched_data_type_properties
    login_as_admin
    with_new_project do |project|
      setup_numeric_property_definition("status", [1,2,3])
      assert_raise Plan::Query::ProjectCardValidator::Error do
        query("select count(*) where name = property status")
      end
    end
  end

  def test_verify_numeric_property_value
    with_new_project do |project|
      setup_numeric_property_definition("Release", [1, 2, 3])
      assert_raise Plan::Query::ProjectCardValidator::Error do
        query("select count(*) where Release = haha")
      end
    end
  end

  def test_verify_date_property_value
    with_new_project do |project|
      setup_date_property_definition("start date")
      assert_raise Plan::Query::ProjectCardValidator::Error do
        query("select count(*) where start date = haha")
      end
    end
  end

  def test_hidden_prop
    login_as_admin
    with_new_project do |project|
      setup_managed_text_definition("status", %w(new open done))

      create_card!(:name => "card1")
      create_card!(:name => "card2")
      create_card!(:name => "card3", :status => "open")

      status = project.find_property_definition('status')
      status.update_attribute(:hidden, true)
      project.reload
      assert_equal ['2'], query("select count(*) where status is null")
      assert_equal ['1'], query("select count(*) where status = 'open'")
    end
  end

  def lt_gt_lteq_gteq
    yield('>')
    yield('>=')
    yield('<')
    yield('<=')
  end

  def assert_operator_validation_error(prop_name, op)
    assert_raise Plan::Query::ProjectCardValidator::Error do
      query("select count(*) where #{prop_name.inspect} #{op} member")
    end
  end

  def query(mql, selection=:single_values) #:select_all
    pql= create_query(mql).sql_ast

    selector = Plan::Query::Selector.new(Plan.connection, create_query(mql), self)
    puts selector.sql if $debug
    if selection == :single_values
      selector.single_values
    else
      selector.values
    end
  end

  def format_date(date)
    Project.current.format_date(date)
  end

  def format_number(number)
    number.to_s.to_num(Project.current.precision).to_s
  end

  def create_query(mql)
    Plan::Query::ProjectCardQuery.new(Mql.parse(mql), Project.current)
  end

end
