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

require File.expand_path(File.dirname(__FILE__) + '/../functional_test_helper')

class TabsControllerTest < ActionController::TestCase

  def setup
    @controller = create_controller(TabsController)
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    login_as_admin
    @project = first_project
    @project.activate
  end

  def test_should_persist_tab_positions_for_new_tabs
    tab_page = @project.pages.create!(:name => 'test page')

    favorite = @project.tabs.of_pages.create!(:favorited => tab_page)

    put :reorder, {:project_id => @project.identifier, :new_order => ["All", favorite.id, "Overview", "History", "Dependencies"]}

    assert_response :ok
    @project.reload
    display_tabs = DisplayTabs.new(@project, fake_controller)
    assert_equal ["All", "test page", "Overview", "History", "Dependencies"], display_tabs.collect(&:name)
  end

  def test_cannot_rename_tab_the_same_name_as_any_existing_user_tabs
    tab_page = @project.pages.create!(:name => 'test page')
    page_favorite = @project.tabs.of_pages.create!(:favorited => tab_page)

    view = @project.card_list_views.create_or_update(:view => { :name => "team fav" }, :filters => ['[type][is][card]'])
    view.tab_view = true
    view.save!
    view_fave = view.favorite

    put :rename, :project_id => @project.identifier, :tab => { :identifier => page_favorite.id.to_s, :new_name => view_fave.name }
    assert_response :unprocessable_entity
  end


  def test_cannot_rename_tab_the_same_name_as_any_predefined_tabs
    view = @project.card_list_views.create_or_update(:view => { :name => "team fav" }, :filters => ['[type][is][card]'])
    view.tab_view = true
    view.save!
    fave = view.favorite

    put :rename, :project_id => @project.identifier, :tab => { :identifier => fave.id.to_s, :new_name => 'history' }
    assert_response :unprocessable_entity
  end


  def test_should_update_order_for_existing_tabs
    tab_page1 = @project.pages.create!(:name => 'test page 1')
    fave1 = @project.tabs.of_pages.create!(:favorited => tab_page1)

    tab_page2 = @project.pages.create!(:name => 'test page 2')
    fave2 = @project.tabs.of_pages.create!(:favorited => tab_page2)

    @project.reload
    display_tabs = DisplayTabs.new(@project, fake_controller)

    tab1 = display_tabs.find_by_identifier fave1.id.to_s
    tab2 = display_tabs.find_by_identifier fave2.id.to_s

    put(:reorder,
        {:project_id => @project.identifier,
          :new_order => [tab1.identifier, tab2.identifier]})

    @project.reload
    display_tabs = DisplayTabs.new(@project, fake_controller)
    assert_equal [tab1,tab2].collect(&:identifier), display_tabs.to_a[0..1].collect(&:identifier)

    put(:reorder,
        {:project_id => @project.identifier,
          :new_order => [ tab2.identifier, tab1.identifier]})

    @project.reload
    display_tabs = DisplayTabs.new(@project, fake_controller)
    assert_equal [tab2,tab1].collect(&:identifier), display_tabs.to_a[0..1].collect(&:identifier)
  end

  def test_non_admins_should_not_be_able_to_reorder_tabs
    login_as_bob
    assert_raise ApplicationController::UserAccessAuthorizationError do
      put(:reorder, {:project_id => @project.identifier, :new_order => []})
    end
  end

  def test_rename_should_set_tab_order_if_not_set
    with_new_project do |project|
      @project = project
      @controller = create_controller(TabsController)

      login_as_admin
      assert_nil project.ordered_tab_identifiers

      view = project.card_list_views.create_or_update(:view => { :name => "view fav" }, :filters => ['[type][is][card]'])
      assert view.valid?
      view.tab_view = true
      view.save!

      put(:rename, :project_id => project.identifier, :tab => {:identifier => view.favorite.id.to_s, :new_name => "now, a tab"})
      assert_response :ok
      assert_equal ["Overview", view.favorite.id.to_s, "Dependencies", "All", "History"], project.reload.ordered_tab_identifiers
    end
  end

  def test_rename_wiki_tab_to_invalid_name_should_return_json_errors
    page = @project.pages.create!(:name => 'simple page')
    tab = @project.tabs.of_pages.create!(:favorited => page)

    put(:rename, :project_id => @project.identifier, :tab => {:identifier => tab.id.to_s, :new_name => ''})
    assert_response :unprocessable_entity
    json = JSON.parse(@response.body)
    assert_equal "Name can't be blank", json['message']
    assert_equal 'simple page', tab.reload.favorited.name
  end

  def test_rename_wiki_tab_to_existing_name_should_return_json_errors
    page1 = @project.pages.create!(:name => 'simple page')
    page = @project.pages.create!(:name => 'another page')
    tab = @project.tabs.of_pages.create!(:favorited => page)

    put(:rename, :project_id => @project.identifier, :tab => {:identifier => tab.id.to_s, :new_name => 'simple page'})
    assert_response :unprocessable_entity
    json = JSON.parse(@response.body)
    assert_equal "Name has already been taken", json['message']
    assert_equal 'another page', tab.reload.favorited.name
  end

  def test_should_allow_renaming_of_card_list_view_tabs
    view = @project.card_list_views.create_or_update(:view => { :name => "view fav" }, :filters => ['[type][is][card]'])
    assert view.valid?
    view.tab_view = true
    view.save!

    put(:rename, :project_id => @project.identifier, :tab => {:identifier => view.favorite.id.to_s, :new_name => "discipline"})
    assert_response :ok
    json = JSON.parse(@response.body)
    assert_equal 'discipline', json['name']

    assert_equal 'discipline', view.reload.name
  end

  def test_should_allow_renaming_of_wiki_tabs_including_attachments_and_tags
    page = @project.pages.create!(:name => 'test page 1', :content => 'woof')
    page.attach_files(sample_attachment("1.gif"))
    page.tag_with('osito')
    tab = @project.tabs.of_pages.create!(:favorited => page)

    put(:rename, :project_id => @project.identifier, :tab => {:identifier => tab.id.to_s, :new_name => "whatever 1"})
    assert_response :ok
    json = JSON.parse(@response.body)
    assert renamed_page = @project.pages.find_by_name("whatever 1")
    assert_equal 'This page was renamed to [[whatever 1]].', page.reload.content
    assert_equal 'woof', renamed_page.content
    assert_equal 1, renamed_page.attachments.size
    assert_equal ['osito'], renamed_page.tags.collect(&:name)
  end

  private

  def fake_controller
    OpenStruct.new(:current_tab => {
                     :name => 'All',
                     :type => 'All'
                   },
                   :card_context => CardContext.new(@project, {}),
                   :session => {})
  end

end
