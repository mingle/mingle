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

class CardPopupDataCacheTest < ActionController::TestCase
  include TreeFixtures::PlanningTree
  include CachingTestHelper
  
  def setup
    @project = first_project
    @project.activate
    login_as_member
    @first_card = @project.cards.find_by_number(1)
    @another_card = @project.cards.find_by_number(4)
  end

  def test_cache_path_depend_on_card_key
    assert_include KeySegments::Card.new(@first_card).to_s, cache_path(@first_card)
    assert_not_include KeySegments::Card.new(@another_card).to_s, cache_path(@first_card)
  end

  def test_different_login_user_has_different_cache_path
    assert_cache_path_changed_after(@first_card) do
      login_as_bob
    end
  end

  def test_user_role_changed_result_in_cache_path_change
    assert_cache_path_changed_after(@first_card) do
      @project.add_member(User.find_by_login('member'), :project_admin)
      @project.reload
    end
  end

  def test_add_property_definition_should_regenerate_cache_path
    with_new_project do |project|
      card = create_card!(:name => 'card1')
      ThreadLocalCache.clear!
      assert_cache_path_changed_after(card) do
        project.create_any_text_definition!(:name => 'status', :is_numeric  =>  false)
        project.reload.update_card_schema
      end
    end
  end

  def test_update_of_user_should_make_cache_path_different
    assert_cache_path_changed_after(@first_card) do
      member = User.find_by_login('member')
      member.email = 'new_one@example.com'
      member.save!
    end
  end

  def test_adding_members_from_groups_should_make_cache_path_different
    assert_cache_path_changed_after(@first_card) do
      perform_as('admin@email.com') {
        create_group("jimmy_ba", [@project.users.first])
        @project.reload
      }
    end
  end

  def test_removing_members_from_groups_should_make_cache_path_different
    first_user = @project.users.first
    jimmy_group = perform_as('admin@email.com') { create_group("jimmy_ba", [first_user]) }

    assert_cache_path_changed_after(@first_card) do
      perform_as('admin@email.com') { jimmy_group.remove_member(first_user) }
      @project.reload
    end
  end

  private

  def cache_path(card)
    Keys::CardPopupData.new.path_for(card)
  end
end
