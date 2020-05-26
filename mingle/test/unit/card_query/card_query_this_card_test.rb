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

class CardQueryThisCardTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    @project = card_query_project
    @project.activate
    login_as_member
    @card = @project.cards.find_by_number(1)
  end

  def teardown
    Clock.reset_fake
  end

  def test_this_card_property_returns_correct_values
    this_card = create_card! :name => 'Uno', :size => '2'
    assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE size = THIS CARD.size", :content_provider => this_card).values
  end

  def test_this_card_property_should_work_with_hidden_properties
    with_new_project do |project|
      setup_allow_any_text_property_definition 'hidden_size', :hidden => true
      this_card = create_card! :name => 'Uno', :hidden_size => '2'
      assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE hidden_size = THIS CARD.hidden_size", :content_provider => this_card).values
    end
  end

  def test_this_card_predefined_integer_properties_can_be_used
    this_card = create_card!(:name => 'Blah')
    assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE number = THIS CARD.number", :content_provider => this_card).values
  end

  def test_this_card_predefined_text_properties_can_be_used
    this_card = create_card!(:name => 'Blah')
    assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE name = THIS CARD.name", :content_provider => this_card).values
  end

  def test_this_card_predefined_date_properties_can_be_used
    Clock.fake_now :year => 2007, :month => 1, :day => 1
    create_card! :name => 'Uno'
    Clock.fake_now :year => 2007, :month => 1, :day => 2
    this_card = create_card!(:name => 'Uno')
    assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE 'created on' = THIS CARD.'created on'", :content_provider => this_card).values
  end

  def test_this_card_predefined_user_properties_can_be_used
    login_as_proj_admin
    this_card = create_card!(:name => 'Uno')
    assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE 'created by' = THIS CARD.'created by'", :content_provider => this_card).values
  end

  def test_this_card_predefined_card_type_property_can_be_used
    with_new_project do |project|
      setup_card_types project, :names => %w{good bad}
      create_card! :card_type => 'bad', :name => 'Uno'
      this_card = create_card!(:card_type => 'good', :name => 'Uno')
      assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE Type = THIS CARD.Type", :content_provider => this_card).values
    end
  end

  def test_this_card_property_can_make_date_comparisons
    this_card = create_card! :name => 'Un', :date_created => '02/05/2007'
    assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE date_created = THIS CARD.date_created", :content_provider => this_card).values
  end

  def test_this_card_property_works_on_card_versions
    this_card = create_card! :name => 'Un'
    this_card.update_attribute(:name, 'Deux')
    assert_equal [], CardQuery.parse("SELECT number WHERE name = THIS CARD.name", :content_provider => this_card.reload.versions.first).values
  end

  def test_this_card_property_fails_nicely_when_comparing_date_properties_to_numeric_properties
    this_card = create_card! :name => 'Un', :date_created => '02/05/2009'
    assert_raise_message(CardQuery::DomainException, "Property #{'Size'.bold} is numeric, and value #{'02 May 2009'.bold} is not numeric. Only numeric values can be compared with #{'Size'.bold}.") do
      CardQuery.parse("SELECT number WHERE size = THIS CARD.date_created", :content_provider => this_card).values
    end
  end

  def test_this_card_property_can_make_user_comparisons
    bob = User.find_by_login('bob')
    @project.add_member(bob)
    this_card = create_card! :name => 'Un'
    owner = @project.find_property_definition("owner")
    owner.update_card(this_card, bob.id)
    this_card.save
    assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE owner = THIS CARD.owner", :content_provider => this_card).values
  end

  def test_this_card_property_fails_nicely_when_comparing_user_properties_to_numeric_properties
    bob = User.find_by_login('bob')
    @project.add_member(bob)
    this_card = create_card! :name => 'Un'
    owner = @project.find_property_definition("owner")
    owner.update_card(this_card, bob.id)
    this_card.save
    assert_raise_message(CardQuery::DomainException, "Property #{'Size'.bold} is numeric, and value #{'bob'.bold} is not numeric. Only numeric values can be compared with #{'Size'.bold}.") do
      CardQuery.parse("SELECT number WHERE size = THIS CARD.owner", :content_provider => this_card).values
    end
  end

  def test_this_card_property_can_compare_using_card_relationship_property_numbers_in
    other_card = create_card! :name => 'onree'
    this_card = create_card! :name => 'Un', :'related card' => other_card.id
    assert_equal [{ 'Number' => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE 'related card' NUMBERS IN (THIS CARD.'related card')", :content_provider => this_card).values
  end

  def test_this_card_property_can_compare_using_card_relationship_property
    other_card = create_card! :name => 'onree'
    this_card = create_card! :name => 'Un', :'related card' => other_card.id

    card_query = CardQuery.parse("SELECT number WHERE 'related card' is THIS CARD.'related card'", :content_provider => this_card)
    assert_equal [{ 'Number' => this_card.number.to_s }], card_query.values
  end

  def test_this_card_property_works_when_property_value_is_null_and_used_with_equality_operator
    this_card = create_card! :name => 'Un', :priority => nil
    assert_include({ "Number" => this_card.number.to_s }, CardQuery.parse("SELECT number WHERE priority = THIS CARD.priority", :content_provider => this_card).values)
  end

  def test_this_card_property_fails_with_a_helpful_error_message_when_property_value_is_null_and_used_in_in_clause
    this_card = create_card! :name => 'Un', :priority => nil
    assert_raise_message(CardQuery::DomainException, "The value of THIS CARD.Priority is NULL and cannot be used in an IN or NUMBERS IN clause.") do
      CardQuery.parse("SELECT number WHERE priority IN (THIS CARD.priority, low)", :content_provider => this_card).values
    end
  end

  def test_this_card_property_fails_with_a_pleasant_error_message_when_property_value_in_numbers_in_clause_is_null
    this_card = create_card! :name => 'Un', :'related card' => nil
    assert_raise_message(CardQuery::DomainException, "The value of THIS CARD.'related card' is NULL and cannot be used in an IN or NUMBERS IN clause.") do
      CardQuery.parse("SELECT number WHERE 'related card' NUMBERS IN (THIS CARD.'related card')", :content_provider => this_card).values
    end
  end

  def test_this_card_property_fails_nicely_when_comparing_date_properties_to_card_relationship_properties_IN_clause
    this_card = create_card! :name => 'Un', :date_created => '03/26/2010'
    assert_raise_message(CardQuery::DomainException, "Property #{'related card'.bold} is card, and value #{'26 Mar 2010'.bold} is not card. Only card values can be compared with #{'related card'.bold}.") do
      CardQuery.parse("SELECT number WHERE 'related card' NUMBERS IN (THIS CARD.date_created)", :content_provider => this_card).values
    end
  end

  def test_in_this_card_property_returns_correct_values
    this_card = create_card! :name => 'Uno', :size => '2'
    assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE size IN (1, THIS CARD.size, 3)", :content_provider => this_card).values
  end

  def test_this_card_property_raise_exception_when_used_in_wiki_page
    assert_raise_message(CardQuery::DomainException, /THIS CARD.Size is not a supported macro for page./) do
      CardQuery.parse("SELECT number WHERE 'size' IN (THIS CARD.size)", :content_provider => @project.pages.create!(:name => 'foo'))
    end
  end

  def test_this_card_property_shows_alert_when_used_in_card_defaults_using_in_clause
    alert_receiver = MockAlertReceiver.new
    some_card_defaults = @project.card_types.first.card_defaults
    CardQuery.parse("SELECT number WHERE 'size' IN (THIS CARD.size)", :content_provider => some_card_defaults, :alert_receiver => alert_receiver).values rescue nil
    assert_equal ["Macros using THIS CARD.Size will be rendered when card is created using this card default."], alert_receiver.alerts
  end

  def test_this_card_property_works_with_a_formula_property_that_is_of_type_date
    with_new_project do |project|
      setup_date_property_definition('start_date')
      setup_formula_property_definition('date formula', 'start_date + 2')
      this_card = create_card! :name => "I am card", :start_date => '11 Dec 2009'

      assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE 'date formula' = THIS CARD.'date formula'", :content_provider => this_card).values
      assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE 'date formula' IN (THIS CARD.'date formula')", :content_provider => this_card).values
    end
  end

  def test_this_card_property_works_with_a_formula_property_that_is_of_type_number
    this_card = create_card! :name => "I am card", :size => 2

    assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE half = THIS CARD.half", :content_provider => this_card).values
    assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE half IN (THIS CARD.half)", :content_provider => this_card).values
  end

  def test_this_card_property_gives_pleasant_error_message_when_comparing_number_with_a_date
    this_card = create_card! :name => "I am card", :size => 2, :date_created => '07 Dec 1941'

    assert_raise_message(CardQuery::DomainException, "Property #{'half'.bold} is numeric, and value #{'07 Dec 1941'.bold} is not numeric. Only numeric values can be compared with #{'half'.bold}.") do
      CardQuery.parse("SELECT number WHERE half = THIS CARD.date_created", :content_provider => this_card).values
    end
    assert_raise_message(CardQuery::DomainException, "Property #{'half'.bold} is numeric, and value #{'07 Dec 1941'.bold} is not numeric. Only numeric values can be compared with #{'half'.bold}.") do
      CardQuery.parse("SELECT number WHERE half IN (THIS CARD.date_created)", :content_provider => this_card).values
    end
  end

  def test_this_card_property_returns_correct_values
    this_card = create_card! :name => 'Uno', :size => '2'
    assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE size = THIS CARD.size", :content_provider => this_card).values
  end

  def test_this_card_property_can_make_date_comparisons
    this_card = create_card! :name => 'Un', :date_created => '02/05/2009'
    assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE date_created = THIS CARD.date_created", :content_provider => this_card).values
  end

  def test_this_card_property_works_on_card_versions
    this_card = create_card! :name => 'Un'
    this_card.update_attribute(:name, 'Deux')
    assert_equal [], CardQuery.parse("SELECT number WHERE name = THIS CARD.name", :content_provider => this_card.reload.versions.first).values
  end

  def test_this_card_property_fails_nicely_when_comparing_date_properties_to_numeric_properties
    this_card = create_card! :name => 'Un', :date_created => '02/05/2009'
    assert_raise_message(CardQuery::DomainException, "Property #{'Size'.bold} is numeric, and value #{'02 May 2009'.bold} is not numeric. Only numeric values can be compared with #{'Size'.bold}.") do
      CardQuery.parse("SELECT number WHERE size = THIS CARD.date_created", :content_provider => this_card).values
    end
  end

  def test_this_card_property_can_make_user_comparisons
    bob = User.find_by_login('bob')
    @project.add_member(bob)
    this_card = create_card! :name => 'Un'
    owner = @project.find_property_definition("owner")
    owner.update_card(this_card, bob.id)
    this_card.save
    assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE owner = THIS CARD.owner", :content_provider => this_card).values
  end

  def test_this_card_property_fails_nicely_when_comparing_user_properties_to_numeric_properties
    bob = User.find_by_login('bob')
    @project.add_member(bob)
    this_card = create_card! :name => 'Un'
    owner = @project.find_property_definition("owner")
    owner.update_card(this_card, bob.id)
    this_card.save
    assert_raise_message(CardQuery::DomainException, "Property #{'Size'.bold} is numeric, and value #{'bob'.bold} is not numeric. Only numeric values can be compared with #{'Size'.bold}.") do
      CardQuery.parse("SELECT number WHERE size = THIS CARD.owner", :content_provider => this_card).values
    end
  end

  def test_this_card_property_can_compare_using_card_relationship_property_numbers_in
    other_card = create_card! :name => 'onree'
    this_card = create_card! :name => 'Un', :'related card' => other_card.id
    assert_equal [{ 'Number' => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE 'related card' NUMBERS IN (THIS CARD.'related card')", :content_provider => this_card).values
  end

  def test_this_card_property_works_when_property_value_is_null_and_used_with_equality_operator
    this_card = create_card! :name => 'Un', :priority => nil
    assert_include({ "Number" => this_card.number.to_s }, CardQuery.parse("SELECT number WHERE priority = THIS CARD.priority", :content_provider => this_card).values)
  end

  def test_this_card_property_fails_with_a_helpful_error_message_when_property_value_is_null_and_used_in_in_clause
    this_card = create_card! :name => 'Un', :priority => nil
    assert_raise_message(CardQuery::DomainException, "The value of THIS CARD.Priority is NULL and cannot be used in an IN or NUMBERS IN clause.") do
      CardQuery.parse("SELECT number WHERE priority IN (THIS CARD.priority, low)", :content_provider => this_card).values
    end
  end

  def test_this_card_property_fails_with_a_pleasant_error_message_when_property_value_in_numbers_in_clause_is_null
    this_card = create_card! :name => 'Un', :'related card' => nil
    assert_raise_message(CardQuery::DomainException, "The value of THIS CARD.'related card' is NULL and cannot be used in an IN or NUMBERS IN clause.") do
      CardQuery.parse("SELECT number WHERE 'related card' NUMBERS IN (THIS CARD.'related card')", :content_provider => this_card).values
    end
  end

  def test_this_card_property_fails_nicely_when_comparing_date_properties_to_card_relationship_properties_IN_clause
    this_card = create_card! :name => 'Un', :date_created => '03/26/2010'
    assert_raise_message(CardQuery::DomainException, "Property #{'related card'.bold} is card, and value #{'26 Mar 2010'.bold} is not card. Only card values can be compared with #{'related card'.bold}.") do
      CardQuery.parse("SELECT number WHERE 'related card' NUMBERS IN (THIS CARD.date_created)", :content_provider => this_card).values
    end
  end

  def test_in_this_card_property_returns_correct_values
    this_card = create_card! :name => 'Uno', :size => '2'
    assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE size IN (1, THIS CARD.size, 3)", :content_provider => this_card).values
  end

  def test_this_card_property_raise_exception_when_used_in_wiki_page
    assert_raise_message(CardQuery::DomainException, /#{'THIS CARD.Size'.bold} is not a supported macro for page./) do
      CardQuery.parse("SELECT number WHERE 'size' IN (THIS CARD.size)", :content_provider => @project.pages.create!(:name => 'foo'))
    end
  end

  def test_this_card_property_shows_alert_when_used_in_card_defaults_using_in_clause
    alert_receiver = MockAlertReceiver.new
    some_card_defaults = @project.card_types.first.card_defaults
    CardQuery.parse("SELECT number WHERE 'size' IN (THIS CARD.size)", :content_provider => some_card_defaults, :alert_receiver => alert_receiver).values rescue nil
    assert_equal ["Macros using #{'THIS CARD.Size'.bold} will be rendered when card is created using this card default."], alert_receiver.alerts
  end

  def test_this_card_property_works_with_a_formula_property_that_is_of_type_date
    with_new_project do |project|
      setup_date_property_definition('start_date')
      setup_formula_property_definition('date formula', 'start_date + 2')
      this_card = create_card! :name => "I am card", :start_date => '11 Dec 2009'

      assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE 'date formula' = THIS CARD.'date formula'", :content_provider => this_card).values
      assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE 'date formula' IN (THIS CARD.'date formula')", :content_provider => this_card).values
    end
  end

  def test_this_card_property_works_with_a_formula_property_that_is_of_type_number
    this_card = create_card! :name => "I am card", :size => 2

    assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE half = THIS CARD.half", :content_provider => this_card).values
    assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE half IN (THIS CARD.half)", :content_provider => this_card).values
  end

  def test_this_card_property_gives_pleasant_error_message_when_comparing_number_with_a_date
    this_card = create_card! :name => "I am card", :size => 2, :date_created => '07 Dec 1941'

    assert_raise_message(CardQuery::DomainException, "Property #{'half'.bold} is numeric, and value #{'07 Dec 1941'.bold} is not numeric. Only numeric values can be compared with #{'half'.bold}.") do
      CardQuery.parse("SELECT number WHERE half = THIS CARD.date_created", :content_provider => this_card).values
    end
    assert_raise_message(CardQuery::DomainException, "Property #{'half'.bold} is numeric, and value #{'07 Dec 1941'.bold} is not numeric. Only numeric values can be compared with #{'half'.bold}.") do
      CardQuery.parse("SELECT number WHERE half IN (THIS CARD.date_created)", :content_provider => this_card).values
    end
  end

  def test_this_card_property_gives_pleasant_error_message_when_comparing_numberic_formula_with_a_date_formula_property
    with_new_project do |project|
      setup_date_property_definition('start_date')
      setup_formula_property_definition('date formula', 'start_date + 2')
      setup_formula_property_definition('number formula', '1 + 3')
      this_card = create_card! :name => "I am card", :start_date => '11 Dec 2009'

      assert_raise_message(CardQuery::DomainException, "Property #{'number formula'.bold} is numeric, and value #{'2009-12-13'.bold} is not numeric. Only numeric values can be compared with #{'number formula'.bold}.") do
        CardQuery.parse("SELECT number WHERE 'number formula' = THIS CARD.'date formula'", :content_provider => this_card).values
      end
      assert_raise_message(CardQuery::DomainException, "Property #{'number formula'.bold} is numeric, and value #{'2009-12-13'.bold} is not numeric. Only numeric values can be compared with #{'number formula'.bold}.") do
        CardQuery.parse("SELECT number WHERE 'number formula' IN (THIS CARD.'date formula')", :content_provider => this_card).values
      end
    end
  end

  def test_this_card_property_shows_alert_when_used_in_card_defaults_using_equality_operator
    alert_receiver = MockAlertReceiver.new
    some_card_defaults = @project.card_types.first.card_defaults
    CardQuery.parse("SELECT number WHERE 'size' = THIS CARD.size", :content_provider => some_card_defaults, :alert_receiver => alert_receiver).values rescue nil
    assert_equal ["Macros using #{'THIS CARD.Size'.bold} will be rendered when card is created using this card default."], alert_receiver.alerts
  end

  def test_this_card_property_should_error_when_property_doesnt_exist
    this_card = @project.cards.first
    assert_raise_message(CardQuery::Column::PropertyNotExistError, "Card property '#{'number formula'.bold}' does not exist!") do
      CardQuery.parse("SELECT number WHERE 'number formula' = THIS CARD.'non-existent'", :content_provider => this_card).values
    end
  end

  def test_this_card_property_should_error_when_property_does_not_apply_to_cards_card_type
    with_three_level_tree_project do |project|
      release1 = project.cards.find_by_name('release1')
      assert_raise_message(CardQuery::DomainException, "Card property '#{'Planning release'.bold}' is not valid for '#{'release'.bold}' card types.") do
        CardQuery.parse("SELECT number WHERE 'Planning release' = THIS CARD.'Planning release'", :content_provider => release1).values
      end
    end
  end

  def test_numbers_in_this_card_property_returns_correct_values
    related_card = create_card! :name => 'cousin'
    this_card = create_card! :name => 'Uno'
    this_card.cp_related_card = related_card
    this_card.save!
    assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE 'related card' NUMBERS IN (1, THIS CARD.'related card', 3)", :content_provider => this_card).values
  end

  def test_this_card_property_should_raise_exception_if_using_this_card_with_page_context
    assert_raise_message(CardQuery::DomainException, /#{'THIS CARD.Size'.bold} is not a supported macro for page./) do
      CardQuery.parse("SELECT number WHERE 'size' = THIS CARD.size", :content_provider => @project.pages.create!(:name => 'foo'))
    end
  end

  def test_this_card_property_should_not_raise_exception_if_using_this_card_property_without_content
    # Because content_provider is nil when creating an aggregate
    assert_nothing_raised do
      CardQuery.parse("SELECT number WHERE 'size' = THIS CARD.size", :content_provider => nil)
    end
  end

  def test_should_create_this_card_property_alert_if_using_this_card_with_card_default
    alert_receiver = MockAlertReceiver.new
    some_card_defaults = @project.card_types.first.card_defaults
    CardQuery.parse("SELECT number WHERE 'size' = THIS CARD.size", :content_provider => some_card_defaults, :alert_receiver => alert_receiver).to_sql
    assert_equal ["Macros using #{'THIS CARD.Size'.bold} will be rendered when card is created using this card default."], alert_receiver.alerts
  end

  def test_values_method_works_with_this_card_syntax
    this_card = @project.cards.first
    related_card_property_definition = @project.find_property_definition('related card')

    another_card = @project.cards.create!(:name => 'another card', :card_type_name => 'Card')
    related_card_property_definition.update_card(another_card, this_card)
    another_card.save!

    assert_equal [{"Name"=>"another card"}], CardQuery.parse("SELECT name WHERE 'related card' = THIS CARD", :content_provider => this_card).values
  end

  def test_single_value_method_works_with_this_card_syntax
    this_card = @project.cards.first

    related_card_property_definition = @project.find_property_definition('related card')

    another_card = @project.cards.create!(:name => 'another card', :card_type_name => 'Card')
    related_card_property_definition.update_card(another_card, this_card)
    another_card.save!

    assert_equal "another card", CardQuery.parse("SELECT name WHERE 'related card' = THIS CARD", :content_provider => this_card).single_value
  end

  def test_values_as_pairs_method_works_with_this_card_syntax
    this_card = @project.cards.first
    related_card_property_definition = @project.find_property_definition('related card')
    another_card = @project.cards.create!(:name => 'another card', :card_type_name => 'Card')
    related_card_property_definition.update_card(another_card, this_card)
    another_card.save!
    assert_equal [[another_card.number.to_s, 1]], CardQuery.parse("SELECT number, COUNT(*) WHERE 'related card' = THIS CARD", :content_provider => this_card).values_as_pairs
  end

  def test_values_as_coords_method_works_with_this_card_syntax
    this_card = @project.cards.first
    related_card_property_definition = @project.find_property_definition('related card')
    another_card = @project.cards.create!(:name => 'another card', :card_type_name => 'Card')
    related_card_property_definition.update_card(another_card, this_card)
    another_card.save!
    assert_equal({another_card.number.to_s=>1}, CardQuery.parse("SELECT number, COUNT(*) WHERE 'related card' = THIS CARD", :content_provider => this_card).values_as_coords)
  end

  def test_values_as_coords_method_works_with_this_card_syntax_for_card_versions
    this_card = @project.cards.first
    related_card_property_definition = @project.find_property_definition('related card')
    another_card = @project.cards.create!(:name => 'another card', :card_type_name => 'Card')
    related_card_property_definition.update_card(another_card, this_card)
    another_card.save!
    assert_equal({another_card.number.to_s=>1}, CardQuery.parse("SELECT number, COUNT(*) WHERE 'related card' = THIS CARD", :content_provider => this_card.versions.first).values_as_coords)
  end

  def test_should_raise_exception_if_using_this_card_with_page_context
    assert_raise_message(CardQuery::DomainException, /#{'THIS CARD'.bold} is not a supported macro for page./) do
      some_page = @project.pages.create!(:name => 'foo')
      CardQuery.parse("SELECT number, COUNT(*) WHERE 'related card' = THIS CARD", :content_provider => some_page).to_sql
    end
  end

  def test_should_raise_exception_if_using_this_card_with_page_version_context
    assert_raise_message(CardQuery::DomainException, /#{'THIS CARD'.bold} is not a supported macro for page./) do
      some_page = @project.pages.create!(:name => 'foo')
      CardQuery.parse("SELECT number, COUNT(*) WHERE 'related card' = THIS CARD", :content_provider => some_page.versions.last).to_sql
    end
  end

  # Bug 7789
  def test_should_create_this_card_alert_if_using_this_card_with_card_which_has_not_been_saved
    alert_receiver = MockAlertReceiver.new
    CardQuery.parse("SELECT number, COUNT(*) WHERE 'related card' = THIS CARD", :content_provider => Card.new, :alert_receiver => alert_receiver).to_sql
    assert_equal ["Macros using #{'THIS CARD'.bold} will be rendered when card is saved."], alert_receiver.alerts
  end

  # Bug 7789
  def test_should_create_this_card_alert_if_using_this_card_property_with_card_which_has_not_been_saved
    alert_receiver = MockAlertReceiver.new
    new_card = Card.new
    new_card.project = @project
    CardQuery.parse("SELECT number WHERE size = THIS CARD.size", :content_provider => new_card, :alert_receiver => alert_receiver).to_sql
    assert_equal ["Macros using #{'THIS CARD.Size'.bold} will be rendered when card is saved."], alert_receiver.alerts
  end

  def test_should_create_this_card_alert_if_using_this_card_with_card_default
    alert_receiver = MockAlertReceiver.new
    some_card_defaults = @project.card_types.first.card_defaults
    CardQuery.parse("SELECT number, COUNT(*) WHERE 'related card' = THIS CARD", :content_provider => some_card_defaults, :alert_receiver => alert_receiver).to_sql
    assert_equal ["Macros using #{'THIS CARD'.bold} will be rendered when card is created using this card default."], alert_receiver.alerts
  end

  def test_should_have_alert_about_this_card_unavailable_when_using_this_card_in_mql
    with_three_level_tree_project do |project|
      alert_receiver = MockAlertReceiver.new
      CardQuery.parse("SELECT number, COUNT(*) WHERE 'Planning iteration' = THIS CARD", :content_provider => project.cards.new, :alert_receiver => alert_receiver).to_sql
      assert_equal ["Macros using #{'THIS CARD'.bold} will be rendered when card is saved."], alert_receiver.alerts
    end
  end

  def test_should_raise_exception_if_this_card_is_of_a_type_that_does_not_match_property
    with_three_level_tree_project do |project|
      story = project.cards.find_by_name('story1')
      assert_raise_message(CardQuery::DomainException, /Comparing between property '#{'Planning iteration'.bold}' and THIS CARD is invalid as they are different types./) do
        CardQuery.parse("SELECT number, COUNT(*) WHERE 'Planning iteration' = THIS CARD", :content_provider => story).to_sql
      end

      alert_receiver = MockAlertReceiver.new
      story_card_defaults = project.card_types.find_by_name('story').card_defaults
      assert_raise_message(CardQuery::DomainException, /Comparing between property '#{'Planning iteration'.bold}' and THIS CARD is invalid as they are different types./) do
        CardQuery.parse("SELECT number, COUNT(*) WHERE 'Planning iteration' = THIS CARD", :content_provider => story_card_defaults, :alert_receiver => alert_receiver).to_sql
      end

      # happy path
      iteration_card_defaults = project.card_types.find_by_name('iteration').card_defaults
      alert_receiver = MockAlertReceiver.new
      CardQuery.parse("SELECT number, COUNT(*) WHERE 'Planning iteration' = THIS CARD", :content_provider => iteration_card_defaults, :alert_receiver => alert_receiver).to_sql
      assert_equal ["Macros using #{'THIS CARD'.bold} will be rendered when card is created using this card default."], alert_receiver.alerts
    end
  end

  def test_should_not_be_able_to_compare_this_card_with_non_card_properties
    assert_raise_message(CardQuery::DomainException, /Property #{'Size'.bold} is not a card relationship property or tree relationship property, only card relationship properties or tree relationship properties can be used in 'column = THIS CARD' clause./) do
      CardQuery.parse("SELECT number WHERE size = THIS CARD")
    end
  end

  def test_this_card_property_can_use_property_named_select
    with_new_project do |project|
      setup_allow_any_text_property_definition 'select'
      this_card = create_card! :name => 'Uno', :select => 'foo'
      assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE 'select' = THIS CARD.'select'", :content_provider => this_card).values
    end
  end

  def test_can_restrict_query_with_this_card
    this_card = create_card! :name => 'Uno', :size => '2'
    q = CardQuery.parse("SELECT number", :content_provider => this_card)
    assert_equal [{ "Number" => this_card.number.to_s }], q.restrict_with("size = THIS CARD.size").values
  end

  # bug 8151
  def test_this_card_property_can_make_date_comparisons_using_in_clause
    this_card = create_card! :name => 'Un', :date_created => 'May 02 2009'
    assert_equal [{ "Number" => this_card.number.to_s }], CardQuery.parse("SELECT number WHERE date_created IN (THIS CARD.date_created)", :content_provider => this_card).values
  end

  # bug 8339
  def test_comparing_relationship_property_with_number_should_do_a_name_comparison
    with_three_level_tree_project do |project|
      this_card = project.cards.find_by_name('release1')
      expected_values = CardQuery.parse("SELECT 'Planning release' where 'Planning release' = #{this_card.number}").values  # correctly acts as though we are giving it a card name
      assert_equal expected_values, CardQuery.parse("SELECT 'Planning release' where 'Planning release' = THIS CARD.number", :content_provider => this_card).values
    end
  end

  # Bug 8214 (story #8379 changes this)
  def test_can_not_use_this_card_property_across_projects
    this_card = create_card! :name => 'this project'
    with_first_project do |that_project|
      assert_raise_message(CardQuery::DomainException, /THIS CARD is not supported for cross project macros./) do
        CardQuery.parse('SELECT number WHERE number = THIS CARD.number', :content_provider => this_card)
      end
    end
  end

  def test_should_be_able_to_compare_number_with_value_of_relationship_property
    related_card = @project.cards.create!(:name => 'related card', :card_type_name => 'Card')
    this_card = @project.cards.create!(:name => 'some card', :card_type_name => 'Card', :cp_related_card => related_card)

    assert_equal [{"Name"=>"related card"}], CardQuery.parse("SELECT name WHERE number IN (THIS CARD.'related card')", :content_provider => this_card).values
    assert_equal [{"Name"=>"related card"}], CardQuery.parse("SELECT name WHERE number = THIS CARD.'related card'", :content_provider => this_card).values
  end

end

class MockAlertReceiver
  attr_reader :alerts

  def initialize
    @alerts = []
  end

  def alert(message)
    alerts << message
  end
end
