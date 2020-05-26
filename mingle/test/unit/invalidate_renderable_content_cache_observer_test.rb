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

#Tags:
class InvalidateRenderableContentCacheObserverTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit, CachingTestHelper

  def setup
    @project = first_project
    @project.activate
    login_as_member
    Renderable.enable_caching
  end

  def teardown
    Renderable.disable_caching
    Project.current.teardown rescue nil
  end

  ##----------------------
  ## ProjectVariable tests
  ##----------------------

  def test_project_variable_clear_team_member_trigger
    member = User.find_by_login('member')
    variable = create_plv!(@project,
      :name => 'a variable',
      :data_type => ProjectVariable::USER_DATA_TYPE,
      :value => member.id)
    assert_cache_path_has_changed_for_all_renderables(@project) do
      variable.clear_team_member(member)
    end
  end

  def test_project_variable_create_update_and_destroy_triggers
    variable = nil

    assert_cache_path_has_changed_for_all_renderables(@project) do
      variable = create_plv!(@project, :name => 'Current Iteration', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => "2")
    end

    assert_cache_path_has_changed_for_all_renderables(@project) do
      variable.name = 'new name'
      variable.save!
    end

    assert_cache_path_has_changed_for_all_renderables(@project) do
      variable.destroy
    end
  end

  ##------------------
  ## BulkDestroy tests
  ##------------------

  def test_bulk_destroy_trigger
    card_selection_project.with_active_project do |project|
      card_selection = CardSelection.new(project.reload, project.cards)
      result = nil
      assert_cache_path_has_changed_for_all_renderables(project) do
        result = card_selection.destroy
      end
      assert result
      assert project.reload.cards.empty?
    end
  end

  ##-----------------------
  ## EnumerationValue tests
  ##-----------------------

  def test_enumeration_value_create_update_and_destroy_triggers
    enum = nil
    assert_cache_path_has_changed_for_all_renderables(@project) do
      enum = @project.find_property_definition('status').create_enumeration_value(:value => 'new status')
    end

    assert_cache_path_has_changed_for_all_renderables(@project) do
      enum.value = 'a new value'
      enum.save!
    end

    assert_cache_path_has_changed_for_all_renderables(@project) do
      enum.destroy
    end
  end

  ##------------------------
  ## PropertyDefintion tests
  ##------------------------

  def test_is_observed_for_refreshing_renderable_cache_on_cud
    with_new_project do |project|
      login_as_member
      project.cards.create!(:name => 'some card', :card_type_name => 'Card')
      prop_def = nil

      assert_cache_path_has_changed_for_all_renderables(project) do
        prop_def = project.create_text_list_definition!(:name => 'status')
      end

      project.reload.update_card_schema
      project.activate

      assert_cache_path_has_changed_for_all_renderables(project) do
        prop_def.name = 'a new name'
        prop_def.save!
      end

      assert_cache_path_has_changed_for_all_renderables(project) do
        prop_def.destroy
      end
    end
  end

  ##---------------
  ## CardType tests
  ##---------------

  def test_card_type_create_update_and_destroy_triggers
    new_type = nil

    assert_cache_path_has_changed_for_all_renderables(@project) do
      new_type = @project.card_types.create!(:name => 'a new type')
    end

    assert_cache_path_has_changed_for_all_renderables(@project) do
      new_type.name = 'a new type name'
      new_type.save!
    end

    assert_cache_path_has_changed_for_all_renderables(@project) do
      new_type.destroy
    end
  end

  def test_should_change_cache_paths_for_renderables_with_and_without_cache_on_project_structure_change
    card_without_macro = @project.cards.create!(:name => 'card without macro', :card_type_name => 'card', :description => "no macro here")
    card_with_macro = @project.cards.create!(:name => 'card with macro', :card_type_name => 'card', :description => "{{ hello }}")
    assert_cache_path_has_changed_for_all_renderables(@project) do
      @project.card_types.first.update_attributes(:name => 'Booya!')
    end
  end

  ##-------------------
  ## CardListView tests
  ##-------------------

  def test_card_list_view_create_update_and_destroy_test
    new_view = nil

    assert_cache_path_has_changed_for_all_renderables(@project) do
      new_view = @project.card_list_views.create_or_update(:view => {:name => 'a brand new view'}, :style => 'grid', :group_by => 'status')
    end

    assert_cache_path_has_changed_for_all_renderables(@project) do
      new_view.name = 'an all new original name'
      new_view.save!
    end

    assert_cache_path_has_changed_for_all_renderables(@project) do
      new_view.destroy
    end
  end

  ##---------------------
  ## ProjectsMember tests
  ##---------------------

  def test_projects_member_create_update_and_destroy_triggers
    member = User.find_by_login('member')
    clear_all_existing_user_memberships_for(@project)

    assert_cache_path_has_changed_for_all_renderables(@project) do
      @project.add_member(member)
    end

    assert_cache_path_has_changed_for_all_renderables(@project) do
      @project.add_member(member, :project_admin)
    end
    login_as_admin
    assert_cache_path_has_changed_for_all_renderables(@project) do
      @project.remove_member(member)
    end
  end

  ##------------------------
  ## TreeConfiguration tests
  ##------------------------

  def test_tree_configuration_create_update_and_destroy_triggers
    with_new_project do |project|
      login_as_member
      project.cards.create!(:name => 'some card', :card_type_name => 'Card')
      configuration = nil

      assert_cache_path_has_changed_for_all_renderables(project) do
        configuration = project.tree_configurations.create!(:name => 'three_level_tree')
      end

      assert_cache_path_has_changed_for_all_renderables(project) do
        configuration.name = '3 level tree'
        configuration.save!
      end

      type_release = project.card_types.create!(:name => 'release')
      type_iteration = project.card_types.create!(:name => 'iteration')
      assert_cache_path_has_changed_for_all_renderables(project) do
        configuration.update_card_types({
          type_release => {:position => 0, :relationship_name => 'release'},
          type_iteration => {:position => 1}
        })
      end

      assert_cache_path_has_changed_for_all_renderables(project) do
        configuration.destroy
      end
    end
  end

  ##-----------
  ## Page tests
  ##-----------

  def test_page_create_and_destroy_triggers
    login_as_member
    page = nil

    assert_cache_path_has_changed_for_all_renderables(@project) do
      page = @project.pages.create(:name => 'a very new page')
    end

    assert_cache_path_has_changed_for_all_renderables(@project) do
      User.with_first_admin { page.destroy }
    end
  end

  def test_page_update_does_not_trigger_invalidation_on_cards_and_old_page_versions
    login_as_member
    page = @project.pages.create(:name => 'a very new page')

    renderables = @project.cards + @project.card_versions + @project.pages + @project.page_versions - [page.versions.last]
    original_paths = renderables.collect { |renderable| Caches::RenderableCache.send(:path_for, renderable) }

    page.update_attributes(name: 'not so new anymore')

    new_paths = renderables.collect { |renderable| Caches::RenderableCache.send(:path_for, renderable) }
    assert_equal original_paths, new_paths
  end

  ##--------------
  ## Project tests
  ##--------------

  def test_creation_of_project_deletes_entire_renderable_cache_for_all_projects
    login_as_admin
    existing_project = @project
    assert_cache_path_has_changed_for_all_renderables(existing_project) do
      project_name = unique_project_name
      Project.create!(:name => project_name, :identifier => project_name)
    end
  end

  def test_update_of_project_deletes_entire_renderable_cache_for_all_projects_in_support_of_cross_project_reporting
    login_as_admin
    existing_project1 = @project
    existing_project2 = card_selection_project
    [existing_project1, existing_project2].each do |project|
      assert_cache_path_has_changed_for_all_renderables(project) do
        existing_project1.with_active_project do |ep1|
          ep1.precision = 8
          ep1.save!
        end
      end
    end
  end
end
