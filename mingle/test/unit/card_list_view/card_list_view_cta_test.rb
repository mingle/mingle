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

class CardListViewCtaTest < ActiveSupport::TestCase

  def setup
    login_as_member
  end

  def test_ready_for_cta
    with_first_project do |project|
      view = CardListView.find_or_construct(project, :style => 'grid', :group_by => 'status')
      view.name = 'group by status'
      view.save!

      assert view.ready_for_cta?
    end
  end

  def test_should_not_be_ready_for_cta_when_there_is_error_in_filters
    with_first_project do |project|
      card_list_view = CardListView.construct_from_params(project, {:tf_story => ["[status][is][(current status)]"], :tree_name => tree_name = 'filtering tree'})
      view = CardListView.find_or_construct(project,
                                            :filters => ["[Iteration][is][(current iteration)]"],
                                            :style => 'grid',
                                            :group_by => 'status')
      view.name = 'group by status'
      view.save!

      assert !view.ready_for_cta?, "should not ready for invalid project variable"
    end
  end
end
