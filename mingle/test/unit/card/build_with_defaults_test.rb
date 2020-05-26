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

class Card::BuildWithDefaultTest < ActiveSupport::TestCase

  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def test_build_with_defaults_should_new_card_within_project
    first_type = @project.card_types.first
    card = @project.cards.build_with_defaults(:card_type_name => first_type.name)
    assert_equal @project, card.project
    assert card.new_record?
  end

  def test_build_with_defaults_should_set_card_type_default_descriptions
    first_type = @project.card_types.first
    first_type.card_defaults.update_attributes(:description => 'template desc')

    card = @project.cards.build_with_defaults(:card_type => first_type)

    assert_equal 'template desc', card.description
  end

  def test_build_with_defaults_should_set_use_value_from_attributes_over_card_type_defaults
    first_type = @project.card_types.first
    first_type.card_defaults.update_attributes(:description => 'template desc')

    card = @project.cards.build_with_defaults(:card_type => first_type, :description => 'attribut desc')

    assert_equal 'attribut desc', card.description
  end

  def test_build_with_defaults_should_set_card_type_default_properties
    first_type = @project.card_types.first
    first_type.card_defaults.update_properties(:status => 'open')

    card = @project.cards.build_with_defaults(:card_type => first_type, :description => 'raspberry swirl')

    assert_equal 'open', card.cp_status
  end

  def test_build_with_defaults_should_use_first_card_type_when_card_not_specified
    card = @project.cards.build_with_defaults
    assert_name_equal @project.card_types.first, card.card_type
  end

  def test_build_with_defaults_should_use_first_card_type_when_card_type_is_not_valid
    card = @project.cards.build_with_defaults(:card_type_name => 'not exits')
    assert_equal @project.card_types.first, card.card_type

    card = @project.cards.build_with_defaults({}, 'Type' => 'not exits')
    assert_equal @project.card_types.first, card.card_type
  end


  def test_should_set_card_type_defaults_when_type_is_set_through_properties
    second_type = @project.card_types.create!(:name => 'new type')
    second_type.card_defaults.update_properties(:status => 'open')
    card = @project.cards.build_with_defaults({}, {:type => second_type.name})
    assert_equal 'open', card.cp_status
  end

  def test_should_set_properties_when_properties_provided
    member = User.find_by_login('member')
    card = @project.cards.build_with_defaults({}, {:dev => member.login })
    assert_equal member, card.cp_dev
  end

  def test_property_should_be_not_set_if_error_happened
    dev = @project.find_property_definition("dev")
    card_type = @project.card_types.first
    card_type.card_defaults.update_properties :dev => PropertyType::UserType::CURRENT_USER

    login(User.find_by_login("admin").email)

    card = @project.cards.build_with_defaults
    assert_equal nil, card.cp_dev
  end

  def test_nil_attributes_and_properties
    card = @project.cards.build_with_defaults(nil, nil)
    assert_not_nil card
    assert_name_equal @project.card_types.first, card.card_type
  end

  def test_should_use_type_in_attribute_if_given
    second_type = @project.card_types.create!(:name => 'new type')
    card = @project.cards.build_with_defaults({:card_type_name => second_type.name})
    assert_name_equal second_type, card.card_type
  end

  def test_build_with_defaults_should_use_type_property_when_type_property_is_set
    second_type = @project.card_types.create!(:name => 'new type')
    card = @project.cards.build_with_defaults({:name => 'card 1'}, {:type => second_type.name})
    assert_name_equal second_type, card.card_type
  end

  def test_blank_card_type_name
    card = @project.cards.build_with_defaults({:card_type_name => ""})
    assert_name_equal @project.card_types.first, card.card_type
  end

end
