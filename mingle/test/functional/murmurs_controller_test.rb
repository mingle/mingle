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
require File.expand_path(File.dirname(__FILE__) + '/../messaging/messaging_test_helper')

class MurmursControllerTest < ActionController::TestCase
  include ActionView::Helpers::AssetTagHelper, MessagingTestHelper
  SHOW_MORE_TEXT = '[&nbsp;Show more&nbsp;]&nbsp;'
  SHOW_LESS_TEXT = '[&nbsp;Show less&nbsp;]'

  def setup
    @controller = create_controller MurmursController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new

    @project = first_project
    @project.activate
    @member = login_as_member
  end

  def test_index_json_format
    message = create_murmur
    get :index, :project_id => @project.identifier, :format => 'json'
    assert_response :ok
    murmurs = JSON.parse(@response.body)
    assert_equal 1, murmurs.size
  end

  def test_create_json_format
    xhr :post, :create, :murmur => { :murmur => 'From Mingle' }, :project_id => @project.identifier, :format => 'json'
    assert_response :ok
    assert_equal({'conversation_id' => nil, 'murmur_ids' => nil}, JSON.parse(@response.body))
    assert_equal 1, @project.murmurs.size
  end

  def test_show_coming_as_ajax_request_should_show_full_murmur_with_expandability
    message = create_murmur(:murmur => 'a' * 2000)
    xhr :get, :show, :project_id => @project.identifier, :id => message.id, :page_source => :murmur
    assert_select "div.full-content", :text => Regexp.new(message.murmur)
    assert_select "div.truncated-content[style='display:none;']"
    assert_select "span.show-less", :text => SHOW_LESS_TEXT
  end

  def test_create_posting_a_new_murmur_through_the_page_creates_new_murmur_in_the_database
    xhr :post, :create, :murmur => { :murmur => 'From Mingle' }, :project_id => @project.identifier, :format => 'json'
    last_murmur = @project.murmurs.reload.last
    assert_equal 'From Mingle', last_murmur.murmur
    assert_equal @member, last_murmur.author
  end

  def test_at_user_suggestion_list_returns_all_groups_and_activate_users
    first = User.find_by_login('first')
    first.activated = false
    first.save!
    @project.groups.create!(:name => 'DEVs')

    get :at_user_suggestion, :project_id => @project.identifier, :format => :json
    assert_response :ok
    assert_equal(["@devs", "@team", "@member", "@proj_admin", "@bob"].sort, JSON.parse(@response.body).map {|d| d['value']}.sort)
  end

  def test_filter_and_sort
    users = []
    users << User.new(:login => "Deactivated", :name => "deactivated", :activated => false)
    100.times {|i|
      users << User.new(:login => "#{i}", :name => "z#{i}", :activated => true)
    }
    users << User.new(:login => "Put me first", :name => :a, :activated => true)
    filtered = @controller.filter_and_sort(users)
    assert_equal 101, filtered.size
    assert_equal :a, filtered.first.name
    assert_equal 0, filtered.select{ |user| user.name == "deactivated" }.size
  end

  def test_murmur_with_inline_link
    message = create_murmur(:murmur => "commit [#rev-asdf23f](http://mingle.thoughtworks.com) (repo name)")
    get :index, :project_id => @project.identifier, :format => 'json'
    murmurs = JSON.parse(@response.body)
    assert_equal 1, murmurs.size
    assert_include "commit <a href=\"http://mingle.thoughtworks.com\">#rev-asdf23f</a> (repo name)", murmurs.first
  end

  def test_murmur_line_break
    message = create_murmur(:murmur => "a\n\nb\nc")
    get :index, :project_id => @project.identifier, :format => 'json'
    murmurs = JSON.parse(@response.body)
    assert_equal 1, murmurs.size
    assert_include "a<br/><br/>b<br/>c", murmurs.first
  end

  def test_creates_a_conversation_when_replying_to_a_murmur
    parent = create_murmur(:murmur => "Hello")
    assert_nil parent.conversation
    xhr :post, :create, :murmur => { :murmur => 'Hey there', :replying_to_murmur_id => parent.id.to_s }, :project_id => @project.identifier, :format => 'json'
    assert_response :ok
    assert_equal({'conversation_id' => parent.reload.conversation_id,
                   'murmur_ids' => parent.conversation.murmur_ids}, JSON.parse(@response.body))
    assert_not_nil parent.reload.conversation
    assert_equal 2, parent.reload.conversation.murmurs.size
    assert_equal ['Hello', 'Hey there'], parent.reload.conversation.murmurs.map(&:murmur)
  end

  def test_replying_to_a_reply_adds_the_murmur_to_the_conversation
    parent = create_murmur(:murmur => "Hello")
    xhr :post, :create, :murmur => { :murmur => 'Replying with hello back', :replying_to_murmur_id => parent.id.to_s }, :project_id => @project.identifier, :format => 'json'
    assert_response :success
    assert_equal ["Hello", "Replying with hello back"], parent.reload.conversation.murmurs.map(&:murmur)
    assert_equal @project, parent.conversation.project
  end

  def test_should_load_murmurs_for_a_conversation
    conversation = @project.conversations.create
    parent = create_murmur(:murmur => "Hello", :conversation_id => conversation.id)
    reply = create_murmur(:murmur => "Replying with hello back", :conversation_id => conversation.id)

    get :conversation, :conversation_id => conversation.id, :format => 'json', :project_id => @project.identifier
    assert_response :success
    murmurs = JSON.parse(@response.body)
    assert_equal 2, murmurs.length
  end

  def test_should_add_create_card_murmur_in_app_monitoring_event
    MingleConfiguration.overridden_to(:metrics_api_key => 'm_key') do
      consumer = MessagingTestHelper::SampleConsumer.new
      tracker = EventsTracker.new(consumer)
      @controller.set_events_tracker(tracker)

      xhr :post, :create, :murmur => {:murmur => 'Testing create card murmur in app monitoring event'}, :project_id => @project.identifier, :format => 'json'
      EventsTracker.run_once(:processor => tracker)

      event_data = JSON.parse(consumer.sent.last[1])["data"]
      assert_equal 'create_global_murmur_in_app', event_data['event']
      assert_equal @project.name, event_data['properties']['project_name']
    end
  end

  def image_url(src)
    File.join('http://test.host', image_path(src))
  end
end
