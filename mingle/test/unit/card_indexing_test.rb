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

class CardIndexingTest < ActiveSupport::TestCase

  def setup
    @user = create_user! :login => 'senglehart', :email => 'senglehart@marvel.com', :name => 'Steve Englehart', :version_control_user_name => 'sengleha'
    login(@user.email)
    @project = first_project
    @project.activate
  end

  def teardown
    @project.deactivate
  end

  def test_when_indexed_should_include_name
    card = @project.cards.create!(:name => 'Shang-Chi', :card_type => @project.card_types.first)
    assert_equal 'Shang-Chi', card.as_json_for_index['name']
  end

  def test_when_indexed_should_include_project_id
    card = @project.cards.create!(:name => 'Shang-Chi', :card_type => @project.card_types.first)
    assert_equal @project.id, card.as_json_for_index['project_id']
  end

  def test_when_indexed_should_include_description
    description = "He has no special superpowers, but he exhibits extraordinary skills in the martial arts and is a master of Wushu"
    card = @project.cards.create!(:name => 'Shang-Chi', :description => description, :card_type => @project.card_types.first)
    assert_equal description, card.as_json_for_index[:indexable_content]
  end

  def test_when_indexed_should_include_card_type_name_and_id
    card_type = @project.card_types.first
    card = @project.cards.create!(:name => 'Shang-Chi', :card_type => card_type)
    assert_equal card_type.name, card.as_json_for_index['card_type_name']
    assert_equal card_type.id, card.as_json_for_index[:card_type_id]
  end

  def test_when_indexed_should_include_number
    card = @project.cards.create!(:name => 'Shang-Chi', :number => 1234, :card_type => @project.card_types.first)
    assert_equal 1234, card.as_json_for_index['number']
  end

  def test_when_indexed_should_include_comments
    card = @project.cards.create!(:name => 'Shang-Chi', :card_type => @project.card_types.first)
    card.add_comment :content => "Master of Kung Fu"
    assert_equal ["Master of Kung Fu"], card.as_json_for_index[:discussion_for_indexing]
  end

  def test_when_indexed_should_include_creator
    card = @project.cards.create!(:name => 'Shang-Chi', :card_type => @project.card_types.first)
    creator_json = card.as_json_for_index['created_by']
    assert_equal 'Steve Englehart', creator_json['name']
    assert_equal 'senglehart', creator_json['login']
    assert_equal 'senglehart@marvel.com', creator_json['email']
    assert_equal 'sengleha', creator_json['version_control_user_name']
  end

  def test_when_indexed_should_include_creator
    card = @project.cards.create!(:name => 'Shang-Chi', :card_type => @project.card_types.first)
    create_user! :login => 'jps', :email => 'jim@marvel.com', :name => 'James P. Starlin', :version_control_user_name => 'jstar'
    login('jim@marvel.com')
    card.description = "Shang-Chi was born in the Hunan province of the People's Republic of China, and is the son of Fu Manchu"
    card.save!
    modifier_json = card.as_json_for_index[:modified_by]
    assert_equal 'James P. Starlin', modifier_json['name']
    assert_equal 'jps', modifier_json['login']
    assert_equal 'jim@marvel.com', modifier_json['email']
    assert_equal 'jstar', modifier_json['version_control_user_name']
  end

  def test_when_indexing_html_tags_should_be_stored_as_human_readable_escaped
    card = @project.cards.create!(:name => 'Cobalt Man', :description => '<b>Co</b> 27', :card_type => @project.card_types.first)
    assert_equal 'Co 27', card.as_json_for_index[:indexable_content]
  end

  def test_index_tree_configuration_ids
    with_three_level_tree_project do |project|
      story2 = project.cards.find_by_name('story2')
      assert_equal story2.tree_configurations.map(&:id), story2.as_json_for_index[:tree_configuration_ids]
    end
  end

  def test_index_user_property_value
    member = User.find_by_login('member')
    card = @project.cards.find_by_number(1)
    card.update_properties('dev' => member.id)
    card.save!
    properties = card.properties_to_index
    assert_equal ['member', 'member@email.com', 'member@email.com', nil], properties[:dev]
  end

  def test_only_index_enum_user_and_text_properties
    member = User.find_by_login('member')
    card = @project.cards.find_by_number(1)
    card.update_properties('Status' => 'new', 'dev' => member.id, 'id' => '123', 'Release' => '1', 'start date' => Clock.now)
    card.save!
    indexed_property_names = card.properties_to_index.keys.map(&:to_s)
    assert ['dev', 'id', 'release', 'status'].all? { |name| indexed_property_names.include? name }
  end
end
