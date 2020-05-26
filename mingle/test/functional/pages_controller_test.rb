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
require File.expand_path(File.dirname(__FILE__) + '/../unit/renderable_test_helper')

# Tags: page, favorites
class PagesControllerTest < ActionController::TestCase
  include ::RenderableTestHelper::Functional

  def setup
    @controller = create_controller PagesController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @member_user = User.find_by_login('member')
    login_as_member

    @project = create_project :users => [@member_user]
    setup_property_definitions :feature => [], :status => [], :old_type => []
    setup_numeric_property_definition('size', [])
  end

  def test_page_create_should_escape_manually_entered_macros
    post :create, :project_id => @project.identifier, :page => {:name => 'manual macro', :content => "{{ project }}"}
    assert_equal ManuallyEnteredMacroEscaper.new("{{ project }}").escape, @project.pages.find_by_name("manual macro").content
  end

  def test_bang_bang_is_escaped
    post :create, :project_id => @project.identifier, :page => {:name => 'manual bang bang', :content => '<p>!bang!</p>'}
    assert_equal "<p>&#33;bang&#33;</p>", @project.pages.find_by_name("manual bang bang").content
  end

  def test_page_create_should_preserve_macros_created_by_editor
    post :create, :project_id => @project.identifier, :page => {:name => 'macro', :content => create_raw_macro_markup("{{ project }}")}
    assert_equal "{{ project }}", @project.pages.find_by_name("macro").content
  end

  def test_page_update_should_escape_manually_entered_macros
    page = @project.pages.create!(:name => 'manual macro', :content => "nothing")
    post :update, :project_id => @project.identifier, :page_identifier => 'manual_macro', :page => {:content => "{{ project }}"}
    assert_equal ManuallyEnteredMacroEscaper.new("{{ project }}").escape, page.reload.content
  end

  def test_page_update_should_preserve_macros_created_by_editor
    page = @project.pages.create!(:name => 'manual macro', :content => "nothing")
    post :update, :project_id => @project.identifier, :page_identifier => 'manual_macro', :page => {:content => create_raw_macro_markup("{{ project }}")}
    assert_equal "{{ project }}", page.reload.content
  end

  def test_creating_page_with_attachment
    a1 = @project.attachments.create(:file => sample_attachment("1.gif"))
    a2 = @project.attachments.create(:file => sample_attachment("2.gif"))
    page = perform_with_default_options :create, [a1.id, a2.id], 'very_new_wiki_page'
    assert_redirected_to :action => 'show'
    assert_attachments 2, page.attachments
  end

  def test_create_with_dangling_attachments
    a1 = @project.attachments.create(:file => sample_attachment("1.txt"))
    a2 = @project.attachments.create(:file => sample_attachment("2.txt"))

    options = default_options.merge("pending_attachments" => [a1.id, a2.id])
    options["page"].merge!("name" => "dangling attachments")
    post(:create, options)

    assert_redirected_to :action => :show
    page = @project.pages.find_by_name("dangling attachments")

    assert_equal 2, page.attachments.size
    assert_equal [a1.id, a2.id].sort, page.attachments.map(&:id).sort
  end

  def test_empty_file_should_not_create_attachment
    attachments_before = Attachment.find(:all).size
    page = perform_with_default_options :create, [], "very_new_wiki_page"
    assert_redirected_to :action => 'show'
    assert_equal attachments_before, Attachment.find(:all).size
  end

  def test_update_strips_trailing_whitespace_from_page_content
    page = @project.pages.create!(:name => 'testeroo', :content => 'some content')
    post('update', {:commit => 'Publish', :project_id => @project.identifier, :page_identifier => 'testeroo',
                    :attachments => {},
                    :page => {:name => 'testeroo', :content => 'some content  '}})
    assert_equal 1, page.reload.versions.count
  end

  def test_charts_have_preview_set_to_true_in_preview
    page = @project.pages.create!(:name => 'Blah', :content => '{{ pie-chart data: SELECT Feature, SUM(Size) }}')
    post :preview, {:project_id => @project.identifier, :page_identifier => 'Blah',
                    :page => {:id => page, :content => '{{ pie-chart data: SELECT Status, SUM(Size) }}', :name => 'Blah'}}
    assert_include "id=\"piechart-Page-#{page.id}-1-preview\"", @response.body
  end

  def test_can_render_preview_charts_from_session
    # this test puts a dodgy chart in the preview data in the session and expects
    # an error when rendering from that it's the only way I can assure the data is
    # being rendered from the session

    # first we render one that is good, to check that works
    @request.session[:renderable_preview_content] = '{{ pie-chart data: SELECT Feature, SUM(Size) }}' # good chart
    get :chart_data, :pagename => 'Blah', :project_id => @project.identifier, :type => 'pie-chart', :position => 1, :preview => true
    assert_response :success
    assert_equal 'pie', JSON.parse!(@response.body)['data']['type']

    # now we render a dodgy chart, it should not work
    @request.session[:renderable_preview_content] = '{{ pie-chart }}'
    get :chart_data, :pagename => 'Blah', :project_id => @project.identifier, :type => 'pie-chart', :position => 1, :preview => true
    assert_equal '', @response.body
  end

  # test for bug #705
  def test_can_link_to_attachments_in_preview
    MingleConfiguration.with_secure_site_u_r_l_overridden_to("") do
      MingleConfiguration.with_site_u_r_l_overridden_to("http://test.host") do
        page = @project.pages.create!(:name => 'some page')
        page.attach_files(sample_attachment('IMG_1.jpg'))
        page.save!
        attachment = page.attachments.first
        post :preview, {:project_id => @project.identifier, :page_identifier => 'Blah',
                        :page => {:id => page, :content => '!IMG_1.jpg!', :name => 'Blah'}}
        assert_tag :img, :attributes => { :src => attachment_url(attachment) }
      end
    end
  end

  def test_can_render_chart_data
    setup_property_definitions :feature => ['Dashboard', 'Applications', 'Rate calculator', 'Profile builder'],
      :size => [1,2,3,4,5], :status => ['Closed'], :old_type => ['Story']
    create_card!(:name => 'Blah', :feature => 'Dashboard', :size => '1', :status => 'Closed', :old_type => 'Story')
    create_card!(:name => 'Blah', :feature => 'Applications', :size => '1', :old_type => 'Story')
    create_card!(:name => 'Blah', :feature => 'Applications', :size => '2', :old_type => 'Story')
    create_card!(:name => 'Blah', :feature => 'Rate calculator', :size => '3', :old_type => 'Story')
    create_card!(:name => 'Blah', :feature => 'Rate calculator', :size => '2', :status => 'Closed', :old_type => 'Story')
    create_card!(:name => 'Blah', :feature => 'Profile builder', :size => '5', :old_type => 'Story')
    expected_chart_column_data = ['data', 100, 0, 40, 0]

    page = @project.pages.create!(:name => 'Dashboard',
                                  :content => %{
        {{
          ratio-bar-chart:
            totals: SELECT Feature, SUM(Size) WHERE old_type = Story
            restrict-ratio-with: Status = Closed
        }}
        {{
          ratio-bar-chart:
            totals: SELECT Feature, SUM(Size) WHERE old_type = Story
            restrict-ratio-with: Status = Closed
        }}
    })

    get :chart_data, :pagename => 'Dashboard', :project_id => @project.identifier, :type => 'ratio-bar', :position => 1
    assert_response :success
    assert_equal expected_chart_column_data, JSON.parse(@response.body)['data']['columns'][0]

    get :chart_data, :pagename => 'Dashboard', :project_id => @project.identifier, :type => 'ratio-bar', :position => 2
    assert_response :success
    assert_equal expected_chart_column_data, JSON.parse(@response.body)['data']['columns'][0]

    get :chart_data, :pagename => 'Dashboard', :project_id => @project.identifier, :type => 'ratio-bar', :position => 3
    assert_equal '', @response.body
  end

  def test_can_render_chart_data_for_version
    setup_property_definitions :feature => ['Dashboard', 'Applications', 'Rate calculator', 'Profile builder'],
                               :size => [1,2,3,4,5], :status => ['Closed'], :old_type => ['Story']
    create_card!(:name => 'Blah', :feature => 'Dashboard', :size => '1', :status => 'Closed', :old_type => 'Story')
    create_card!(:name => 'Blah', :feature => 'Applications', :size => '1', :old_type => 'Story')
    create_card!(:name => 'Blah', :feature => 'Applications', :size => '2', :old_type => 'Story')
    create_card!(:name => 'Blah', :feature => 'Rate calculator', :size => '3', :old_type => 'Story')
    create_card!(:name => 'Blah', :feature => 'Rate calculator', :size => '2', :status => 'Closed', :old_type => 'Story')
    create_card!(:name => 'Blah', :feature => 'Profile builder', :size => '5', :old_type => 'Story')
    expected_chart_column_data = ['data', 100, 0, 40, 0]

    page = @project.pages.create!(:name => 'Dashboard',
                                  :content => '
        {{
          ratio-bar-chart:
            totals: SELECT Feature, SUM(Size) WHERE old_type = Story
            restrict-ratio-with: Status = Closed
        }}
    ')
    page.update_attributes(content: 'blank chart')

    get :chart_data, :pagename => 'Dashboard', :project_id => @project.identifier, :type => 'ratio-bar', :position => 1, :version => 1
    assert_response :success
    assert_false @response.body.blank?
    assert_equal expected_chart_column_data, JSON.parse(@response.body)['data']['columns'][0]
  end

  def test_chart_data_is_cached
    setup_property_definitions :feature => ['Dashboard', 'Applications', 'Rate calculator', 'Profile builder'],
      :size => [1,2,3,4,5], :status => ['Closed'], :old_type => ['Story']
    create_card!(:name => 'Blah', :feature => 'Dashboard', :size => '1', :status => 'Closed', :old_type => 'Story')
    create_card!(:name => 'Blah', :feature => 'Applications', :size => '1', :old_type => 'Story')
    create_card!(:name => 'Blah', :feature => 'Applications', :size => '2', :old_type => 'Story')
    create_card!(:name => 'Blah', :feature => 'Rate calculator', :size => '3', :old_type => 'Story')
    create_card!(:name => 'Blah', :feature => 'Rate calculator', :size => '2', :status => 'Closed', :old_type => 'Story')
    create_card!(:name => 'Blah', :feature => 'Profile builder', :size => '5', :old_type => 'Story')
    expected_chart_column_data = ['data', 100, 0, 40, 0]

    with_renderable_caching_enabled do
      page_content = %{
        {{
          ratio-bar-chart:
            totals: SELECT Feature, SUM(Size) WHERE old_type = Story
            restrict-ratio-with: Status = Closed
        }}
        {{
          ratio-bar-chart:
            totals: SELECT Feature, SUM(Size) WHERE old_type = Story
            restrict-ratio-with: Status = Closed
        }}
      }
      page = @project.pages.create!(:name => 'Great Page', :content => page_content)

      get :chart_data, :pagename => 'Great Page', :project_id => @project.identifier, :type => 'ratio-bar', :position => 1
      get :chart_data, :pagename => 'Great Page', :project_id => @project.identifier, :type => 'ratio-bar', :position => 2

      assert_equal expected_chart_column_data, JSON.parse(Caches::ChartCache.get(page, 'ratio-bar', 1))['data']['columns'][0]
      assert_equal expected_chart_column_data, JSON.parse(Caches::ChartCache.get(page, 'ratio-bar', 2))['data']['columns'][0]
    end
  end

  def test_cached_charts_should_be_retrieved_from_cache_instead_of_generated
    with_renderable_caching_enabled do
      page = @project.pages.create!(:name => 'Great Page', :content => 'some page content')

      chart_type = 'dummy'
      macro_position = 1
      Caches::ChartCache.add(page, chart_type, macro_position, 'this would normally be an image')

      get :chart, :pagename => 'Great Page', :project_id => @project.identifier, :type => chart_type, :position => macro_position
      assert_equal "this would normally be an image", @response.body
    end
  end

  def test_cached_charts_should_not_be_retrieved_from_cache_when_previewed
    with_renderable_caching_enabled do
      page_content = %{
           {{
             pie-chart:
               data: SELECT Status, COUNT(*)
           }}
        }
      page = @project.pages.create!(:name => 'Great Page', :content => page_content)
      index = 1
      chart_type = 'pie'
      @request.session[:renderable_preview_content] = page_content
      Caches::ChartCache.add(page, chart_type, index, 'this would normally be an image')

      get :chart, :pagename => page.name, :project_id => @project.identifier, :type => chart_type, :position => index, :preview => true

      assert_not_equal "this would normally be an image", @response.body
    end
  end

  def test_charts_are_not_cached_when_cross_project_macros_are_being_used
    with_renderable_caching_enabled do
      page_content = %{
        {{
          pie-chart:
            data: SELECT Status, COUNT(*)
            project: #{first_project.identifier}
        }} }
      page = @project.pages.create!(:name => 'Great Page', :content => page_content)

      get :chart_data, :pagename => 'Great Page', :project_id => @project.identifier, :type => 'pie-chart', :position => 1

      assert_nil Caches::ChartCache.get(page, 'pie-chart', 1)
    end
  end

  def test_should_be_able_delete_attachment_in_view_mode
    page = @project.pages.create!(:name => 'test page')
    page.attach_files(sample_attachment, sample_attachment('sample_attachment.gif'))
    page.save!
    xhr :delete, :remove_attachment, :project_id => @project.identifier, :id => page.id, :file_name => 'sample_attachment.txt', :format => "json"
    assert_response :success
    assert_equal({"file" => "sample_attachment.txt"}, JSON.parse(@response.body))
  end

  def test_should_update_content_section_if_content_used_recently_deleted_attachment
    page = @project.pages.create!(:name => 'test page 1', :content => 'sample_attachment.gif')
    page.attach_files(sample_attachment, sample_attachment('sample_attachment.gif'))
    page.save!
    xhr :delete, :remove_attachment, :project_id => @project.identifier, :id => page.id, :file_name => 'sample_attachment.gif', :format => "json"
    assert_response :success
    assert_equal({"file" => "sample_attachment.gif"}, JSON.parse(@response.body))
  end

  def test_should_allow_deletion_of_multiple_attachments_in_edit_mode
    page = @project.pages.create!(:name => 'test page')
    page.attach_files(sample_attachment, sample_attachment('sample_attachment.gif'))
    page.save!
    attachments_ids = page.attachments.collect(&:id)
    post :update, :project_id => @project.identifier, :page_identifier => 'test_page', :page => {:content => ''}, :deleted_attachments => { 'sample_attachment.txt' => 'true', 'sample_attachment.gif' => 'true' }
    follow_redirect
    assert page.reload.attachments.empty?
    attachments_ids.each do |attachment_id|
      assert_no_tag :a, :attributes => {:id => "attachment_#{attachment_id}" }
    end
  end

  def test_should_add_to_page_view_history_when_showing_the_page
    page = @project.pages.create!(:name => 'test page 1', :content => 'test page 1 content')
    get :show, :project_id => @project.identifier, :pagename => 'test page 1'
    assert_equal({@project.id.to_s => [page.identifier]}, session[ApplicationController::SESSION_RECENTLY_ACCESSED_PAGES])
  end

  # bug #9787
  def test_should_include_help_link_for_read_only_member
    user = User.find_by_email('member@email.com')
    @project.add_member(user, :readonly_member)

    page = @project.pages.create!(:name => 'test page 1', :content => 'test page 1 content')
    get :show, :project_id => @project.identifier, :pagename => 'test page 1'

    assert_select "#current-user a", :text => /member@email.com/
    assert_select "#main a", :text => /Help/, :count => 1
  end

  def test_cannot_subscribe_to_page_via_email_without_an_email_address
    member = User.find_by_login('member')
    member.update_attribute('email', nil)
    page = @project.pages.create!(:name => 'first page')
    get :show, :pagename => 'first page', :project_id => @project.identifier
    assert_select 'p.email-disabled'
  end

  def test_can_subscribe_to_card_with_email_address_and_no_existing_subscription
    page = @project.pages.create!(:name => 'first page')
    get :show, :pagename => 'first page', :project_id => @project.identifier
    assert_select 'div#subscribe-via-email'
  end

  def test_cannot_subscribe_to_card_with_existing_subscription
    page = @project.pages.create!(:name => 'first page')
    history_params = HistoryFilterParams.new(:page_identifier => page.identifier).serialize
    @project.create_history_subscription(User.current, history_params)
    get :show, :pagename => 'first page', :project_id => @project.identifier
    assert_select 'div#subscribed-message'
  end

  def test_show_version_does_not_show_tags_from_current_version
    page = @project.pages.create!(:name => 'Somepage')
    page.reload.content = 'new content'
    page.save!
    page.reload.tag_with('rss')
    page.save!
    assert_equal 3, page.reload.versions.size

    get :show, :project_id => @project.identifier, :version => '1', :pagename => 'Somepage'
    assert_select 'div.tag-list', :count => 0, :text => 'rss'
  end

  def test_should_be_able_to_set_wiki_page_as_a_favorite
    page = @project.pages.create!(:name => 'test page')
    xhr :post, :update_favorite_and_tab_status, :project_id => @project.identifier, :page_identifier => page.identifier, :status => {:favorite => 'true'}
    assert @project.favorites.of_pages.find_by_favorited_id(page.id)
  end

  def test_should_be_able_to_demote_tabbed_wiki_page_to_team_favorite
    favorite = create_page_favorite(@project.pages.create!(:name => 'tabbed'), :tab => true)
    @proj_admin = User.find_by_login('proj_admin')
    @project.add_member(@proj_admin, :project_admin)
    login_as_proj_admin
    xhr :post, :update_favorite_and_tab_status, :project_id => @project.identifier, :page_identifier =>favorite.favorited.identifier, :status => {:favorite => 'true'}
    assert_equal false, favorite.reload.tab_view?
    assert_not_nil @project.favorites.of_team.find_by_favorited_id(favorite.favorited.id)
  end

  def test_should_be_able_to_set_wiki_page_as_a_tab_view
    login_as_admin
    page = @project.pages.create!(:name => 'test page')
    xhr :post, :update_favorite_and_tab_status, :project_id => @project.identifier, :page_identifier => page.identifier, :status => {:tab => 'true'}
    assert @project.tabs.of_pages.find_by_favorited_id(page.id)
  end

  def test_should_set_persisted_tabs_position_when_setting_wiki_as_tab_when_tab_reordering_enabled
    login_as_admin
    page1 = @project.pages.create!(:name => 'test page 1')
    xhr :post, :update_favorite_and_tab_status, :project_id => @project.identifier, :page_identifier => page1.identifier, :status => {:tab => 'true'}

    fake_controller =     OpenStruct.new(:current_tab => {
      :name => 'All',
      :type => 'All'
    },
    :card_context => CardContext.new(@project, {}),
    :session => {})

    display_tabs = DisplayTabs.new(@project, fake_controller)

    assert_include 'test page 1', display_tabs.to_a.map(&:name)
  end

  def test_should_be_able_remove_favorite
    page = @project.pages.create!(:name => 'test page')
    create_page_favorite(page, true)
    xhr :post, :update_favorite_and_tab_status, :project_id => @project.identifier, :page_identifier => page.identifier
    assert_nil @project.favorites_and_tabs.of_pages.find_by_favorited_id(page.id)
  end

  def test_tab_highlighting_on_favourite_and_tab_creation
    page = @project.pages.create!(:name => 'likey')
    xhr :post, :update_favorite_and_tab_status, :project_id => @project.identifier, :page_identifier => page.identifier, :status => {:favorite => 'true'}
    assert_equal 'Overview', @controller.current_tab[:name]

    xhr :post, :update_favorite_and_tab_status, :project_id => @project.identifier, :page_identifier => page.identifier, :status => {:tab => 'true'}
    assert_equal 'likey', @controller.current_tab[:name]
  end

  def test_only_admins_should_be_able_to_make_page_a_tab
    page = @project.pages.create!(:name => 'mike')

    login_as_member
    get :show, :project_id => @project.identifier, :pagename => page.name
    make_top_tab_identifier = 'a#top_tab_link'
    make_bottom_tab_identifier = 'a#bottom_tab_link'
    assert_select(make_top_tab_identifier, false, 'Only admins should be able to make pages tabs')
    assert_select(make_bottom_tab_identifier, false, 'Only admins should be able to make pages tabs')

    login_as_admin
    get :show, :project_id => @project.identifier, :pagename => page.name
    assert_select(make_top_tab_identifier, true, 'Admins should be able to make pages tabs')
    assert_select(make_bottom_tab_identifier, true, 'Admins should be able to make pages tabs')
  end

  def test_members_cannot_make_a_tabbed_page_into_a_favorite_using_the_ui
    page = @project.pages.create!(:name => 'mike')
    create_page_favorite(page, true)

    login_as_member
    get :show, :project_id => @project.identifier, :pagename => page.name
    assert_select 'input[name*="favorite"][disabled]', true, 'Favorite checkbox should be disabled'

    login_as_admin
    get :show, :project_id => @project.identifier, :pagename => page.name
    assert_select('input[name*="favorite"]:not([disabled])', true, 'Favorite checkbox should not be disabled')
  end

  def test_members_cannot_make_a_tabbed_page_into_a_favorite
    page = @project.pages.create!(:name => 'mike')
    favorite = create_page_favorite(page, true)

    login_as_member
    xhr :post, :update_favorite_and_tab_status, :project_id => @project.identifier, :page_identifier => page.identifier, :status => {:favorite => 'true'}

    assert favorite.reload.tab_view?
    assert !favorite.favorite?
  end

  def test_that_tab_replacement_includes_the_page_that_was_just_made_into_a_tab
    login_as_admin
    page = @project.pages.create!(:name => 'jay')

    xhr :post, :update_favorite_and_tab_status, :project_id => @project.identifier, :page_identifier => page.identifier, :status => {:tab => 'true'}
    assert @response.body =~ /tab_jay_link/
  end

  def test_should_be_able_to_add_a_new_tab_page_when_there_is_a_wiki_page_as_a_tab
    login_as_admin
    page = @project.pages.create!(:name => 'mike')
    xhr :post, :update_favorite_and_tab_status, :project_id => @project.identifier, :page_identifier => page.identifier, :status => {:tab => 'true'}
    get :show, :project_id => @project.identifier, :pagename => 'timmy'  # this should not throw an exception
  end

  def test_should_not_show_make_current_view_favorite_sidebar
    @project.favorites_and_tabs.destroy_all
    page = @project.pages.create!(:name => 'rock and roll')
    xhr :post, :update_favorite_and_tab_status, :project_id => @project.identifier, :page_identifier => page.identifier, :status => {:tab => 'true'}
    assert_text_not_present 'Add current view to team favorites'
  end

  def test_make_favorite_should_update_favorites_sidebar
    @project.favorites_and_tabs.destroy_all
    page = @project.pages.create!(:name => 'rock and roll')
    get :show, :project_id => @project.identifier, :pagename => 'rock and roll'
    assert_select 'a', {:text => 'Team favorites', :count => 0}
    xhr :post, :update_favorite_and_tab_status, :project_id => @project.identifier, :page_identifier => page.identifier, :status => {:favorite => 'true'}
    assert_rjs 'replace', 'favorites-container', /#{json_escape("<a.*>Team favorites<\/a>")}/
    xhr :post, :update_favorite_and_tab_status, :project_id => @project.identifier, :page_identifier => page.identifier
    assert_select "div#favorites-container", :count => 1
  end

  def test_make_tab_should_not_update_favorites_sidebar
    @project.favorites_and_tabs.destroy_all
    page = @project.pages.create!(:name => 'rock and roll')
    get :show, :project_id => @project.identifier, :pagename => 'rock and roll'
    assert_select 'a', {:text => 'Team favorites', :count => 0}
    xhr :post, :update_favorite_and_tab_status, :project_id => @project.identifier, :page_identifier => page.identifier, :status => {:tab => 'true'}
    assert_text_not_present "Team favorites"
    xhr :post, :update_favorite_and_tab_status, :project_id => @project.identifier, :page_identifier => page.identifier
    assert_text_not_present "Team favorites"
  end

  def test_get_list_of_pages
    get :index, :project_id => @project.identifier
    assert_response :success
    assert_equal assigns['pages'].size, @project.pages.size
  end

  # bug 3981
  def test_chart_route_for_page_name_with_dot_get_recongized
    assert_recognizes({:action => 'chart',
                       :project_id => 'mingle',
                       :controller => 'pages',
                       :pagename => 'Release_2.1_Pre_Analysis',
                       :type => 'pie-chart',
                       :position => '2'
    }, "projects/mingle/wiki/Release_2.1_Pre_Analysis/chart/2/pie-chart.png")
  end

  def test_should_redirect_to_overview_page_when_readonly_member_is_trying_to_access_a_page_does_not_exist
    @bob = User.find_by_login('bob')
    @project.add_member(@bob, :readonly_member)
    login_as_bob
    @request.env["HTTP_REFERER"] = 'overview'
    get :show, :project_id => @project.identifier, :pagename => 'doesnt_exist'
    assert_response :redirect
    assert_equal 'Read only team members do not have access rights to create pages.', flash[:error]
  end

  def test_should_redirect_to_project_url_when_accessing_overview_page_url
    overview_page = @project.pages.create(:identifier => Project::OVERVIEW_PAGE_IDENTIFIER)
    get :show, :project_id => @project.identifier, :pagename => overview_page.name
    assert_response :redirect
    assert_redirected_to project_overview_url(:project_id => @project.identifier)
  end

  def test_should_allow_dot_appear_in_page_name
    get :show, :project_id => @project.identifier, :pagename => ''
  end

  def test_should_allow_project_admin_to_delete_wiki_page
    @proj_admin = User.find_by_login('proj_admin')
    @project.add_member(@proj_admin, :project_admin)
    login_as_proj_admin
    @project.pages.create!(:name => 'coffee')
    post :destroy, :project_id => @project.identifier, :page_identifier => 'coffee'
    assert_redirected_to :action => 'show'
    assert_equal 0, @project.pages.reload.size
  end

  # bug 5587
  def test_should_not_allow_non_project_admin_to_delete_wiki_page
    @member = User.find_by_login('member')
    @project.add_member(@member)
    login_as_member
    @project.pages.create!(:name => 'coffee')

    assert_raise ApplicationController::UserAccessAuthorizationError do
      post :destroy, :project_id => @project.identifier, :page_identifier => 'coffee'
    end
  end

  #bug 5472
  def test_should_escape_page_name
    @project.pages.create(:name => "new <sub> wiki <h3> page")
    get :show, :project_id => @project.identifier, :pagename => 'new <sub> wiki <h3> page'
    assert_match(/new &lt;sub&gt; wiki &lt;h3&gt; page/, @response.body)
  end

  def test_edit_should_show_latest_content_with_message_that_latest_is_shown
    page = @project.pages.create!(:name => 'jay coffee')
    page.content = 'jay says just water and bang'
    page.save!
    get :edit, :project_id => @project.identifier, :page_identifier => page.identifier, :coming_from_version => page.version - 1
    assert_response :success
    assert_info /This page has changed since you opened it for viewing. The latest version was opened for editing. You can continue to edit this content, .*go back.* to the previous page or view the .*latest version.*./
  end

  def test_edit_should_not_show_message_that_latest_is_shown_if_already_coming_from_latest
    page = @project.pages.create!(:name => 'phoenix coffee')
    page.content = 'just tea'
    page.save!
    get :edit, :project_id => @project.identifier, :page_identifier => page.identifier, :coming_from_version => page.version
    assert_response :success
    assert_nil flash[:info]
  end

  def test_edit_should_not_show_message_that_latest_is_shown_if_coming_from_version_is_not_specified
    page = @project.pages.create!(:name => 'timmy coffee')
    page.content = 'just milk'
    page.save!
    get :edit, :project_id => @project.identifier, :page_identifier => page.identifier
    assert_response :success
    assert_nil flash[:info]
  end

  def test_edit_should_include_version_information
    page = @project.pages.create!(:name => 'happy Jay')
    get :edit, :project_id => @project.identifier, :page_identifier => page.identifier
    assert_response :success
    assert_select 'p#version-info', :count => 1
  end

  def test_edit_existing_page_with_redcloth_markup_will_edit_as_html
    page = @project.pages.create!(:name => 'old', :content => 'h1. I am a header')
    page.redcloth = true
    page.save
    assert page.redcloth
    get :edit, :project_id => @project.identifier, :page_identifier => page.identifier
    assert_equal "<h1>I am a header</h1>", ckeditor_data
  end

  def test_edit_nonredcloth_page_will_remain_unchanged
    content = '<h1>I am a header</h1> h1. something'
    page = @project.pages.create!(:name => 'WYSIWYGmania', :content => content)
    get :edit, :project_id => @project.identifier, :page_identifier => page.identifier
    assert_equal content, ckeditor_data
  end

  def test_edit_an_page_no_longer_found_redirects_to_new
    get :edit, :project_id => @project.identifier, :page_identifier => 'does_not_exist'
    assert_response :success
    assert_template 'new'
  end

  def test_show_should_provide_warning_when_more_than_10_macros
    with_first_project do |project|
      page = project.pages.create!(:name => 'iwefuh', :redcloth => true)
      page.update_attribute(:content, "sdfvsdf #{"{{ dummy }}" * 11} blabla")
      get :show, :project_id => project.identifier, :page_identifier => page.identifier
      assert_select "#too_many_macros_warning"
    end
  end

  def test_should_disable_macro_warnings_for_desired_page
    with_first_project do |project|
      post :hide_too_many_macros_warning, :project_id => project.identifier, :page => "/foo/bar"
      assert_equal ["/foo/bar"], @controller.session[:too_many_macros_warning_visible]
    end
  end

  def test_should_not_show_warning_when_user_turn_off_too_many_macros_warning
    with_first_project do |project|
      page = project.pages.first
      page.update_attribute(:content, "sdfvsdf #{"{{ dummy }}" * 11} blabla")
      @request.session[:too_many_macros_warning_visible] = ["/projects/#{project.identifier}/wiki/#{page.identifier}/show"]
      get :show, :project_id => project.identifier, :page_identifier => page.identifier
      assert_select "#too_many_macros_warning", :count => 0
    end
  end

  #bug 8443 get rid of the backgroud of "action bar" on wiki page for anon/readonly user
  def test_show_should_not_render_action_bar_spinner_when_log_in_as_readonly
    with_first_project do |project|
      member = User.find_by_login('member')
      project.add_member(member, :readonly_member)
      page = project.pages.first
      login_as_member
      get :show, :project_id => project.identifier, :page_identifier => page.identifier
      assert_select '#bottom_spinner', :count => 0
    end
  end

  #bug 8443 get rid of the backgroud of "action bar" on wiki page for anon/readonly user
  def test_show_should_not_render_action_bar_spinner_when_log_in_as_anonymous_user
    with_new_project(:anonymous_accessible => true) do |project|
      set_anonymous_access_for(project, true)
      page = project.pages.create!(:name => 'happy new year')
      logout_as_nil
      change_license_to_allow_anonymous_access
      get :show, :project_id => project.identifier, :page_identifier => page.identifier
      assert_select '#bottom_spinner', :count => 0
    end
  ensure
    reset_license
  end

  def test_deleting_already_deleted_page_gives_appropriate_error
    login_as_admin
    post :destroy, :project_id => @project.identifier, :identifier => rand
    assert_redirected_to
    assert_redirected_to project_show_url(:project_id => @project.identifier)
    assert_equal "The page you attempted to delete no longer exists.", flash[:error]
  end

  def test_should_add_new_card_in_footbar
    login_as_admin
    @project.pages.create(:name => 'first page')
    get :show, :project_id => @project.identifier, :pagename => @project.pages.first.name
    assert_select 'a#add_card_with_defaults', :text => 'Add Card'
  end

  def test_show_history_events
    page = @project.pages.create!(:name => 'wiki page', :content => "wiki !content! ?")
    page.update_attribute('content', "updated wiki content 2")
    page.update_attribute('content', "updated wiki content 3")
    page.update_attribute('content', "updated wiki content 4")

    get :history, :project_id => @project.identifier, :pagename => 'wiki page'
    assert_response :success
    assert_select '.page-event', :count => 4
  end

  def test_show_history_should_response_404_when_page_can_not_be_found
    assert_raises(ActiveRecord::RecordNotFound) do
      get :history, :project_id => @project.identifier, :pagename => 'not exists page'
    end
  end

  private

  def default_options
    {
      "commit" => "Publish",
      "tags" => { "0" => "" },
      :project_id => @project.identifier,
      "page" => {
        "name" => "very new wiki page",
        "content" => "random [[wiki]] content"
      }
    }
  end

  def perform_with_default_options(action, attachments = [], page_identifier = nil)
    options = default_options
    options.merge!("pending_attachments" => attachments) unless attachments.empty?
    options.merge!("page_identifier" => page_identifier ) if page_identifier
    post(action, options)
    @project.pages.find_by_identifier('very_new_wiki_page')
  end

  def assert_text_not_present(text)
    assert_no_match Regexp.new(Regexp.escape(text)), @response.body, "Response included:\n #{text.to_s}"
  end

  def assert_attachments(size, attachments)
    assert_equal size, attachments.size
    for attachment in attachments
      assert File.exist?(File.join(attachment.file_dir, attachment.file_name))
    end
  end

  def create_page_favorite(page, tabbed = false)
    if tabbed
      @project.tabs.of_pages.create!(:favorited => page)
    else
      @project.favorites.of_pages.create!(:favorited => page)
    end
  end
end
