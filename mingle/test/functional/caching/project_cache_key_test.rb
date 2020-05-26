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


class ProjectCacheKeyTest < ActionController::TestCase
  include CachingTestHelper

  def test_different_project_should_have_different_project_cache_key
    assert_equal key(first_project.identifier), key(first_project.identifier)
    assert_not_equal key(first_project.identifier), key(project_without_cards.identifier)
  end

  def test_delete_from_cache
    key_before_delete = key(first_project.identifier)
    KeySegments::ProjectCache.delete_from_cache(first_project.identifier)
    assert_not_equal key_before_delete, key(first_project.identifier)
  end

  private
  
  def key(project_identifier)
    KeySegments::ProjectCache.new(project_identifier).to_s
  end
end
