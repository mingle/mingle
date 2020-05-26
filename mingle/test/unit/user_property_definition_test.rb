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

class UserPropertyDefinitionTest < ActiveSupport::TestCase

  def setup
    @first_user = User.find_by_login('first')
    @project = create_project(:users => [@first_user])
    @owner = @project.create_user_definition!(:name => 'owner')
    @project.card_types.first.add_property_definition(@owner)
    @project.reload. update_card_schema
    login_as_member
  end

  def test_values_should_be_order_by_of_name_and_value
    user_properties = {:password => MINGLE_TEST_DEFAULT_PASSWORD, :password_confirmation => MINGLE_TEST_DEFAULT_PASSWORD}

    @project.add_member User.create!(user_properties.merge(:login => "owner1", :name => "owner1", :email => "owner1@x.com"))
    @project.add_member User.create!(user_properties.merge(:login => "a_owner2", :name => "a_owner2", :email => "owner2@x.com"))
    @project.add_member User.create!(user_properties.merge(:login => "a_owner3", :name => "a_owner3", :email => "owner3@x.com"))

    assert_equal ["a_owner2", "a_owner3", "first@email.com", "owner1"], @owner.values.collect(&:name)
  end

  def test_deactivate_should_clean_up_the_association
    with_new_project do |project|
      setup_user_definition 'deveploper'
    end
    with_new_project do |project|
      setup_property_definitions :developer => ['wpc']
      card = create_card!(:name => "wpc's card", :developer => 'wpc')
      assert_equal 'wpc', card.cp_developer
    end
  end

  def test_should_have_column_name_be_owner_id_for_user_property
    assert_equal 'cp_owner_user_id', @owner.column_name
    assert_equal 'cp_owner', @owner.ruby_name
    with_new_project do |project|
      ba = project.all_property_definitions.create_user_property_definition(:name => 'business analyst')
      assert_equal 'cp_business_analyst_user_id', ba.column_name
      assert_equal 'cp_business_analyst', ba.ruby_name
    end
    with_new_project do |project|
      user_type = project.all_property_definitions.create_user_property_definition(:name => 'type')
      assert_equal 'cp_type_user_id', user_type.column_name
      assert_equal 'cp_type', user_type.ruby_name
    end
  end

  def test_validate_card
    card_type = @project.card_types.first
    card = @project.cards.new(:name => 'card1', :cp_owner_user_id => 'some crappy user id', :project => @project, :card_type => card_type)
    assert !card.valid?

    user_not_in_team = User.find_by_login('admin')
    assert !@project.cards.new(:name => 'card1', :cp_owner_user_id => user_not_in_team.id, :project => @project, :card_type => card_type).valid?

    assert @project.cards.new(:name => 'card1', :cp_owner_user_id => @first_user.id, :project => @project, :card_type => card_type).valid?
    assert @project.cards.new(:name => 'card1', :cp_owner_user_id => nil, :project => @project, :card_type => card_type).valid?
  end

  def test_should_be_invalid_if_set_card_to_a_user_who_is_not_team_member_of_the_project_card_blongs_to
    non_team_member = create_user! :login => 'mouse'
    card = create_card!(:name => 'card1')
    @owner.update_card(card, non_team_member.id)
    @owner.validate_card(card)
    assert !card.errors.empty?
    assert_equal " #{non_team_member.name.bold} is not a project member", card.errors.full_messages[0]
  end

  def test_value_for_card_should_return_user
    user = User.find_by_login('first')
    card = create_card!(:name => 'card1', :owner => user.id)
    assert_equal user,  @owner.value(card)
    assert_equal @owner.property_value_from_url('first'), card.property_value(@owner)
  end

  def test_value_for_card_should_return_nil_if_user_not_set
    card = create_card!(:name => 'card1')
    assert @owner.value(card).blank?
    assert @owner.property_value_on(card).not_set?
  end

  def test_user_property_renaming_does_not_regenerate_column_name
    assert_equal 'cp_owner_user_id', @owner.column_name
    @owner.update_attributes(:name => 'stakeholder')
    assert_equal 'cp_owner_user_id', @owner.reload.column_name
  end

  def test_properties_should_take_all_the_users_in_the_project
    assert_equal [@first_user.id.to_s], @owner.property_values.collect(&:db_identifier)
    assert_equal [@first_user.name], @owner.property_values.collect(&:display_value)
  end

  def test_should_not_support_inline_creating
    assert !@owner.support_inline_creating?
  end

  def test_should_understand_current_user_as_special_identifier
    assert_equal PropertyType::UserType:: CURRENT_USER, @owner.property_value_from_db(PropertyType::UserType:: CURRENT_USER).display_value
  end

  def test_should_update_card_with_current_user
    @project.add_member(User.find_by_login('bob'))
    card = create_card!(:name => 'card 1', :card_type => @project.card_types.first)
    logout_as_nil
    login('bob@email.com')

    @owner.update_card(card, PropertyType::UserType::CURRENT_USER)
    card.save!
    logout_as_nil
    login_as_member
    assert_equal 'bob@email.com', card.display_value(@owner)
    assert_equal User.find_by_login('bob').id, @owner.property_value_on(card).db_identifier.to_i
    assert_equal PropertyType::UserType:: CURRENT_USER, @owner.property_value_from_db(PropertyType::UserType:: CURRENT_USER).display_value
  end

  def test_database_value_should_convert_login_to_id
    assert_equal @first_user.id.to_s, @owner.property_value_from_url(@first_user.login).db_identifier
  end

  def test_database_value_should_use_user_id
    assert_equal @first_user.id.to_s, @owner.property_value_from_db(@first_user.id).db_identifier
  end

  def test_database_value_should_convert_blank_to_null
    assert_nil @owner.property_value_from_url('').db_identifier
  end

  def test_database_value_should_convert_current_user_to_id
    logout_as_nil
    member = User.find_by_login('member')
    login_as_member
    assert_equal member.id.to_s, @owner.property_value_from_url(PropertyType::UserType:: CURRENT_USER).db_identifier
    assert_equal PropertyType::UserType:: CURRENT_USER, @owner.property_value_from_db(PropertyType::UserType:: CURRENT_USER).db_identifier
  end

  def test_copiable_to_returns_false_when_card_value_is_not_team_member_of_target_project
    card = create_card! :name => 'Uno', :owner => @first_user.id

    with_new_project do |project|
      another_owner = setup_user_definition 'Owner'
      assert_equal false, @owner.value_copiable?(card, another_owner)
    end
  end

  def test_copiable_to_returns_true_when_card_value_is_team_member_of_target_project
    card = create_card! :name => 'Uno', :owner => @first_user.id

    with_new_project do |another|
      another_owner = setup_user_definition 'Owner'
      another.add_member(@first_user)
      assert_equal true, @owner.value_copiable?(card, another_owner)
    end
  end

  def test_copiable_to_returns_true_when_card_value_is_nil
    card = create_card! :name => 'Uno', :owner => nil

    with_new_project do |another|
      another_owner = setup_user_definition 'Owner'
      assert_equal true, @owner.value_copiable?(card, another_owner)
    end
  end

  def test_lane_identifier_returns_user_login
    presidents = setup_user_definition 'presidents'
    obama = create_user!(:login => "bobama")
    @project.add_member obama
    assert_equal "bobama", presidents.lane_identifier(obama.login)
  end

  def test_lane_identifier_returns_current_users_login_for_current_user
    presidents = setup_user_definition 'presidents'
    @project.add_member User.current
    assert_equal User.current.login, presidents.lane_identifier('(current user)')
  end

  def test_lane_values_returns_user_name_and_login_pairs
    with_first_project do |project|
      dev = project.find_property_definition "dev"
      lane_value_options = dev.lane_values
      assert_equal dev.values.size, lane_value_options.size
      dev.values.each do |user|
        assert_include [user.name, user.login], lane_value_options
      end
    end
  end

  def test_card_filter_options_is_empty_now_that_we_lazy_load_users
    with_first_project do |project|
      dev = project.find_property_definition "dev"
      assert_equal [], dev.card_filter_options
    end
  end
end
