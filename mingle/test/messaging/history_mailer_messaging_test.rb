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
require File.expand_path(File.dirname(__FILE__) + '/messaging_test_helper')

class HistoryMailerMessagingTest < ActiveSupport::TestCase
  include HistoryMailerTestHellper
  include MessagingTestHelper

  def setup
    setup_mailer_project
    @driver = with_cached_repository_driver(name + '_setup') do |driver|
      driver.create
      driver.import("#{Rails.root}/test/data/test_repository")
      driver.checkout
    end
    configure_subversion_for(@project, {:repository_path => @driver.repos_dir})
  end  
  
  def test_card_version_notification_should_show_user_name_when_the_property_is_the_user_property_defintion
     @filter_params = history_filter_query_string({'involved_filter_properties' => {"my_developer" => "#{@member.id}"}})
     @subscription = HistorySubscription.create(:user => @member, :project_id => @project.id, :filter_params => @filter_params,
         :last_max_card_version_id => 1, :last_max_page_version_id => 1, :last_max_revision_id => 1)
     card = create_card!(:name => 'This is my first card', :my_developer => @member.id)
     response = HistoryMailer.deliver_card_version_notification(card.versions.first, [@subscription])
     assert response.body.include?("my_developer:&nbsp;#{@member.name}")
   end

   def test_should_show_unsubscribe_url_and_version_url_in_notification_email
     does_not_work_without_subversion_bindings do
       @project.revisions.create!(:number => '1', :identifier => '1',
        :commit_message => 'for notification email test', :commit_time => Clock.now, :commit_user => 'jb')
       create_card!(:name => 'This is my first card', :description => 'Blah blah #123 blah blah')
       @project.pages.create!(:name => 'This is my first page')
       HistoryGeneration.run_once

       response = HistoryMailer.deliver_card_version_notification(@project.card_versions.first, [@subscription])
       assert_email_contains_unsubscribe_link(response.body)
       assert_email_contains_card_link(@project.card_versions.first, response.body)
       assert_email_contains_url("http://test.host/projects/#{@project.identifier}/cards/123", response.body)

       response = HistoryMailer.deliver_page_version_notification(@project.page_versions.first, [@subscription])
       assert_email_contains_unsubscribe_link(response.body)
       assert_email_contains_page_link(@project.page_versions.first, response.body)

       response = HistoryMailer.deliver_revision_notification(@project.revisions.first, [@subscription])
       assert_email_contains_unsubscribe_link(response.body)
       # TODO: we should have a link here too
     end
   end
   
   def test_should_not_print_macro_content_in_emails
     @project.history_subscriptions.each(&:destroy)
     card = create_card!(:name => 'very welcoming story')
     subscription = @project.create_history_subscription(@member, HistoryFilterParams.new(:card_number => card.number).serialize)
     ActionMailer::Base.deliveries.clear

     card.update_attributes(:description => %{
       {{
         pivot-table
           conditions: old_type IN (Story, Task) AND Release = '1.0' 
           rows: old_type
           columns: Status
           empty-rows: false
           empty-columns: false
           totals: true
       }}

       This is not a macro
     })
     HistoryGeneration.run_once
     @project.send_history_notifications
     assert 1, ActionMailer::Base.deliveries.size
     description_changed_email = ActionMailer::Base.deliveries.first

     assert description_changed_email.body =~ /This is not a macro/
     assert description_changed_email.body !~ /I look like a macro/
   end
   
   def test_should_continue_processing_history_subscriptions_even_if_a_particular_subscription_fails
     open_things_subscription = @project.create_history_subscription(@member, "involved_filter_properties[status]=open")
     closed_things_subscription = @project.create_history_subscription(@member, "involved_filter_properties[status]=closed")

     sql_to_update_a_subscription_to_a_bad_value = SqlHelper.sanitize_sql(%{
       UPDATE history_subscriptions
       SET filter_params = ?
       WHERE id = ?
     }, "involved_filter_properties[stat]=open", open_things_subscription.id)
     HistorySubscription.connection.execute(sql_to_update_a_subscription_to_a_bad_value)

     card = create_card!(:name => 'This is my first card')
     card.update_attribute(:cp_status, 'open')
     card.update_attribute(:cp_status, 'closed')
     HistoryGeneration.run_once

     @project.history_subscriptions.reload
     @project.send_history_notifications

     assert_equal 1, ActionMailer::Base.deliveries.size
     first_mail = ActionMailer::Base.deliveries.first
     assert first_mail.body =~ /history\/unsubscribe\/#{closed_things_subscription.id}/
     assert first_mail.body !~ /history\/unsubscribe\/#{open_things_subscription.id}/
   end  

   def test_should_show_correct_version_number_on_card_subscribtion
     @subscription = HistorySubscription.create(:user => @member, :project_id => @project.id, :filter_params => nil, :last_max_card_version_id => 1, :last_max_page_version_id => 1, :last_max_revision_id => 1)
     card = create_card!(:name => 'This is my first card')
     card.update_attribute(:cp_status, 'open')
     card.update_attribute(:cp_status, 'done')
     HistoryMailer.deliver_card_version_notification(card.reload.versions[1], [@subscription])
     card_property_change_email = ActionMailer::Base.deliveries.first
     assert card_property_change_email.body.include?("View latest version")
     assert card_property_change_email.body.include?("View this version (v2)")
   end
   
   def test_should_show_change_details_in_page_notification_emails
     page = @project.pages.create!(:name => 'some page')
     subscription = @project.create_history_subscription(@member, HistoryFilterParams.new(:page_identifier => page.identifier).serialize)
     page.tag_with('panda, koala')
     page.save!
     HistoryGeneration.run_once

     ActionMailer::Base.deliveries.clear
     @project.send_history_notifications
     description_changed_email = ActionMailer::Base.deliveries.first
     assert description_changed_email.body =~ /Tagged with panda/
     assert description_changed_email.body =~ /Tagged with koala/
   end
   
   def test_send_notifications_associates_event_notifications_only_appropriate_subscriptions
     with_project_without_cards_and_create_a_user do |project, user|
       card_23 = project.cards.create!(:name => 'test card', :number => 23, :card_type => project.card_types.first)
       card_47 = project.cards.create!(:name => 'another test card', :number => 47, :card_type => project.card_types.first)

       subscription_1 = project.create_history_subscription(user, "")
       subscription_2 = project.create_history_subscription(user, "card_number=23")
       subscription_2 = project.create_history_subscription(user, "card_number=47")

       card_23.update_attribute(:name, 'a new name')

       HistoryGeneration.run_once
       user.send_history_notifications_for(project)

       notification = ActionMailer::Base.deliveries.first.body
       assert notification.include?('Project Without Cards history')
       assert notification.include?('Card #23')
       assert !notification.include?('Card #47')
      end
   end
   
   def test_send_notifications_associates_event_notifications_into_a_single_mail_for_a_user
     with_project_without_cards_and_create_a_user do |project, user|
       card_23 = project.cards.create!(:name => 'test card', :number => 23, :card_type => project.card_types.first)
       card_47 = project.cards.create!(:name => 'another test card', :number => 47, :card_type => project.card_types.first)

       subscription_1 = project.create_history_subscription(user, "")
       subscription_2 = project.create_history_subscription(user, "card_number=23")
       subscription_2 = project.create_history_subscription(user, "card_number=47")

       card_23.update_attribute(:name, 'a new name')

       HistoryGeneration.run_once
       project.send_history_notifications

       mails = ActionMailer::Base.deliveries
       assert_equal 1, mails.size

       notification = mails.first.body
       assert notification.include?('Project Without Cards history')
       assert notification.include?('Card #23')
       assert !notification.include?('Card #47')
      end
   end

   def test_send_notifications_delivers_mail_for_each_event_type
     does_not_work_without_subversion_bindings do
       with_project_without_cards_and_create_a_user do |project, user|
         subscription = project.create_history_subscription(user, "")
         project.cards.create!(:name => 'first card', :card_type => project.card_types.first)
         project.revisions.create!(:number => 1, :identifier => '1',
          :commit_message => 'i made a change', :commit_time => Time.now, :commit_user => 'david')
         project.pages.create!(:name => 'first page')     
         HistoryGeneration.run_once
         user.send_history_notifications_for(project)

         deliveries = ActionMailer::Base.deliveries
         assert_equal 3, deliveries.size    
         assert(['Card #1', 'Page first page', 'Revision 1'].all? do |expected_subject|
           deliveries.any?{|delivery| delivery.subject.include?(expected_subject)}
         end)
       end
     end
   end
   
   def test_should_not_send_notification_when_global_history_changes_were_not_generated_yet
     with_project_without_cards_and_create_a_user do |project, user|
       card = project.cards.create!(:name => 'some card', :card_type_name => 'Card')
       page = project.pages.create!(:name => 'some page')
       project.create_history_subscription(user, "")
       project.create_history_subscription(user, "card_number=#{card.number}")
       project.create_history_subscription(user, "page_identifier=#{page.identifier}")
       
       card.update_attribute(:description, 'hi there')
       page.update_attribute(:content, 'hello')
       user.send_history_notifications_for(project)
       assert_equal 0, ActionMailer::Base.deliveries.size
       
       HistoryGeneration.run_once
       user.destroy_subscriptions_by_event_cache!
       user.send_history_notifications_for(project)
       assert_equal 2, ActionMailer::Base.deliveries.size
     end
   end
   
   def test_send_notifications_updates_last_max_ids_to_last_sent_for_each_event_type
     with_project_without_cards_and_create_a_user do |project, user|
       subscription = project.create_history_subscription(user, "")
       project.cards.create!(:name => 'first card', :card_type => project.card_types.first)
       project.revisions.create!(:number => 29, :identifier => '29', 
        :commit_message => 'i made a change', :commit_time => Time.now, :commit_user => 'david')
       project.pages.create!(:name => 'first page')            
       HistoryGeneration.run_once
       user.send_history_notifications_for(project)

       subscription.reload
       assert_equal project.card_versions.maximum('id'), subscription.last_max_card_version_id
       assert_equal project.page_versions.maximum('id'), subscription.last_max_page_version_id
       assert_equal project.revisions.maximum('id'), subscription.last_max_revision_id
    end
   end

   def test_send_notifications_makes_subscription_current_when_no_user_email
     with_project_without_cards_and_create_a_user do |project, user|
       user.update_attribute(:email, nil)
       subscription = project.create_history_subscription(user, "")
       project.cards.create!(:name => 'first card', :card_type => project.card_types.first)
       project.revisions.create!(:number => 29, :identifier => '29',
        :commit_message => 'i made a change', :commit_time => Time.now, :commit_user => 'david')
       project.pages.create!(:name => 'first page')            
       user.send_history_notifications_for(project)

       subscription.reload
       assert_equal project.card_versions.maximum('id'), subscription.last_max_card_version_id
       assert_equal project.page_versions.maximum('id'), subscription.last_max_page_version_id
       assert_equal project.revisions.maximum('id'), subscription.last_max_revision_id
     end
   end

   def test_send_notifications_does_not_attempt_to_notify_when_no_user_email
     with_project_without_cards_and_create_a_user do |project, user|
       user.update_attribute(:email, nil)
       subscription = project.create_history_subscription(user, "")
       project.cards.create!(:name => 'first card', :card_type => project.card_types.first)
       project.revisions.create!(:number => 29, :identifier => '29',
        :commit_message => 'i made a change', :commit_time => Time.now, :commit_user => 'david')
       project.pages.create!(:name => 'first page')            
       user.send_history_notifications_for(project)

       assert_equal 0, ActionMailer::Base.deliveries.size
     end
   end

   def test_send_notifications_does_not_deliver_duplicate_emails_when_user_has_overlapping_subscriptions
     with_project_without_cards_and_create_a_user do |project, user|
       subscription_1 = project.create_history_subscription(user, "")
       subscription_2 = project.create_history_subscription(user, "card_number=47")        
       card = project.cards.create!(:name => 'test card', :number => 47, :card_type => project.card_types.first)
       project.pages.create!(:name => 'first page')    
       HistoryGeneration.run_once
       user.send_history_notifications_for(project)

       assert_equal 2, ActionMailer::Base.deliveries.size
       ActionMailer::Base.deliveries.clear
       project.reload.send_history_notifications
       assert_equal 0, ActionMailer::Base.deliveries.size
     end
   end

   def test_send_notifications_makes_current_all_subscriptions_when_user_has_overlapping_subscriptions
     with_project_without_cards_and_create_a_user do |project, user|
       subscription_1 = project.create_history_subscription(user, "")
       subscription_2 = project.create_history_subscription(user, "card_number=47")        
       card = project.cards.create!(:name => 'test card', :number => 47, :card_type => project.card_types.first)
       project.pages.create!(:name => 'first page')    
       HistoryGeneration.run_once
       user.send_history_notifications_for(project)
       [subscription_1, subscription_2].each do |subscription|
         subscription.reload
         assert_equal project.card_versions.maximum('id'), subscription.last_max_card_version_id
         assert_equal project.page_versions.maximum('id'), subscription.last_max_page_version_id
       end
     end
   end
   
   # bug 8961
   def test_should_send_notifications_to_mingle_admins_even_when_they_are_not_project_members
     admin_user = User.first_admin
     assert !admin_user.member_of?(@project)
     
     card = @project.cards.create!(:name => 'some card', :card_type_name => 'Card')
     subscription = @project.create_history_subscription(admin_user, "card_number=#{card.number}")
     card.name = 'updated name'
     card.save!
     HistoryGeneration.run_once
     @project.send_history_notifications
     
     assert_equal 1, ActionMailer::Base.deliveries.size
     assert_equal [admin_user.email], ActionMailer::Base.deliveries.first.to
   end
   
   def test_error_messages_truncated_to_255_characters
      with_project_without_cards_and_create_a_user do |project, user|
        subscription = project.create_history_subscription(user, "")
        def subscription.fresh_events(options)
          raise "a" * 300
        end
        user.send(:history_subscriptions_by_event, [subscription], {})

        assert_equal 255, subscription.reload.error_message.length
     end
    end
    
   def with_project_without_cards_and_create_a_user(&block)
     with_project_without_cards do |project|
       @driver = with_cached_repository_driver(name + '_setup') do |driver|
         driver.create
         driver.import("#{Rails.root}/test/data/test_repository")
         driver.checkout
       end
       configure_subversion_for(project, {:repository_path => @driver.repos_dir})
       
       user = create_user!
       project.add_member(user)
       yield(project, user)
     end
   end
   
end
