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
require File.expand_path(File.dirname(__FILE__) + '/../unit/renderable_test_helper')

class RenderingControllerTest < ActionController::TestCase
  include ::RenderableTestHelper

  def setup
    @controller = create_controller(RenderingController)
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    login_as_member
    @project = first_project
    @project.activate
  end

  def test_should_be_able_to_render_macro_to_html
    post :render_content, :api_version => 'v2', :format => 'xml', :project_id => @project.identifier, :content => <<-MACRO
    {{ project }}
    MACRO
    assert_response :success
    assert_equal_ignoring_spaces @project.identifier, @response.body.strip
  end

  def test_should_be_able_to_render_redcloth_card_with_given_content
    first_card = @project.cards.first
    first_card.update_attributes(:description => 'h3. hello', :redcloth => true)
    get :render_content, :api_version => 'v2', :format => 'xml', :content_provider => { :type => 'card', :id => first_card.id }, :project_id => @project.identifier
    assert_response :success
    assert_equal '<h3>hello</h3>', @response.body.strip
    assert first_card.reload.redcloth
  end

  def test_should_be_able_to_render_card_with_given_content
    first_card = @project.cards.first
    first_card.update_attributes(:description => '<h3>hello</h3>')
    get :render_content, :api_version => 'v2', :format => 'xml', :content_provider => { :type => 'card', :id => first_card.id }, :project_id => @project.identifier
    assert_response :success
    assert_equal '<h3>hello</h3>', @response.body.strip
  end

  def test_should_be_able_to_render_card_version_content
    first_card = @project.cards.first
    first_card.update_attributes(:description => '<h3>hello</h3>')
    first_card.update_attributes(:description => '<h3>goodbye</h3>')
    get :render_content, :api_version => 'v2', :format => 'xml', :content_provider => { :type => 'card::version', :id => first_card.versions[-2].id }, :project_id => @project.identifier
    assert_response :success
    assert_equal '<h3>hello</h3>', @response.body.strip
  end

  #bug #13449 - render api does not render given content
  def test_render_card_with_given_content_should_not_hit_cache
    Renderable.enable_caching
    first_card = @project.cards.first
    first_card.update_attributes(:description => 'h3. hello')
    get :render_content, :api_version => 'v2', :format => 'xml', :content_provider => { :type => 'card', :id => first_card.id }, :project_id => @project.identifier

    get :render_content, :api_version => 'v2', :format => 'xml', :content_provider => { :type => 'card', :id => first_card.id }, :project_id => @project.identifier, :content => <<-MACRO
    {{ project }}
    MACRO
    assert_response :success
    assert_equal_ignoring_spaces @project.identifier, @response.body.strip
  ensure
    Renderable.disable_caching
  end

  def test_should_be_able_to_render_page_content
    page = @project.pages.first
    expected = "<h3>hello</h3>"
    page.update_attributes(:content => expected)
    assert_false page.redcloth
    get :render_content, :api_version => 'v2', :format => 'xml', :content_provider => { :type => 'page', :id => page.id }, :project_id => @project.identifier
    assert_response :success
    assert_equal expected, @response.body.strip
  end

  def test_should_be_able_to_render_page_version_content
    content_1 = "<h3>hello</h3>"
    content_2 = "<h3>goodbye</h3>"

    page = @project.pages.first
    assert_false page.redcloth

    page.update_attributes(:content => content_1)
    page.update_attributes(:content => content_2)
    get :render_content, :api_version => 'v2', :format => 'xml', :content_provider => { :type => 'page::version', :id => page.versions[-2].id }, :project_id => @project.identifier
    assert_response :success
    assert_equal content_1, @response.body.strip
  end

  def test_should_return_404_if_provider_type_is_not_recognized
    get :render_content, :api_version => 'v2', :format => 'xml', :content_provider => { :type => 'project', :id => @project.id }, :project_id => @project.identifier
    assert_response :not_found
  end

  def test_should_return_404_if_card_identifier_is_not_a_number
    get :render_content, :api_version => 'v2', :format => 'xml', :content_provider => { :type => 'card', :id => 'first card' }, :project_id => @project.identifier
    assert_response :not_found
  end

  def test_should_be_able_to_specified_the_raw_content_even_content_provider_is_found
    first_card = @project.cards.first
    first_card.update_attributes(:description => 'h3. hello')
    get :render_content, :api_version => 'v2', :format => 'xml', :content_provider => { :type => 'card', :id => first_card.id }, :project_id => @project.identifier, :content => <<-MACRO
    {{ project }}
    MACRO
    assert_response :success
    assert_equal_ignoring_spaces @project.identifier, @response.body.strip
  end

  def test_chart_should_render_content_stored_in_the_session
      session[:renderable_chart_content] = <<-MACRO
      {{
          pie-chart
            data: SELECT Iteration, Count(*)
      }}
      MACRO

      get :chart, :project_id => @project.identifier, :position => 1, :type => 'pie-chart'
      assert_response :success
  end

  def test_can_render_macro_with_caching_enabled
    Renderable.enable_caching
    post :render_content, :api_version => 'v2', :format => 'xml', :project_id => @project.identifier, :content => <<-MACRO
    {{ project }}
    MACRO
    assert_response :success
    assert_equal_ignoring_spaces @project.identifier, @response.body.strip

  ensure
    Renderable.disable_caching
  end

  def test_should_urls_in_result_should_be_full_url
    # this test started failing when we upgraded c-ruby on precommit. FullSanitizer#sanitize compares html
    # as a string to determine when it has sanitized nested tags. The reason this test fails is that it
    # goes into infinite recursion when the two strings this method compares differ in attribute order. I didn't
    # want to patch the sanitizer so instead just run this test in jruby.
    MingleConfiguration.with_site_u_r_l_overridden_to('https://test.host/') do
      requires_jruby do
        post :render_content, :api_version => 'v2', :format => 'xml', :project_id => @project.identifier, :content => "#1"
        assert_response :success
        assert_include "href=\"https://test.host/projects/#{@project.identifier}/cards/1\"", @response.body.strip
      end
    end
  end

  def test_should_strip_out_all_js_event_handler
    # this test started failing when we upgraded c-ruby on precommit. FullSanitizer#sanitize compares html
    # as a string to determine when it has sanitized nested tags. The reason this test fails is that it
    # goes into infinite recursion when the two strings this method compares differ in attribute order. I didn't
    # want to patch the sanitizer so instead just run this test in jruby.
    requires_jruby do
      post :render_content, :api_version => 'v2', :format => 'xml', :project_id => @project.identifier, :content => "#1"
      assert_response :success
      assert_not_include "onmouseover", @response.body.strip
    end
  end

  def test_should_be_able_to_render_this_card_macro
    first_card = @project.cards.first
    first_card.update_attributes(:description => "{{ value query: SELECT name where number = THIS CARD.number }}")
    get :render_content, :api_version => 'v2', :format => 'xml', :content_provider => { :type => 'card', :id => first_card.id }, :project_id => @project.identifier
    assert_response :success
    assert_equal_ignoring_spaces first_card.name, @response.body.strip
  end

  def test_link_in_table_query_should_be_html_format_full_url
    MingleConfiguration.with_site_u_r_l_overridden_to('https://test.host/') do
      card = create_card! :name => "theOne"
      post :render_content, :api_version => 'v2', :format => 'xml',  :project_id => @project.identifier, :content => <<-MACRO
        {{ table
            query: SELECT number, name WHERE number = #{card.number}
        }}
      MACRO
      assert_response :success
      assert_include "https://test.host/projects/first_project/cards/#{card.number}", @response.body
    end
  end

  def test_link_in_pivot_table_macro_should_be_html_format_full_url
    MingleConfiguration.with_site_u_r_l_overridden_to('https://test.host/') do
      with_pivot_table_macro_project do |project|
        create_card!(:name => 'No size')
        post :render_content, :api_version => 'v2', :format => 'xml', :project_id => project.identifier, :content => <<-MACRO
          {{ pivot-table
              columns: half
              rows: Status
              conditions: 'Status is null'
          }}
        MACRO

        assert_response :success
        assert_include "https://test.host/projects/#{project.identifier}/cards?columns=Status%2Chalf&amp;filters%5Bmql%5D=Status+IS+NULL+AND+half+%3D+%272.5%27&amp;style=list", @response.body
      end
    end
  end

  def test_render_attachment_link
    MingleConfiguration.with_site_u_r_l_overridden_to('https://test.host/') do
      with_new_project do |project|
        project.add_member(User.current)
        card = project.cards.create!(:name => "first card", :card_type_name => "card")
        card.attach_files(sample_attachment('IMG_1.JPG'))
        card.save!

        attachment = project.attachments.first
        post :render_content, :api_version => 'v2', :format => 'xml', :project_id => project.identifier, :content => <<-MACRO
          [[#1/IMG_1.jpg]]
        MACRO
        assert_response :success
        assert_include %Q{<a href="https://test.host/projects/#{project.identifier}/attachments/#{attachment.id}" target="blank">#1/IMG_1.jpg</a>}, @response.body
      end
    end
  end
end
