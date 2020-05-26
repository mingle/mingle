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

class CardTransitionCacheTest < ActionController::TestCase
  include CachingTestHelper
  
  def setup
    @project = first_project
    @project.activate
    login_as_member
    @card = create_card!(:name => 'card status is open', :status => 'open' )    
  end
  
  def test_cache_path_should_change_after_card_changed
    assert_cache_path_changed_after(@card) do
      @card.update_attribute(:cp_status, 'closed')
    end
  end
  
  def test_cache_path_should_change_after_new_transition_created
    assert_cache_path_changed_after(@card) do
      create_transition(@project, 'close', :set_properties => {:status => 'closed'})
    end
  end
  
  def test_different_user_should_use_different_cache_path
    assert_cache_path_changed_after(@card) do
      login_as_bob
    end
  end
  
  private
  def cache_path(card)
    Keys::CardTransition.new.path_for(card)
  end
end
