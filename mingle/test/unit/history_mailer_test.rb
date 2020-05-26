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

class HistoryMailerTest < ActiveSupport::TestCase
  include HistoryMailerTestHellper

  def setup
    setup_mailer_project
  end

  def teardown
    teardown_mailer_project
  end

  def test_subscribe
    response = HistoryMailer.deliver_subscribe(@subscription)
    assert_equal "You have subscribed to #{@project.name} history", response.subject
    assert_equal @subscription.user.email, response.to[0]
    assert response.body.include?('old_type')
    assert response.body.include?('card')
    assert response.body.include?('status')
    assert response.body.include?('done')
    assert response.body.include?('apple')
    assert response.body.include?('orange')
    assert_email_contains_unsubscribe_link(response.body)
    assert_email_contains_manage_subscription_link(response.body)
    assert response.body.include?(@member.name)
  end

  def test_subscribe_to_history_for_a_instance_accessed_over_https
    old_options = MingleConfiguration.site_u_r_l
    begin
      MingleConfiguration.site_u_r_l = 'https://somehost'
      response = HistoryMailer.deliver_subscribe(@subscription)
      assert response.body.include?("https://somehost/projects/#{@project.identifier}/history/unsubscribe/#{@subscription.id}")
    ensure
      MingleConfiguration.site_u_r_l = old_options
    end
  end

  def test_subscribe_mail_shoud_shown_user_name_when_the_property_is_the_user_property_definition
    @filter_params = history_filter_query_string({'involved_filter_properties' => {"my_developer" => "#{@member.id}"}})
    @subscription = HistorySubscription.create(:user => @member, :project => @project, :filter_params => @filter_params,
        :last_max_card_version_id => 1, :last_max_page_version_id => 1, :last_max_revision_id => 1)
    response = HistoryMailer.deliver_subscribe(@subscription)
    assert response.body.include?("my_developer: #{@member.name}")
  end

  def test_filter_params_could_be_empty
    project = first_project
    subscriber = HistorySubscription.create(:user => User.find_by_login("first"), :project_id => project.id,
      :last_max_card_version_id => 1, :last_max_page_version_id => 1, :last_max_revision_id => 1)
    response = HistoryMailer.deliver_subscribe(subscriber)
    assert_equal "You have subscribed to #{project.name} history", response.subject
  end

  def test_should_have_project_based_sender_if_project_is_configured
   @project.update_attributes(:email_sender_name => 'mailman', :email_address => 'post@office.com')
    subscriber = HistorySubscription.create(:user => @member, :project_id => @project.id,
      :last_max_card_version_id => 1, :last_max_page_version_id => 1, :last_max_revision_id => 1)
    response = HistoryMailer.deliver_subscribe(subscriber)
    assert_equal 'post@office.com', response.from_addrs.first.spec
    assert_equal 'mailman', response.from_addrs.first.name
  end

  def test_should_use_default_mingle_sender_if_project_is_not_configured
    subscriber = HistorySubscription.create(:user => @member, :project_id => @project.id,
      :last_max_card_version_id => 1, :last_max_page_version_id => 1, :last_max_revision_id => 1)
    response = HistoryMailer.deliver_subscribe(subscriber)
    assert_equal 'hello@example.com', response.from_addrs.first.spec #from smtp_config
    assert_equal 'mingle', response.from_addrs.first.name #from smtp_config
  end

  def test_should_use_default_mingle_sender_if_project_configured_but_smtp_not_active_feature
    begin
      FEATURES.deactivate("smtp_configuration")
      @project.update_attributes(:email_sender_name => 'mailman', :email_address => 'post@office.com')
      subscriber = HistorySubscription.create(:user => @member, :project_id => @project.id,
                                              :last_max_card_version_id => 1, :last_max_page_version_id => 1, :last_max_revision_id => 1)
      response = HistoryMailer.deliver_subscribe(subscriber)
      assert_equal 'hello@example.com', response.from_addrs.first.spec #from smtp_config
    ensure
      FEATURES.activate("smtp_configuration")
    end
  end

  def test_should_provide_page_name_in_welcome_email_subject
    page = @project.pages.create!(:name => 'very welcoming things')
    subscription = @project.create_history_subscription(@member, HistoryFilterParams.new(:page_identifier => page.identifier).serialize)

    HistoryMailer.deliver_subscribe(subscription)
    welcome_email = ActionMailer::Base.deliveries.first
    assert_equal "You have subscribed to very welcoming things page", welcome_email.subject
    assert welcome_email.body =~ /all events related to this page/
  end

  def test_should_provide_card_description_in_welcome_email_subject
    card = create_card!(:name => 'very welcoming story')
    subscription = @project.create_history_subscription(@member, HistoryFilterParams.new(:card_number => card.number).serialize)

    HistoryMailer.deliver_subscribe(subscription)
    welcome_email = ActionMailer::Base.deliveries.first
    assert_equal "You have subscribed to Card ##{card.number} very welcoming story", welcome_email.subject
    assert welcome_email.body =~ /all events related to this card/
  end
end
