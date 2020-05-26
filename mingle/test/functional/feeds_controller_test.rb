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

# Tags: feeds
class FeedsControllerTest < ActionController::TestCase
  NOT_EMPTY = /.+/
  RFC3339_DATE_FORMAT = /[0-9\-]{8}T[0-9]{2}:[0-9]{2}:[0-9]{2}(\.[0-9]+)?(Z|[\+\-][0-9]{2}:[0-9]{2})/
  URI_FORMAT = /^((urn:uuid:.*)|(http|https):\/\/.*)/
  EMAIL_FORMAT = /\A([^@\s]+)@((?:[-a-z0-9]+\.)+[a-z]{2,})\Z/i

  def setup
    @old_page_size = PAGINATION_PER_PAGE_SIZE
    silence_warnings { Object.const_set('PAGINATION_PER_PAGE_SIZE', 3) }
    @controller = create_controller FeedsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    @member = login_as_member
    @original_site_url = MingleConfiguration.site_url
    MingleConfiguration.site_url = 'http://test.host'
  end

  def teardown
    silence_warnings { Object.const_set('PAGINATION_PER_PAGE_SIZE', @old_page_size) }
    MingleConfiguration.site_url = @original_site_url
  end

  def test_should_generate_valid_feed_structure
    with_first_project do |project|
      get_feed(project)
      assert_response :success
      assert_select 'body', :count => 0 # should not use layout

      assert_select 'feed', :count => 1 do
        assert_select "[xmlns=?]", "http://www.w3.org/2005/Atom"
        assert_select "[xmlns:mingle=?]", Mingle::API.ns
      end

      assert_select 'feed title', NOT_EMPTY

      assert_select 'feed link[rel=self]', :count => 1 do
        assert_select "[href=?]", URI_FORMAT
      end

      assert_select 'feed link[rel=current]', :count => 1 do
        assert_select "[href=?]", URI_FORMAT
      end

      assert_select 'feed updated', RFC3339_DATE_FORMAT
      assert_select 'feed id', URI_FORMAT, :count => 1

      assert_select 'feed entry' do |entries|
        entries.each do |entry|
          assert_select entry, 'title', NOT_EMPTY, :count => 1
          assert_select entry, "category[scheme=#{Mingle::API.ns('categories')}][term=?]", NOT_EMPTY
          assert_select entry, 'id', URI_FORMAT, :count => 1
          assert_select entry, 'author', :count => 1 do |author|
            assert_select author.first, 'name', NOT_EMPTY, :count => 1
            assert_select author.first, 'email', EMAIL_FORMAT, :count => 1
            assert_select author.first, 'uri', URI_FORMAT, :count => 1
          end
          assert_select entry, 'updated', RFC3339_DATE_FORMAT, :count => 1

          assert_select entry, 'content[type=application/vnd.mingle+xml]', NOT_EMPTY, :count => 1
        end
      end
      assert_content_uniq 'feed entry id'
    end
  end

  def test_should_be_served_with_correct_content_type
    with_first_project do |project|
      get_feed(project)
      assert_equal "application/atom+xml", @response.content_type
    end
  end

  def test_link_on_feed_level_should_pointing_to_itself_when_no_paging_happened
    with_first_project do |project|
      get_feed(project)

      assert_select 'feed link[rel=current][href=?]', "http://test.host/api/v2/projects/first_project/feeds/events.xml"
      assert_select 'feed link[rel=pre]', false
      assert_select 'feed link[rel=previous]', false
    end
  end

  def test_entry_link_to_card_event_source
    with_project_without_cards do |project|
      card = create_card!(:name => 'first card')
      get_feed(project)
      assert_select "feed entry link[rel=#{Mingle::API.ns('event-source')}][type=application/vnd.mingle+xml][title=Card #1][href=?]", "http://test.host/api/v2/projects/project_without_cards/cards/#{card.number}.xml"
      assert_select "feed entry link[rel=#{Mingle::API.ns('event-source')}][type=text/html][title=Card #1][href=?]", "http://test.host/projects/project_without_cards/cards/#{card.number}"
    end
  end

  def test_entry_link_to_page_event_source
    with_project_without_cards do |project|
      page = project.pages.create(:name => 'wiiiiki', :content => 'desc here')
      get_feed(project)
      assert_select "feed entry link[rel=#{Mingle::API.ns("event-source")}][type=application/vnd.mingle+xml][title=wiiiiki][href=?]", "http://test.host/api/v2/projects/project_without_cards/wiki/wiiiiki.xml"
      assert_select "feed entry link[rel=#{Mingle::API.ns("event-source")}][type=text/html][title=wiiiiki][href=?]", "http://test.host/projects/project_without_cards/wiki/wiiiiki"
    end
  end

  def test_entry_link_to_revision_event_source
    with_project_without_cards do |project|
      project.revisions.create!({:number => 1, :identifier => 'revision_id', :commit_message => 'fix a bug', :commit_time => Time.now.utc, :commit_user => 'member'})
      get_feed(project)
      assert_select "feed entry link[rel=#{Mingle::API.ns("event-source")}][type=text/html][title=Revision revision_id][href=?]", "http://test.host/projects/project_without_cards/revisions/revision_id"
      assert_select "feed entry link[rel=#{Mingle::API.ns("event-source")}][title=Revision revision_id][type=application/vnd.mingle+xml]", false
    end
  end

  def test_entry_link_to_related_cards
    with_project_without_cards do |project|
      card1 = create_card!(:name => 'card1')
      card2 = create_card!(:name => 'card2')

      project.revisions.create!({:number => 1, :identifier => 'revision_id', :commit_message => "finished card #{card1.number} and ##{card2.number}", :commit_time => Time.now.utc, :commit_user => 'member'})
      get_feed(project)
      assert_select "feed entry link[rel=#{Mingle::API.ns("related")}]", :count => 4
      assert_select "feed entry link[rel=#{Mingle::API.ns("related")}][type=application/vnd.mingle+xml][title=Card ##{card1.number}][href=?]",
        "http://test.host/api/v2/projects/project_without_cards/cards/#{card1.number}.xml"
      assert_select "feed entry link[rel=#{Mingle::API.ns("related")}][type=text/html][title=Card ##{card1.number}][href=?]",
        "http://test.host/projects/project_without_cards/cards/#{card1.number}"

      assert_select "feed entry link[rel=#{Mingle::API.ns("related")}][type=application/vnd.mingle+xml][title=Card ##{card2.number}][href=?]",
        "http://test.host/api/v2/projects/project_without_cards/cards/#{card2.number}.xml"
      assert_select "feed entry link[rel=#{Mingle::API.ns("related")}][type=text/html][title=Card ##{card2.number}][href=?]",
        "http://test.host/projects/project_without_cards/cards/#{card2.number}"
    end
  end

  def test_card_entry_version_link
    with_project_without_cards do |project|
      card = create_card!(:name => 'first card')
      card.cp_status = "closed"
      card.save!
      card.reload

      get_feed(project)
      assert_select "feed entry link[rel=#{Mingle::API.ns("version")}][type=application/vnd.mingle+xml][title=Card ##{card.number} (v2)][href=?]",
        "http://test.host/api/v2/projects/project_without_cards/cards/#{card.number}.xml?version=2"

      assert_select "feed entry link[rel=#{Mingle::API.ns("version")}][type=text/html][title=Card ##{card.number} (v2)][href=?]",
          "http://test.host/projects/project_without_cards/cards/#{card.number}?version=2"

      assert_select "feed entry link[rel=#{Mingle::API.ns("version")}][type=application/vnd.mingle+xml][title=Card ##{card.number} (v1)][href=?]",
        "http://test.host/api/v2/projects/project_without_cards/cards/#{card.number}.xml?version=1"

      assert_select "feed entry link[rel=#{Mingle::API.ns("version")}][type=text/html][title=Card ##{card.number} (v1)][href=?]",
          "http://test.host/projects/project_without_cards/cards/#{card.number}?version=1"
    end
  end

  def test_page_entry_version_link
    with_project_without_cards do |project|
      page = project.pages.create!(:name => 'first page')
      page.update_attribute(:content, 'haha')

      get_feed(project)
      assert_select "feed entry link[rel=#{Mingle::API.ns("version")}][title=first page (v2)][href=?]",
        "http://test.host/api/v2/projects/project_without_cards/wiki/#{page.identifier}.xml?version=2"

      assert_select "feed entry link[rel=#{Mingle::API.ns("version")}][title=first page (v1)][href=?]",
        "http://test.host/api/v2/projects/project_without_cards/wiki/#{page.identifier}.xml?version=1"
    end
  end

  def test_revision_entry_should_not_have_version_link
    with_project_without_cards do |project|
      project.revisions.create!({:number => 1, :identifier => 'revision_id', :commit_message => "finished", :commit_time => Time.now.utc, :commit_user => 'member'})
      get_feed(project)
      assert_select "feed entry link[rel=#{Mingle::API.ns("version")}]", :count => 0
    end
  end

  def test_feeds_for_empty_project
    with_project_without_cards do |project|
      get_feed(project)
      assert_response :ok
      assert_select "feed link[rel=previous]", :count => 0
      assert_select "feed link[rel=next]", :count => 0
      assert_select "feed link[rel=self]", :count => 1
      assert_select "feed entry", :count => 0
      assert_select "feed updated", :count => 1
    end
  end

  def test_links_for_most_recent_page
    with_project_without_cards do |project|
      7.times { create_card!(:name => 'a card') }
      get_feed(project)
      assert_response :ok
      assert_select "feed link[rel=self][href=?]", "http://test.host/api/v2/projects/project_without_cards/feeds/events.xml"
      assert_select "feed link[rel=next][href=?]", "http://test.host/api/v2/projects/project_without_cards/feeds/events.xml?page=2"
      assert_select "feed link[rel=previous]", :count => 0
      assert_select "feed link[rel=current][href=?]", "http://test.host/api/v2/projects/project_without_cards/feeds/events.xml"
    end
  end

  def test_links_for_page_in_the_middle
    with_project_without_cards do |project|
      7.times { create_card!(:name => 'a card') }
      get_feed(project, '2')
      assert_response :ok
      assert_select "feed link[rel=current][href=?]", "http://test.host/api/v2/projects/project_without_cards/feeds/events.xml"
      assert_select "feed link[rel=next][href=?]", "http://test.host/api/v2/projects/project_without_cards/feeds/events.xml?page=1"
      assert_select "feed link[rel=previous][href=?]", "http://test.host/api/v2/projects/project_without_cards/feeds/events.xml?page=3"
      assert_select "feed link[rel=self][href=?]", "http://test.host/api/v2/projects/project_without_cards/feeds/events.xml?page=2"
    end
  end

  def test_links_for_first_page
    with_project_without_cards do |project|
      7.times { create_card!(:name => 'a card') }
      get_feed(project, '1')
      assert_response :ok
      assert_select "feed link[rel=current][href=?]", "http://test.host/api/v2/projects/project_without_cards/feeds/events.xml"
      assert_select "feed link[rel=next]", :count => 0
      assert_select "feed link[rel=previous][href=?]", "http://test.host/api/v2/projects/project_without_cards/feeds/events.xml?page=2"
      assert_select "feed link[rel=self][href=?]", "http://test.host/api/v2/projects/project_without_cards/feeds/events.xml?page=1"
    end
  end

  def test_feeds_entry_title_and_links_for_deleted_card
    with_project_without_cards do |project|
      card = create_card!(:name => 'hello')
      card.destroy
      get_feed(project)
      assert_response :ok
      assert_select "feed entry:nth-last-child(1) title", :text => "Card ##{card.number} #{card.name} created"
      assert_select "feed entry:nth-last-child(1) link[rel=#{Mingle::API.ns("event-source")}][title=Card ##{card.number}][href=?]",
                  "http://test.host/api/v2/projects/project_without_cards/cards/#{card.number}.xml"
      assert_select "feed entry:nth-last-child(1) link[rel=#{Mingle::API.ns("version")}][title=Card ##{card.number} (v1)][href=?]",
            "http://test.host/api/v2/projects/project_without_cards/cards/#{card.number}.xml?version=1"


      assert_select "feed entry:nth-last-child(2) title", :text => "Card ##{card.number} #{card.name} deleted"
      assert_select "feed entry:nth-last-child(2) link[rel=#{Mingle::API.ns("event-source")}][title=Card ##{card.number}][href=?]",
                  "http://test.host/api/v2/projects/project_without_cards/cards/#{card.number}.xml"
      assert_select "feed entry:nth-last-child(2) link[rel=#{Mingle::API.ns("version")}][title=Card ##{card.number} (v2)][href=?]",
            "http://test.host/api/v2/projects/project_without_cards/cards/#{card.number}.xml?version=2"
    end
  end

  def test_correction_events_test
    with_project_without_cards do |project|
      project.card_types.first.update_attributes(:name => 'Story')
      project.card_types.first.update_attributes(:name => 'Bug')

      get_feed(project)
      assert_response :ok
      assert_select "feed entry:nth-last-child(1) title", :text => 'Card type changed'

      assert_select "feed entry:nth-last-child(2) title", :text => 'Card type changed'

      # should not have empty title
      assert_select "feed entry link[rel=#{Mingle::API.ns("event-source")}][title=]", false

    end
  end


  def test_entry_author_should_has_absolute_icon_url_if_user_has_icon
    with_first_project do |project|
      @member.update_attributes(:icon => sample_attachment("user_icon.png"))
      create_card!(:name => 'hello')
      get_feed(project)
      assert_response :success
      assert_include "<mingle:icon>http://test.host/user/icon/#{@member.id}/user_icon.png</mingle:icon>", @response.body
    end
  end

  def test_entry_author_for_revision_changes
    with_project_without_cards do |project|
      commit_time = Time.now.utc
      project.revisions.create!({:number => 1, :identifier => 'revision_id', :commit_message => 'fix a bug', :commit_time => commit_time, :commit_user => 'xxx'})
      get_feed(project)
      assert_response :ok
      assert_select "feed entry author name", :text => 'xxx'
      assert_select "feed entry author email", :count => 0
      assert_select "feed entry author uri", :count => 0
    end
  end


  def test_should_return_404_when_index
    with_first_project do |project|
      login_as_member
      get :index, :project_id => project.identifier
      assert_response 404
    end
  end

  def test_http_cache_scenario
    with_first_project do |project|
      get_feed(project)
      assert_response :ok
      etag = @response.headers['ETag']
      assert_not_nil etag

      @request.env['HTTP_IF_NONE_MATCH'] = etag
      get_feed(project)
      assert_response 304

      create_card!(:name => 'foo')

      @request.env['HTTP_IF_NONE_MATCH'] = etag
      get_feed(project)
      assert_response 304

      # run background job
      FeedsCache.new(Feeds.new(project), MingleConfiguration.site_url).write

      @request.env['HTTP_IF_NONE_MATCH'] = etag
      get_feed(project)
      assert_response 200
    end
  end

  def test_http_cache_for_different_page
    with_first_project do |project|
      get_feed(project)
      assert_response :ok
      @request.env['HTTP_IF_NONE_MATCH'] = @response.headers['ETag']
      get_feed(project, 1)
      assert_response 200
    end
  end

  private

  def get_feed(project, page=nil)
    get :events, :project_id => project.identifier, :api_version => 'v2', :format => 'xml', :page => page
  end

  def assert_content_uniq(selector)
    assert_select selector do |elements|
      assert_unique elements.collect { |element| element.children.first.content }
    end
  end

  def assert_unique(collection)
    assert_equal collection.size, collection.uniq.size, "#{collection.inspect} is not uniq"
  end
end
