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

require File.expand_path(File.dirname(__FILE__) + '/../../../simple_test_helper')
require 'ast/sql'

class Ast::Sql::StatementTest < Test::Unit::TestCase
  def test_sort_statements
    statements = [group_by, order_by, select, from, join, where]
    assert_equal ['select', 'from', 'join', 'where', 'order_by', 'group_by'], statements.sort.collect(&:to_s)
  end

  def test_join_statements
    assert_equal 'select from', [select, from].join(' ')
  end

  def test_validate_statements
    assert Ast::Sql::Statement.valid?([select, from])
    assert !Ast::Sql::Statement.valid?([select])
    assert !Ast::Sql::Statement.valid?([from])
    assert !Ast::Sql::Statement.valid?([where])
    assert !Ast::Sql::Statement.valid?([select, select, from])
  end

  def test_should_be_valid_for_multi_join_statements
    assert Ast::Sql::Statement.valid?([select, from, join, join])
  end

  def test_raise_error_for_invalid_statements
    assert_raise Ast::Sql::InvalidStatementsError do
      Ast::Sql::Statement.validate([select])
    end
  end

  def group_by
    Ast::Sql::Statement.group_by('group_by')
  end
  def select
    Ast::Sql::Statement.select('select')
  end
  def order_by
    Ast::Sql::Statement.order_by('order_by')
  end
  def from
    Ast::Sql::Statement.from('from')
  end
  def join
    Ast::Sql::Statement.join('join')
  end
  def where
    Ast::Sql::Statement.where('where')
  end
end
