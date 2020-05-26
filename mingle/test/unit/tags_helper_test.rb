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

class TagsHelperTest < ActionController::TestCase
  include TagsHelper
  def setup
    User.find_by_login('admin').with_current do
      name = unique_name('Zebra')
      @project = with_new_project(:name => name, :identifier => name.snake_case, :users => [User.find_by_login('member')]) do |project|
        @tags = create_tags(project, 3)
      end
      @project.add_member(User.find_by_login('member'), :readonly_member)
    end
  end

  def test_tags_data_should_return_tags_info_as_json
    expected_tags_json = @tags.inject({}) { |hash, tag| hash[tag.name] = tag.color; hash }
    assert_equal(expected_tags_json, JSON.parse(tags_data(@project)))
  end

end
