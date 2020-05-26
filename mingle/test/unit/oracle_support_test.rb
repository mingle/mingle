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

class OracleSupportTest < ActiveSupport::TestCase

  def setup
    @project = first_project
    @project.activate
    1001.times do |x|
      @project.card_list_views.create_or_update(:view => {:name => "a grid view#{x}"}, :style => 'grid')
    end
  end

  def test_eager_loading_of_has_many_associations_should_work_when_there_are_more_than_1000_associations
    assert_nothing_raised ActiveRecord::StatementInvalid do
      @project.card_list_views.to_s
    end
  end

  def test_eager_loading_of_belongs_to_associations_should_work_when_there_are_more_than_1000_associations
    assert_nothing_raised ActiveRecord::StatementInvalid do
      favorites = @project.favorites
      favorites.of_card_list_views.include_favorited.smart_sort_by(&:name)
    end
  end

end
