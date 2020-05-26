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
require 'mql'

class Ast::TransformTest < Test::Unit::TestCase
  include Ast

  def test_collect_node_info
    mql = Mql.parse("select number where status = new")
    properties = []
    transformer = Transform.new do |t|
      t.match(:property) { |node| properties << node[:name] }
    end
    mql.apply(transformer)
    assert_equal ['number', 'status'], properties
  end

  def test_node_matched_by_name_and_attribute
    mql = Mql.parse("select number where owner = current user")
    matched = []
    transformer = Transform.new do |t|
      t.match(:statements) { |node| matched << 'statements' }
      t.match(:context, :type => 'user') { |node| matched << 'current user' }
      t.match(:select, :distinct => false) { |node| matched << 'select'}
      t.match(:select, :distinct => true) { |node| matched << 'select distinct' }
    end
    mql.apply(transformer)
    assert_equal ['select', 'current user', 'statements'], matched
  end

  def test_transform_instance_rules_should_be_independent
    mql = Mql.parse("select number where owner = current user")
    Transform.new do |t|
      t.match(:statements) { |node| raise 'something wrong' }
    end
    transformer = Transform.new do |t|
      t.match(:statements) { |node| 'hello' }
    end
    assert_equal 'hello', mql.apply(transformer)
  end

  def test_sub_class_rules_should_be_independent
    transformer1 = Class.new(Transform) { match(:match1, &:block) }
    transformer2 = Class.new(Transform) { match(:match2, &:block) }
    assert_equal [], Transform.instance_rules
    assert_equal [], Transform.new.instance_rules
    assert_not_equal transformer1.new.rules, transformer2.new.rules
  end

  def test_substitute_node_with_sub_node
    mql = Mql.parse("select sum(estimate)")
    t = Transform.new do |t|
      t.match(:aggregate) { |node| node[:property] }
    end
    new_ast = mql.apply(t)
    assert_equal Mql.parse("select estimate"), new_ast
  end

  def test_substitute_node_with_new_node
    mql = Mql.parse("select sum(estimate)")
    t = Transform.new do |t|
      t.match(:aggregate) { |node| Node.new(:property, :name => 'haha') }
    end
    new_ast = mql.apply(t)
    assert_equal Mql.parse("select haha"), new_ast
  end

  def test_should_expand_array_when_substitution_has_more_than_one_arity
    new_ast = node(:abc, [node(:left), node(:right)]).transform do |t|
      t.match(:abc) { |left, right| node(:abc, :left => left, :right => right) }
    end
    expected = node(:abc, :left => node(:left), :right => node(:right))
    assert_equal expected, new_ast
  end

  def test_transform_should_not_change_source_node
    origin = Mql.parse("select sum(estimate)")
    t = Transform.new do |t|
      t.match(:property) { |node| Node.new(:unknown) }
    end
    r = origin.apply(t)
    assert_equal Mql.parse("select sum(estimate)"), origin
  end

  def test_visit_node
    origin = node(:abc, [node(:left), node(:right)])
    new_ast = origin.visit do |t|
      t.match(:abc) { |left, right| node(:abc, :left => left, :right => right) }
    end
    assert_equal origin, new_ast
  end
end
