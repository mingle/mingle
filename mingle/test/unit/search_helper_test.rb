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

class SearchHelperTest < ActionView::TestCase
  include SearchHelper
  attr_reader :params

  def setup
    @params = {:q => 'query', :type => 'cards'}
  end

  def test_search_result_rank
    Clock.now_is(:year => 2011, :month => 5, :day => 6, :hour => 1, :min => 2, :sec => 3) do
      r = search_result_rank(1, 10)
      assert_equal 1, r[:rank]
      assert_equal 10, r[:size]
      assert_equal 'query', r[:q]
      assert_equal 'cards', r[:q_type]
      assert_equal "05/06/11 01:02:03", r[:ts]
      assert r[:query_id]
    end
  end
end
