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

class CardTreeCardNodeTest < ActiveSupport::TestCase
    
  def setup
    login_as_admin
    @project = three_level_tree_project
    @project.activate
  end
  
  def test_color_of_node_should_be_card_type_color
    card = OpenStruct.new
    def card.color(definition)
      self.color_definintion = definition
      "#ccc"
    end
    node = CardTree::CardNode.new(card, nil, nil, 0, 0, 0, 0)
    assert_equal "#ccc", node.color
    assert_equal CardTypeDefinition::INSTANCE, node.color_definintion
  end
  
  def test_color_should_be_white_if_card_type_color_not_set
    card = OpenStruct.new
    def card.color(definition); ''; end
    node = CardTree::CardNode.new(card, nil, nil, 0, 0, 0, 0)
    assert_equal "#fff", node.color
  end
  
  def test_node_should_act_like_a_card_with_tree_related_methods_on_it
    card = create_card!(:name => 'I am a release story')
    node = CardTree::CardNode.new(card, nil, nil, 0, 0, 0, 0)
    assert_name_equal card, node
    assert_number_equal card, node
    assert_html_id_equal card, node
    assert_kind_of Card, node
    assert_equal card, node
    assert !card.respond_to?(:parent)
    assert node.respond_to?(:parent)
    assert !card.respond_to?(:children)
    assert node.respond_to?(:children)
  end
  
end
