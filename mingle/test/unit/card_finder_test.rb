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

class CardFinderTest < ActiveSupport::TestCase
  def setup
    @project = card_query_project
    @project.activate
    login_as_member
  end
  
  def test_should_work_as_generic_finder_conditions
    assert_equal 1, @project.cards.find(:first, :mql => "number=1").number
    assert_nil @project.cards.find(:first, :mql => "number=0")

    assert_equal [1], @project.cards.find(:all, :mql => "number=1").collect(&:number)
  end
  
  def test_find_cards_by_query
    q = CardQuery.parse("number=1")
    assert_equal 1, @project.cards.find(:first, :query => q).number
    assert_equal 1, @project.cards.count(:query => q)
  end
  
  def test_should_ignore_nil_option_of_query
    create_card!(:name => 'Blah', :iteration => '1')
    create_card!(:name => 'Blah', :iteration => '2')
    assert_equal @project.cards.count, @project.cards.find(:all, :query => nil).size
  end
  
  def test_should_merge_mql_condition_to_normal_condition
    create_card!(:name => 'Blah', :iteration => '1')
    create_card!(:name => 'Blah', :iteration => '2')
    create_card!(:name => 'Blah', :iteration => '2')
    create_card!(:name => 'Blah', :iteration => '3')
    assert_equal 2, @project.cards.count(:conditions => ["cp_iteration != ?", '1'] , :mql => "iteration < 3")
    assert_equal 2, @project.cards.find(:all, :conditions => ["cp_iteration != ?", '1'] , :mql => "iteration < 3").size
  end
  
  def test_should_accept_pagination_options
    create_card!(:name => 'Blah', :iteration => '1')
    create_card!(:name => 'Blah', :iteration => '2')
    create_card!(:name => 'Blah', :iteration => '2')
    create_card!(:name => 'Blah', :iteration => '3')
    assert_equal 2, @project.cards.paginate(:all, :mql => "iteration is not null", :page => 1, :per_page => 2).size
  end
end
