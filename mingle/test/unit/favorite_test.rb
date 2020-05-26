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

# Tags: favorites
class FavoriteTest < ActiveSupport::TestCase

  def setup
    @project = first_project
    @project.activate
    @member = login_as_member
    @page = @project.pages.first
  end

  def test_using_card_type
    first_type = @project.card_types.first
    view1 = @project.card_list_views.create_or_update(:view => {:name => 'a grid view'}, :style => 'grid', :group_by => 'type', :lanes => first_type.name)
    view2 = @project.card_list_views.create_or_update(:view => {:name => 'a list view'}, :style => 'list', :columns => 'type')
    assert_equal [view1.favorite], @project.favorites.of_card_list_views.using(first_type)
  end

  def test_named_scope_can_be_smart_sorted
    view1 = @project.card_list_views.create_or_update(:view => {:name => 'a grid view'}, :style => 'grid')
    view2 = @project.card_list_views.create_or_update(:view => {:name => 'B grid view'}, :style => 'grid')
    f1 = @project.favorites.create(:favorited => @project.pages.create(:name => '2 banana'))
    f2 = @project.favorites.create(:favorited => @project.pages.create(:name => '11 banana'))
    @project.favorites.reload
    assert_equal [f1, f2], @project.favorites.of_team.of_pages.smart_sort_by(&:name)
    assert_equal [view1.favorite, view2.favorite], @project.favorites.of_team.of_card_list_views.smart_sort_by(&:name)
  end

  def test_to_params_of_page
    favorite = @project.favorites.create(:favorited => @project.pages.first)
    assert_equal @project.pages.first.link_params.merge(:favorite_id => favorite.id), favorite.to_params
  end
  def test_to_params_of_card_list_view
    view = @project.card_list_views.create_or_update(:view => {:name => 'a grid view'}, :style => 'grid')
    favorite = @project.favorites.create(:favorited => view)
    assert_equal({:controller => 'cards', :action => 'index', :view => 'a grid view', :favorite_id => favorite.id}, favorite.to_params)
  end
  def test_to_params_of_personal_card_list_view
    view = @project.card_list_views.create_or_update(:view => {:name => 'a grid view'}, :style => 'grid')
    favorite = @project.favorites.personal(User.current).create(:favorited => view)
    assert_equal(view.link_params.merge(:favorite_id => favorite.id), favorite.to_params)
  end

  def test_to_params_of_tab_view
    view = @project.card_list_views.create_or_update(:view => {:name => 'a grid view'}, :style => 'grid')
    favorite = view.favorite
    favorite.update_attribute(:tab_view, true)

    assert_equal({:controller => 'cards', :action => 'list', :style => 'grid', :tab => 'a grid view', :favorite_id => favorite.id}, favorite.to_params)
  end

  def test_get_all_team_favorite
    with_new_project do |project|
      f1 = project.favorites.of_pages.create(:favorited => project.pages.create(:name => 'p1'))
      f2 = project.favorites.of_pages.create(:favorited => project.pages.create(:name => 'p2'), :user_id => @member.id)
      assert_equal [f1], project.favorites.of_pages.of_team
    end
  end

  def test_get_all_personal_favorites
    with_new_project do |project|
      f1 = project.favorites.of_pages.create(:favorited => project.pages.create(:name => 'p1'))
      f2 = project.favorites.of_pages.personal(@member).create(:favorited => project.pages.create(:name => 'p2'))
      assert_equal [f2], project.favorites.of_pages.personal(@member)
      assert_equal @member.id, f2.user_id
    end
  end

  def test_anonymous_user_can_not_have_personal_favorite
    with_new_project do |project|
      f1 = project.favorites.of_pages.of_team.create(:favorited => project.pages.create(:name => 'p1'))
      f2 = project.favorites.of_pages.personal(@member).create(:favorited => project.pages.create(:name => 'p2'))
      assert_equal [], project.favorites.of_pages.personal(User::AnonymousUser.new)
    end
  end

  def test_can_make_into_a_tab
    favorite = @project.favorites.create(:favorited => @page)
    favorite.adjust(:favorite => true, :tab => false)
    assert favorite.favorite?
    assert !favorite.tab_view?

    # make tab
    favorite.adjust(:favorite => false, :tab => true)
    assert favorite.tab_view?
    assert !favorite.favorite?
  end

  def test_non_admin_cannot_remove_from_tabs
    favorite = @project.favorites.create(:favorited => @page)
    favorite.adjust(:favorite => false, :tab => true) # make tab
    favorite.adjust(:favorite => true, :tab => false)
    assert favorite.tab_view?
    assert !favorite.favorite?
  end

  def test_mingle_admin_can_remove_from_tabs
    favorite = @project.favorites.create(:favorited => @page)
    login_as_admin

    favorite.adjust(:favorite => false, :tab => true) # make tab
    favorite.adjust(:favorite => true, :tab => false)
    assert !favorite.tab_view?
    assert favorite.favorite?

    favorite.adjust(:favorite => false, :tab => false)
    assert_nil Favorite.find_by_id(favorite.id)
  end

  def test_project_admin_can_remove_from_tabs
    favorite = @project.favorites.create(:favorited => @page)
    login_as_proj_admin

    favorite.adjust(:favorite => false, :tab => true) # make tab
    favorite.adjust(:favorite => true, :tab => false)
    assert !favorite.tab_view?
    assert favorite.favorite?

    favorite.adjust(:favorite => false, :tab => false)
    assert_nil Favorite.find_by_id(favorite.id)
  end

  def test_can_retrieve_a_created_a_personal_favorite
    personal_favorite = @project.favorites.personal(@member).create(:favorited => @page)
    assert_equal [personal_favorite], @member.favorites.reload
  end

  def test_personal_favorites_does_not_include_team_favorites
    @project.favorites.create(:favorited => @page)
    assert_equal [], @member.favorites.reload
  end

  def test_cannot_retrieve_another_members_personal_favorite
    me = @project.users.first
    someone_else = create_user!
    @project.add_member(someone_else)

    my_personal_favorite = @project.favorites.personal(me).create(:favorited => @page)
    someone_elses_favourite = @project.favorites.personal(someone_else).create(:favorited => @page)

    assert_equal [my_personal_favorite], me.favorites.reload
  end

  # bug 8669
  def test_destroy_also_destroys_associated_card_list_view
    personal_view = @project.card_list_views.create_or_update(:view => { :name => 'personal' }, :filters => ["[status][is][open]"], :user_id => @project.users.first)
    favorite = personal_view.favorite
    favorite.destroy
    assert_nil CardListView.find_by_id(personal_view.id)
    assert_nil Favorite.find_by_id(favorite.id)
  end

  # bug 8669
  def test_destroy_does_not_destroy_underlying_page
    favorite = @project.favorites.create(:favorited => @page)
    favorite.destroy
    assert Page.find_by_id(@page.id)
  end

  def test_to_xml_version_1_should_include_project_id
    favorite = @project.favorites.create(:favorited => @page)
    xml = favorite.to_xml(:version => 'v1')
    document = REXML::Document.new(xml)
    assert_equal @project.id.to_s, document.element_text_at('/favorite/project_id')
    assert_not document.elements_at('/favorite/*').map(&:name).include?('project')
  end

  def test_to_xml_version_2_should_include_project_rather_than_project_id
    favorite = @project.favorites.create(:favorited => @page)
    xml = favorite.to_xml(:version => 'v2', :view_helper => OpenStruct.new.mock_methods({:rest_project_show_url => 'url_for_project'}))
    document = REXML::Document.new(xml)
    assert_equal 'url_for_project', document.attribute_value_at('/favorite/project/@url')
    assert_equal ['identifier', 'name'], document.elements_at('/favorite/project/*').map(&:name).sort
    assert_not document.elements_at('/favorite/*').map(&:name).include?('project_id')
  end
end
