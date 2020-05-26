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

class CardRelationshipPropertyDefinitionTest < ActiveSupport::TestCase

  def setup
    login_as_admin
  end
  
  def teardown
    logout_as_nil
  end    

  def test_should_accept_plain_old_number_for_url_identifier
    with_card_query_project do |project|
      card_one = project.cards.create!(:name => 'card one', :card_type_name => 'Card')
      prop = project.find_property_definition('related card')
      assert_equal [card_one.number_and_name, card_one.id.to_s], prop.property_value_from_url(card_one.number.to_s).db_value_pair
    end
  end  

  def test_should_accept_card_query_display_format_for_url_identifier
    with_card_query_project do |project|
      card_one = project.cards.create!(:name => 'card one', :card_type_name => 'Card', :number => 101)
      prop = project.find_property_definition('related card')
      value_returned_from_card_query = card_one.number_and_name
      assert_equal [card_one.number_and_name, card_one.id.to_s], prop.property_value_from_url(value_returned_from_card_query).db_value_pair
    end
  end  
  
  
  def test_property_values_description_should_be_any_card
    with_card_query_project do |project|
      card_prop = project.find_property_definition('related card')
      assert_equal "Any card", card_prop.property_values_description
    end
  end

end
