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

#Tags:
class ProjectStructureKeyTest < ActionController::TestCase
  include CachingTestHelper,KeySegments

  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def test_create_property_definition_should_change_key
    with_new_project do |project|
      assert_key_changed_after(project) do
        project.create_any_text_definition!(:name => 'status', :is_numeric  =>  false)
        project.reload.update_card_schema
      end
    end
  end

  def test_create_property_definition_in_another_project_should_not_change_key
    assert_key_not_changed_after(first_project) do
      with_new_project do |project|
        project.create_any_text_definition!(:name => 'status', :is_numeric  =>  false)
        project.reload.update_card_schema
      end
    end
  end

  def test_update_property_definition_should_change_key
    with_new_project do |project|
      status = project.create_any_text_definition!(:name => 'statas', :is_numeric  =>  false)
      assert_key_changed_after(project) do
        status.update_attribute :name, 'status'
        status.save!
        project.reload.update_card_schema
      end
    end
  end

  def test_destroy_property_definition_should_change_key
    with_new_project do |project|
      status = project.create_any_text_definition!(:name => 'status', :is_numeric  =>  false)
      assert_key_changed_after(project) do
        status.destroy
      end
    end
  end

  def test_update_card_type_should_change_key
    with_new_project do |project|
      card_type = project.card_types.create :name => 'bog'
      assert_key_changed_after(project) do
        card_type.update_attribute :name, 'bug'
        card_type.save!
      end
    end
  end

  def test_update_card_default_should_change_key
    card_type = @project.card_types.first
    card_defaults = card_type.card_defaults
    assert_key_changed_after(@project) do
      card_defaults.update_attribute :description, 'I hate GFW'
    end
  end

  def test_update_tag_should_change_key
    assert_key_changed_after(@project) do
      @project.tags.find_by_name('first_tag').update_attribute :name, 'first_taggy'
    end
  end

  def test_safe_delete_tag_should_change_key
    assert_key_changed_after(@project) do
      @project.tags.find_by_name('first_tag').safe_delete
    end
  end

  def test_create_tag_should_not_change_key
    assert_key_not_changed_after(@project) do
      @project.tags.create(:name => 'a tag')
    end
  end

  def test_transition_update_should_change_key
    assert_key_changed_after(@project) do
      create_transition(@project, 'close', :required_properties => {:status => 'open'}, :set_properties => {:status => 'closed'})
    end
  end

  def test_update_tag_name_should_change_card_key
    first_card = @project.cards.find_by_number(1)
    first_card.tag_with(['foo', 'bar']).save!
    assert_key_changed_after(@project) do
      @project.tags.find_by_name("foo").update_attribute(:name, 'fu')
    end
  end

  def test_create_group_should_change_key
    login_as_admin
    assert_key_changed_after(@project) do
      @project.groups.create!(:name => "Group")
    end
  end

  def test_destroy_group_should_change_key
    group = @project.user_defined_groups.create!(:name => "Group")
    assert_key_changed_after(@project) do
      group.destroy
    end
  end

  def test_update_group_memberships_should_change_key
    login_as_admin
    group = @project.user_defined_groups.create!(:name => "Group")
    first_user = @project.users.first
    assert_key_changed_after(@project) do
      group.add_member(first_user)
    end

    assert_key_changed_after(@project) do
      group.remove_member(first_user)
    end
  end

  def test_add_remove_team_member_should_change_key
    login_as_admin
    u = create_user!
    assert_key_changed_after(@project) do
      @project.add_member(u)
    end

    assert_key_changed_after(@project) do
      @project.remove_member(u)
    end
  end

  def test_change_team_member_permission_should_change_key
    login_as_admin
    u = create_user!
    @project.add_member(u, :full_member)

    assert_key_changed_after(@project) do
      @project.add_member(u, :project_admin)
    end
  end

  def test_project_key_generation_should_be_cacheds
    assert_equal key(first_project), key(first_project)
  end

  def test_project_structure_key_should_be_cached
    structure_1 = CacheKey.project_structure_key(@project)
    assert_equal structure_1, CacheKey.project_structure_key(@project)
  end

  def test_project_structure_key_should_cache_by_project
    assert_not_equal CacheKey.project_structure_key(@project), CacheKey.project_structure_key(card_query_project)
  end

  def test_should_clear_project_cache_key_when_structure_key_get_updated
    cached_project = ProjectCacheFacade.instance.load_project_without_cache(@project.identifier)
    ProjectCacheFacade.instance.cache_project(cached_project)

    @project.cache_key.touch_structure_key
    assert_not_same cached_project, ProjectCacheFacade.instance.load_project(@project.identifier)
  end

  def test_reset_auto_enrolled_projects_change_project_structure_key
    autoenroll_all_users('readonly')
    assert_key_changed_after(@project) do
      Project.reset_auto_erolled_projects
    end
  end

  private
  def key(project)
    project.cache_key.structure_key
  end
end
