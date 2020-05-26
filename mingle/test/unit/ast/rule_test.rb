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

require File.expand_path(File.dirname(__FILE__) + '/../../simple_test_helper')
require 'ast'

class Ast::RuleTest < Test::Unit::TestCase
  include Ast
  include Ast::Rule::Factory
  def test_match_class
    assert match(Node).match?(node(:name))
    assert match(Array).match?([node(:name)])
    assert match(Hash).match?(:haha => node(:name))
    assert !match(Array).match?(node(:name))
  end

  def test_match_sub_class
    assert match(Object).match?('obj')
  end

  def test_match_hash
    assert match(:name => 'prop').match?(:name => 'prop')
  end

  def test_match_array
    assert match(['something']).match?(['something'])
  end

  def test_match_anything
    assert match(any).match?(:attr => true)
    assert match(any).match?(node(:name))
    assert match(:attr => any).match?(:attr => true)
    assert match(:name, :attr => any).match?(node(:name, :attr => true))
    assert match(:name, :attr => any).match?(node(:name, :attr => false))
    assert match(:name, :attr => any).match?(node(:name, :attr => false, :another_attr => true))
    assert !match(any).match?(nil)
    assert !match(:name, :attr => any).match?(node(:name, :another_attr => true))
  end

  def test_match_tree_partial
    assert match(:parent, [any, any, :child]).match?(node(:parent, [1, 2, node(:child)]))
    assert match(:parent, [any, any, :child]).match?(node(:parent, [node(:left), '=', node(:child)]))
    assert match(:parent, {:left => :child}).match?(node(:parent, {:left => node(:child), :right => node(:child2)}))

    assert !match(:parent, [any, any, :child]).match?(node(:parent, [2, node(:child)]))
    assert !match(:parent, {:left => :child}).match?(node(:parent, {:right => node(:child)}))
  end

  def test_match_node_tree_partial
    assert match(:parent, node(:child, :childchild)).match?(node(:parent, node(:child, node(:childchild))))
  end

  def test_match_first_symbol_as_node_name
    assert match(:name).match?(node(:name))
    assert !match(:name).match?(node(:something))
  end

  def test_match_hash_following_a_symbol_as_node_attributes
    assert match(:name, {:attr => true}).match?(node(:name, :attr => true))
    assert !match(:name, {:attr => true}).match?(node(:name2, :attr => true))
    assert !match(:name, {:attr => true}).match?(node(:name))
    assert !match(:name, {:attr => true}).match?(node(:name, :attr => false))
  end

  def test_should_pass_matched_object_to_substitution
    r = match(Object) {|node| node}
    assert_equal 'name', r.substitute('name')
  end

  def test_should_pass_matched_node_ast_object_to_substitution_if_a_node_matched
    r = match(:name) {|node| node}
    assert_equal 'attr', r.substitute(node(:name, 'attr'))
  end
end
