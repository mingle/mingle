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
require File.expand_path(File.dirname(__FILE__) + '/renderable_test_helper')

class InvalidateRenderablesWithMacroCacheObserverTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit, CachingTestHelper
  
  def setup
    @decoy_project = project_without_cards
    @project = first_project
    @project.activate
    login_as_member
    Renderable.enable_caching
  end
  
  def teardown
    Renderable.disable_caching
    Project.current.teardown rescue nil
  end
  
  ##-----------
  ## Card tests
  ##-----------

  ##-----------
  ## User tests
  ##-----------

  def test_user_update_triggers_for_all_projects
    
    login_as_admin
    project_with_user_membership = with_new_project do |project|
      project.cards.create!(:name => 'a new card', :card_type_name => 'card')
      member = User.find_by_login('member')
      project.add_member(member)
    end
    
    project_without_user_membership = with_new_project do |project|
      project.cards.create!(:name => 'a new card', :card_type_name => 'card')
    end
      
    login_as_member        
    member= User.find_by_login('member')
    @project.activate
      
    project_with_user_membership.with_active_project { project_with_user_membership.cards.first.update_attributes(:description => "{{ hello }}") }
    project_without_user_membership.with_active_project { project_without_user_membership.cards.last.update_attributes(:description => "{{ hello }}") }
    
    Caches::RenderableWithMacrosCache.assert_cache_path_has_changed_for_all_renderables_with_macros(project_with_user_membership, project_without_user_membership) do
      member.update_attributes(:name => 'Joe Jones')
    end
  end
  
  def test_user_update_only_invalidates_caches_for_renderables_with_macro_content
    assert_cache_path_changed_only_for_card_with_macro(@project) do
      User.find(:first).update_attributes(:name => 'Mercedes')
    end
  end

  ##--------------------
  ## CardSelection tests
  ##--------------------
  
  def test_update_properties_requests_update_of_renderables_that_have_macros
    assert_cache_path_changed_only_for_card_with_macro(@project) do |card_without_macro, card_with_macro|
      CardSelection.new(@project, [card_without_macro]).update_properties('Status' => 'open')
    end
  end

  def test_tag_with_requests_update_of_renderable_macros
    assert_cache_path_changed_only_for_card_with_macro(@project) do |card_without_macro, card_with_macro|
      CardSelection.new(@project, [card_with_macro]).tag_with('needs-re-rendering')
    end
  end

  def test_remove_tag_requests_update_of_renderable_macros
    assert_cache_path_changed_only_for_card_with_macro(@project) do |card_without_macro, card_with_macro|
      [card_without_macro, card_with_macro].each { |card| card.tag_with('rss, foo') }
      CardSelection.new(@project, [card_without_macro]).remove_tag('rss')
    end
  end

  def test_update_relationship_property_requests_update_of_renderable_macros
    filtering_tree_project.with_active_project do |project|
      planning_story = project.relationship_property_definitions.detect { |pd| pd.name == 'Planning story' }
      
      minutia2 = project.cards.find_by_name('minutia2')
      task2 = project.cards.find_by_name('task2')
      story2 = project.cards.find_by_name('story2')
      release1 = project.cards.find_by_name('release1')
      release2 = project.cards.find_by_name('release2')
      
      release1.update_attributes(:description => "no macro here")
      release2.update_attributes(:description => "{{ hello }}")
      
      release1_last_version = release1.versions.last
      release2_last_version = release2.versions.last
      
      original_path_for_release1_last_version = cache_path(release1_last_version)
      original_path_for_release2_last_version = cache_path(release2_last_version)

      at_time_after :hours => 1 do
        CardSelection.new(project, [task2, minutia2]).update_property(planning_story.name, story2.id)
      end

      new_path_for_release1_last_version = cache_path(release1_last_version)
      new_path_for_release2_last_version = cache_path(release2_last_version)
      
      assert_equal original_path_for_release1_last_version, new_path_for_release1_last_version
      assert_not_equal original_path_for_release2_last_version, new_path_for_release2_last_version
    end
  end
  
  def cache_path(renderable)
    (renderable.has_macros ? Caches::RenderableWithMacrosCache : Caches::RenderableCache).send(:path_for, renderable)
  end  
end
