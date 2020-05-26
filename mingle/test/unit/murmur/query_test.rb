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

class Murmur::QueryTest < ActiveSupport::TestCase
  
  def setup
    @project = first_project
    @project.activate
    @member = User.find_by_login('member')
    login_as_member
    @m1 = create_murmur(:murmur => 'm1') 
    @m2 = create_murmur(:murmur => 'm2') 
    @m3 = create_murmur(:murmur => 'm3') 
  end
  
  def test_should_return_all_with_lastest_first_order_when_no_param_given
    assert_equal ['m3', 'm2', 'm1'], query_bodys
  end
  
  def test_wrong_page_should_return_empty_murmurs_collection
    assert_equal [], query_bodys(:page => 2)
  end
  
  def test_get_murmurs_since_murmur_id
    assert_equal ['m3', 'm2'], query_bodys(:since_id => @m1.id)
    assert_equal ['m3'], query_bodys(:since_id => @m2.id)
    assert_equal [], query_bodys(:since_id => @m3.id)
  end
  
  def test_since_id_should_return_nearest_25_when_paginate_happens
    25.times { |i| create_murmur(:murmur => "m#{i + 4}") } #generate m4 ~ m28
    assert_equal (2..26).collect{|i| "m#{i}"}.reverse, query_bodys(:since_id => @m1.id)
  end
  
  def test_before_id_should_return_nearest_25_when_paginate_happens
    25.times { |i| create_murmur(:murmur => "m#{i+ 4}") } #generate m4 ~ m28
    assert_equal (3..27).collect{|i| "m#{i}"}.reverse, query_bodys(:before_id => @project.murmurs.sort_by(&:id).last.id)
  end
  
  def test_get_murmurs_after_murmur_id
    assert_equal [], query_bodys(:before_id => @m1.id)
    assert_equal ['m1'], query_bodys(:before_id => @m2.id)
    assert_equal ['m2', 'm1'], query_bodys(:before_id => @m3.id)
  end
  
  def test_get_murmurs_within_a_range
    assert_equal ['m2'], query_bodys(:since_id => @m1.id, :before_id => @m3.id)
  end
  
  def test_throw_errors_for_bad_cursor
    assert_raise(Murmur::InvalidArgumentError) { query_bodys(:since_id => 'xyx') }
    assert_raise(Murmur::InvalidArgumentError) { query_bodys(:before_id => 'xyx') }
    assert_raise(Murmur::InvalidArgumentError) { query_bodys(:since_id => '') }
    assert_raise(Murmur::InvalidArgumentError) { query_bodys(:before_id => '') }
  end
  
  def test_query_without_cursor
    assert_equal ['m3', 'm2', 'm1'], query_bodys_without_cursor(:since_id => @m1.id)
    assert_equal ['m3', 'm2', 'm1'], query_bodys_without_cursor(:before_id => @m3.id)
  end
  
  def query_bodys(params={})
    @project.murmurs.query(params).collect(&:murmur)
  end
  
  def query_bodys_without_cursor(params)
    @project.murmurs.query_without_cursor(params).collect(&:murmur)    
  end
end
