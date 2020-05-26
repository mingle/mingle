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

require File.expand_path(File.dirname(__FILE__) + '/project_import_export_test_helper')

# this test will fail if there's residue in the database
# and we are having trouble with transactionality in this test
# let's ensure there's nothing weird there before we start the test
class ImportExportFavoritesTest < ActiveSupport::TestCase
  include ProjectImportExportTestHelper

  def test_export_and_import_with_cards_favorite
    @user = login_as_member
    @project = with_new_project do |project|
      setup_property_definitions :status => ['new', 'open', 'fixed'], :iteration => [1,2], :release => [1]
      view  = CardListView.find_or_construct(project, {:style => 'list', :columns => 'status,iteration', :filters => ['[status][is][open]']})
      view.name = 'saved_view'
      view.save!

      favorite_page = project.pages.create!(:name => "Favorite page")

      Favorite.new(:project_id => project.id, :favorited_type => view.class.name, :favorited_id => view.id, :tab_view => false).save!
      project
    end
    @export_file = create_project_exporter!(@project, @user, :template => true).export
    @project_importer = create_project_importer!(User.current, @export_file)
    clone = @project_importer.process!
    assert_equal 2, clone.favorites_and_tabs.size
  end

  # Bug 4743.
  def test_should_remove_page_tabs_and_favorites_when_pages_are_not_included_with_template
    @user = login_as_member
    @project = with_new_project do |project|
      tab_page = project.pages.create!(:name => "Tab page")
      Favorite.new(:project_id => project.id, :favorited_type => Page.name, :favorited_id => tab_page.id     , :tab_view => true).save!
      favorite_page = project.pages.create!(:name => "Favorite page")
      Favorite.new(:project_id => project.id, :favorited_type => Page.name, :favorited_id => favorite_page.id, :tab_view => false).save!
      project
    end

    @export_file = create_project_exporter!(@project, User.current, :template => true).export

    @project_importer = create_project_importer!(User.current, @export_file)
    clone = @project_importer.process!(:include_pages => false)
    assert clone.pages.empty?
    assert clone.page_versions.empty?
    assert_equal 0, clone.favorites_and_tabs.size
  end

  # bug #9904
  def test_should_not_import_personal_favorites_when_importing_template
    @user = login_as_member
    project_import = create_project_importer!(User.current, "#{Rails.root}/test/data/bug_9904_import_template_cont_template.mingle")
    imported_project = project_import.process!
    assert_equal 0, imported_project.favorites.count
    assert_equal 0, imported_project.card_list_views.count
  end

  # bug #9904
  def test_should_import_personal_favorites_when_importing_project
    @user = login_as_member
    export_file = nil
    with_new_project(:users => [@user]) do |project|
      project.card_list_views.create_or_update(:view => {:name => 'Team'}, :style => 'list', :user_id => nil)
      project.card_list_views.create_or_update(:view => {:name => 'Personal'}, :style => 'list', :user_id => @user.id)
      export_file = create_project_exporter!(project, @user).export
    end
    imported_project = create_project_importer!(User.current, export_file).process!
    imported_project.with_active_project do |project|
      assert_equal 2, project.favorites.count
    end
  end

  # bug #9904
  def test_create_from_bad_template_should_not_import_personal_favorites
    @user = login_as_member
    template = with_new_project(:users => [@user]) do |project|
      project.card_list_views.create_or_update(:view => {:name => 'Personal'}, :style => 'list', :user_id => @user.id)
      project.favorites.of_pages.personal(@user).create(:favorited => project.pages.create(:name => 'personal'))
      project.update_attribute(:template, true)
    end

    with_new_project do |project|
      project.reload.merge_template(template.reload)
      assert_equal 0, project.card_list_views.count
      assert_equal 0, project.favorites.count
    end
  end

  def test_should_map_personal_favorites_user_id_to_new_user_id_after_import
    @user = login_as_member

    foo = create_user!(:login => 'foo', :name => 'foo')

    project = with_new_project(:users => [foo]) do |project|
      project.card_list_views.create_or_update(:view => {:name => 'foo list'}, :style => 'list', :user_id => foo.id)
      project.favorites.of_pages.personal(foo).create(:favorited => project.pages.create(:name => 'foo page'))
    end

    export_file = create_project_exporter!(project, User.current).export
    change_user_id(foo.id + 10, foo.id)
    foo = User.find_by_login('foo')

    imported_project = create_project_importer!(User.current, export_file).process!
    assert_equal 1, imported_project.card_list_views.count
    assert_equal foo.id, imported_project.card_list_views.first.favorite.user_id
    assert_equal 1, imported_project.favorites.of_pages.count
    assert_equal foo.id, imported_project.favorites.of_pages.first.user_id
  end

  def test_should_round_trip_built_in_tab_orders
    user = login_as_member
    tab_name_order = nil
    project = with_new_project do |project|
      tabs = load_tabs(project)
      original_order = tabs.sortable_tabs.collect(&:identifier)
      new_order = original_order.shuffle
      assert tabs.reorder!(new_order)
      tab_name_order = tabs.map(&:name)
    end

    @export_file = create_project_exporter!(project, user).export
    project_importer = create_project_importer!(User.current, @export_file)
    clone = project_importer.process!
    assert project_importer.errors.empty?
    clone.reload
    tabs = load_tabs(clone)
    assert_equal tab_name_order, tabs.collect(&:name)
  end

  def test_should_round_trip_user_created_tab_orders
    user = login_as_member
    tab_name_order = nil
    project = with_new_project do |project|
      setup_property_definitions :status => ['new', 'open', 'fixed'], :iteration => [1,2], :release => [1]
      view  = CardListView.find_or_construct(project, {:style => 'list', :columns => 'status,iteration', :filters => ['[status][is][open]']})
      view.name = 'saved_view'
      view.save!
      favorite_page = project.pages.create!(:name => "Favorite page")
      Favorite.create!(:project_id => project.id, :favorited_type => view.class.name, :favorited_id => view.id, :tab_view => true)
      Favorite.create!(:project_id => project.id, :favorited_type => 'Page', :favorited_id => favorite_page.id, :tab_view => true)

      tabs = load_tabs(project)
      original_order = tabs.sortable_tabs.collect(&:identifier)
      new_order = original_order.shuffle
      assert tabs.reorder!(new_order)
      tab_name_order = tabs.map(&:name)

      @export_file = create_project_exporter!(project, user).export
      project_importer = create_project_importer!(User.current, @export_file)
      clone = project_importer.process!
      assert project_importer.errors.empty?
      clone.reload
      tabs = load_tabs(clone)
      assert_equal tab_name_order, tabs.collect(&:name)
    end
  end


  private

  def load_tabs(project)
    controller = OpenStruct.new(:current_tab => {
                                    :name => 'All',
                                    :type => 'All'
                                },
                                :card_context => CardContext.new(project, {}),
                                :session => {})
    class << controller
      include UserAccess
    end
    DisplayTabs.new(project, controller)
  end

end
