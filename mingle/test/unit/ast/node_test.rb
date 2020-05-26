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

class Ast::NodeTest < Test::Unit::TestCase
  include Ast

  def test_equal
    assert_equal Node.new(:node_name, nil), Node.new(:node_name, nil)
    assert_equal Node.new(:node_name, nil), Node.new(:node_name)
    assert_equal Node.new(:node_name, []), Node.new(:node_name, [])
    assert_equal Node.new(:node_name, {}), Node.new(:node_name, {})
    assert_equal Node.new(:node_name, Node.new(:sub)), Node.new(:node_name, Node.new(:sub))
    assert_equal Node.new(:node_name, [Node.new(:sub)]), Node.new(:node_name, [Node.new(:sub)])
    assert_equal Node.new(:node_name, {:attr => Node.new(:sub)}), Node.new(:node_name, {:attr => Node.new(:sub)})

    assert_not_equal Node.new(:name), nil
    assert_not_equal Node.new(:name), Node.new(:name, [])
    assert_not_equal Node.new(:name), Node.new(:name, {})
    assert_not_equal Node.new(:name), Node.new(:name, Node.new(:sub))
    assert_not_equal Node.new(:name, []), Node.new(:name, {})
    assert_not_equal Node.new(:name, Node.new(:sub)), Node.new(:name, Node.new(:sub2))
  end

  def test_hash
    assert_equal Node.new(:node_name, nil).hash, Node.new(:node_name, nil).hash
    assert_equal Node.new(:node_name, nil).hash, Node.new(:node_name).hash
    assert_equal Node.new(:node_name, []).hash, Node.new(:node_name, []).hash
    assert_equal Node.new(:node_name, {}).hash, Node.new(:node_name, {}).hash
    assert_equal Node.new(:node_name, Node.new(:sub)).hash, Node.new(:node_name, Node.new(:sub)).hash
    assert_equal Node.new(:node_name, [Node.new(:sub)]).hash, Node.new(:node_name, [Node.new(:sub)]).hash
    assert_equal Node.new(:node_name, {:attr => Node.new(:sub)}).hash, Node.new(:node_name, {:attr => Node.new(:sub)}).hash

    assert_not_equal Node.new(:name).hash, nil.hash
    assert_not_equal Node.new(:name).hash, Node.new(:name, []).hash
    assert_not_equal Node.new(:name).hash, Node.new(:name, {}).hash
    assert_not_equal Node.new(:name).hash, Node.new(:name, Node.new(:sub)).hash
    assert_not_equal Node.new(:name, []).hash, Node.new(:name, {}).hash
    assert_not_equal Node.new(:name, Node.new(:sub)).hash, Node.new(:name, Node.new(:sub2)).hash
  end

  def test_uniq_nodes
    n1 = Node.new(:node_name, {:attr => Node.new(:sub)})
    n2 = Node.new(:node_name, {:attr => Node.new(:sub)})
    assert_equal 1, [n1, n2].uniq.length
  end

  def test_node_creation
    assert_equal Node.new(:node_name), node(:node_name)
    assert_equal Node.new(:node_name, []), node(:node_name, [])
  end

  def test_transform
    result = Node.new(:person, :name => 'Jay').transform do |t|
      t.match(:person) {|node| "Hello #{node[:name]}" }
    end
    assert_equal 'Hello Jay', result
  end
end
