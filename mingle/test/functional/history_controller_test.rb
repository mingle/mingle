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

class HistoryControllerTest < ActionController::TestCase
  include HistoryHelper

  def setup
    Clock.reset_fake
    @controller = create_controller HistoryController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    ActionMailer::Base.deliveries = []

    @member_user = User.find_by_login('member')
    login_as_member

    @project = create_project :users => [@member_user]
    @project.revisions.create(:number => 10, :commit_time => 2.minutes.ago.utc, :commit_message => 'This is a revision', :commit_user => 'revisionUser')

    setup_property_definitions :feature => ['email', 'atom'], :status => ['open', 'new'], :old_type => ['card'], :"special + characters" => ['lagniappe']

    @project.update_attributes(:email_address =>  'email@address.com', :email_sender_name => 'thoughtworks')
  end

  def test_cant_get_history_feed_based_on_invalid_encrypted_spec
    get :feed, {:format => "atom", :project_id => @project.identifier, :encrypted_history_spec => 'invalid' }
    assert_redirected_to project_show_url
  end

  def test_feed_url_is_encrypted
    get :index, {:tagged_with => 'feature-email', :project_id => @project.identifier}
    assert_no_tag 'a', :attributes => {:id => 'subscribe-link', :href => /email/}
  end

  def test_should_give_useful_error_message_if_smtp_configuration_does_not_specify_default_url_options
    def @controller.smtp
      OpenStruct.new(:configured? => false)
    end

    xhr :post, :subscribe, :project_id => @project.identifier, :filter_params => history_filter_query_string({:involved_filter_properties => {"old_type" => "card", "feature" => nil}})
    assert @response.body =~ /This feature is not configured\. Contact your Mingle administrator for details\./
  end

  def test_cannot_subscribe_via_email_without_an_email_address
    member = User.find_by_login('member')
    member.update_attribute('email', nil)
    get :index, :project_id => @project.identifier, :period => 'all_history'
    assert_select 'p.email-disabled'
  end

  #bug 9930
  def test_invalid_period_should_not_cause_500
    get :index, :project_id => @project.identifier, :period => 'unsupported"'
    assert_response :success
  end

  def test_should_login_in_when_access_history_list
    logout_as_nil
    get :index, :project_id  => @project.identifier
    assert_redirected_to :controller  => 'profile', :action => 'login'
  end

  def test_period_links_should_be_generated_properly
    login_as_member
    get :index, :project_id => @project.identifier, :period => 'today', :involved_filter_properties => {"old_type" => "card", "feature" => nil}

    assert_response :success
    assert_select "a", :content => "Yesterday"

    period_link = find_tag :tag => 'a', :content => 'Yesterday'
    href = URI.unescape(period_link.attributes['href'])
    assert href.include?("involved_filter_properties[old_type]=card")
    assert href.include?('period=yesterday')
  end

  def test_events_for_deleted_cards_and_pages_are_not_included_in_results
    login_as_admin
    with_new_project do |project|
      card = create_card! :name => 'goodbye'
      page = project.pages.create! :name => 'shortlived'
      card.destroy
      page.destroy
      get :index, :project_id => project.identifier, :period => 'today'

      assert_select 'div.card-event', :count => 0
      assert_select 'div.page-event', :count => 0
    end
  end

  def test_post_to_index_should_get_javascript_response
    xhr :post, :index, :project_id => @project.identifier, :period => 'today', :involved_filter_properties => {"old_type" => "card", "feature" => nil}, :acquired_filter_properties => {}
    assert_response :success
    assert_include '$("history-results").update', @response.body
  end

  # bug 10769
  def test_special_characters_in_property_name_are_escaped_properly_in_new_subscribe_link
    xhr :post, :index, :project_id => @project.identifier, :period => 'today', :involved_filter_properties => {"special + characters" => "lagniappe"}
    assert_response :success
    assert_include 'special+%2B+characters', @response.body
  end

  def test_special_characters_in_property_name_are_escaped_properly_after_clicked_link_to_this_page
    get :index, :project_id => @project.identifier, :period => 'today', :involved_filter_properties => {"special + characters" => "lagniappe"}
    assert_response :success
    assert_select '#subscribe-via-email' do
      assert_select 'a.email' do |match|
        assert_match /special\+%2B\+characters/, match.to_s
      end
    end
  end

  def test_subscribe_the_history_via_email
    login_as_member

    post :subscribe,
      :project_id => @project.identifier,
      :filter_params => history_filter_query_string({:involved_filter_properties => {"old_type" => "card", "feature" => nil}})
    assert_response :success
    assert_equal 1, ActionMailer::Base.deliveries.size
    delivery_mailer = ActionMailer::Base.deliveries.first

    assert @member_user.email, delivery_mailer.to

    assert delivery_mailer.encoded.include?('thoughtworks <email@address.com>')

    assert delivery_mailer.body.include?('old_type')
    assert delivery_mailer.body.include?('card')
    assert delivery_mailer.body.include?("projects/#{@project.identifier}/history/unsubscribe/")
  end

  # bug 10294
  def test_unsubscribe_from_history_via_email_should_work_via_get
    login_as_member

    post :subscribe, :project_id => @project.identifier
    get :unsubscribe, :project_id => @project.identifier, :id => @project.reload.history_subscriptions.first.id
    assert_response :redirect
    assert_redirected_to :action => "index"

    assert_equal 0, @project.reload.history_subscriptions.size
    assert flash[:notice].include?("You have successfully unsubscribed from #{@project.name} history.")
  end

  # bug 10294
  def test_unsubscribe_from_history_via_email_works_should_work_via_post
    login_as_member

    post :subscribe, :project_id => @project.identifier
    post :unsubscribe, :project_id => @project.identifier, :id => @project.reload.history_subscriptions.first.id
    assert_response :redirect
    assert_redirected_to :action => "index"

    assert_equal 0, @project.reload.history_subscriptions.size
    assert flash[:notice].include?("You have successfully unsubscribed from #{@project.name} history.")
  end

  def test_unsubscribe_via_email_to_a_deleted_card
    login_as_member

    card = create_card!(:name => 'subscribed card')
    post :subscribe, :project_id => @project.identifier, :filter_params => {:card_number => card.number}
    history_subscription_id = @project.history_subscriptions.first.id
    card.destroy
    post :unsubscribe, :project_id => @project.identifier, :id => history_subscription_id
    assert_redirected_to project_show_url
    assert_equal "The Mingle history notification from which you are trying to unsubscribe is no longer valid or no longer exists.", flash[:error]
  end

  def test_unsubscribe_via_email_to_a_deleted_page
    with_first_project do |project|
      login_as_member
      page = project.pages.create!(:name => 'subscribed page')
      post :subscribe, :project_id => project.identifier, :filter_params => {:page_identifier => page.identifier}
      deleted_page_subscription_id = project.history_subscriptions.first.id
      login_as_proj_admin
      page.destroy

      login_as_member
      post :unsubscribe, :project_id => project.identifier, :id => deleted_page_subscription_id
      assert_redirected_to project_show_url
      assert_equal "The Mingle history notification from which you are trying to unsubscribe is no longer valid or no longer exists.", flash[:error]
    end
  end

  def test_unsubscribe_via_profile_page_link_returns_javascript_response
    with_first_project do |project|
      login_as_member
      page = project.pages.create!(:name => 'subscribed page')
      post :subscribe, :project_id => project.identifier, :filter_params => {:page_identifier => page.identifier}
      xhr :post, :delete, :project_id => project.identifier, :id => project.history_subscriptions.first.id
      assert_response :success # Not redirected
      assert_equal "You have successfully unsubscribed from subscribed page.", flash[:notice]
      assert_equal 0, project.history_subscriptions.count
      assert_match(Regexp.new('SubscriptionsCounter.noSubscriptionsCheck()'), @response.body, 'The response body did not include SubscriptionsCounter.noSubscriptionsCheck()')
    end
  end

  # bug 10294
  def test_unsubscribe_via_profile_page_should_not_work_via_get
    with_first_project do |project|
      login_as_member
      page = project.pages.create!(:name => 'subscribed page')
      post :subscribe, :project_id => project.identifier, :filter_params => {:page_identifier => page.identifier}

      xhr :get, :delete, :project_id => project.identifier, :id => project.history_subscriptions.first.id
      assert_response :bad_request

      get :delete, :project_id => project.identifier, :id => project.history_subscriptions.first.id
      assert_response :bad_request
    end
  end

  def test_unsubscribe_via_profile_page_link_to_a_deleted_page
    with_first_project do |project|
      login_as_member
      page = project.pages.create!(:name => 'subscribed page')
      post :subscribe, :project_id => project.identifier, :filter_params => {:page_identifier => page.identifier}
      deleted_page_subscription_id = project.history_subscriptions.first.id
      login_as_proj_admin
      page.destroy

      login_as_member
      xhr :post, :delete, :project_id => project.identifier, :id => deleted_page_subscription_id
      assert_response :success # Not redirected
      assert_equal "The Mingle history notification from which you are trying to unsubscribe is no longer valid or no longer exists.", flash[:error]
    end
  end

  def test_unsubscribe_via_profile_page_should_html_escape_message
    login_as_member
    name_with_html = '<h1>foo</h1>'
    card = create_card!(:name => name_with_html)
    post :subscribe, :project_id => @project.identifier, :filter_params => {:card_number => card.number}

    history_subscription_id = @project.history_subscriptions.reload.first.id
    post :delete, :project_id => @project.identifier, :id => history_subscription_id
    assert_include name_with_html.escape_html, flash[:notice]
  end

  def test_admin_can_unsubscribe_from_a_members_subscription_via_profile_page_link
    with_first_project do |project|
      login_as_member
      page = project.pages.create!(:name => 'subscribed page')
      post :subscribe, :project_id => project.identifier, :filter_params => {:page_identifier => page.identifier}

      login_as_proj_admin
      xhr :post, :delete, :project_id => project.identifier, :id => project.history_subscriptions.first.id, :user_id => project.history_subscriptions.first.user_id
      assert_response :success # Not redirected
      assert flash[:error].blank?
      assert flash[:notice].include?("You have successfully unsubscribed from subscribed page.")
    end
  end

  # bug 7264, 7705 - references to card are not shown as a link in the notice message when unsubscribing from history
  def test_unsubscribe_from_card_history_provides_link_to_card
    with_first_project do |project|
      login_as_member
      card = create_card! :name => 'first card', :number => 100
      post :subscribe, :project_id => project.identifier, :filter_params => { :card_number => card.number }
      xhr :post, :delete, :project_id => project.identifier, :id => project.history_subscriptions.first.id
      assert_response :success # Not redirected
      assert_match /You have successfully unsubscribed from Card <a href.*#{project.identifier}\/cards\/#{card.number}\">##{card.number}<\/a> #{card.name}./, flash[:notice]
      assert_equal 0, project.history_subscriptions.count
    end
  end

  def test_should_not_be_able_to_subscribe_twice
    with_first_project do |project|
      login_as_member
      card = project.cards.first
      post :subscribe, :project_id => project.identifier, :filter_params => { :card_number => card.number }
      post :subscribe, :project_id => project.identifier, :filter_params => { :card_number => card.number }
      assert_equal 1, User.current.history_subscriptions.size
    end
  end

  def test_show_dependency_history
    with_first_project do |project|
      login_as_member
      card = project.cards.first
      dependency = card.raise_dependency(
        :desired_end_date => "8-11-2014",
        :resolving_project_id => project.id,
        :name => "some dependency")
      dependency.save!
      get :index, :project_id => project.identifier, :period => 'all_history'
      assert_select '.dependency-event', :count => 1

      dependency.update_attribute(:description, 'New description')
      get :index, :project_id => project.identifier, :period => 'all_history'
      assert_select '.dependency-event', :count => 2
    end
  end

  private

  def get_history_atom(options = {})
    encrypted_history_spec = @project.encrypt(HistoryFilterParams.new(options).serialize)
    get :feed, {:format => "atom", :project_id => @project.identifier, :encrypted_history_spec => encrypted_history_spec }

    assert_response :success
    assert_template 'index.atom.rxml'
    assert @response.headers['Content-Type'].include?("application/atom+xml")
  end

end
