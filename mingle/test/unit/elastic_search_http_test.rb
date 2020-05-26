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

class ElasticSearchHttpTest < Test::Unit::TestCase
  def setup
    ElasticSearch.enable
  end

  def teardown
    ElasticSearch.disable
  end

  def test_request_handles_unexpected_search_error
    assert_raise ElasticSearch::ElasticError do
      ElasticSearch.request("wrong_method", "http://localhost", {:query => "find"})
    end

  end

  def test_auth_params_when_password_not_set
    System.clearProperty('mingle.search.password')
    assert_equal({}, ElasticSearch.auth_params())
  end

  def test_auth_params_when_password_not_set
    System.setProperty('mingle.search.user', 'foo')
    System.setProperty('mingle.search.password', 'bar')
    assert_equal({:basic_auth => {:username => 'foo', :password => 'bar'}}, ElasticSearch.auth_params())
  end
end
