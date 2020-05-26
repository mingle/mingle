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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../messaging/messaging_test_helper')

class MurmurCreatorTest < ActiveSupport::TestCase
  EMAIL_CLIENT_STRING = 'Custom User Agent; 1.0'

  include MessagingTestHelper
  ENABLE_EMAIL_REPLIES = {:saas_env => 'some_env'}

  ENABLE_METRIC_TRACKING_WITH_ATTACHMENTS = ENABLE_EMAIL_REPLIES.merge(:metrics_api_key => 'm_key')

  def setup
    @project = first_project
    @member = User.find_by_login('member')
    @bob = User.find_by_login('bob')
  end

  def teardown
    CurrentLicense.clear_cached_registration!
  end

  def test_should_create_murmur_in_reply_to_global_murmur
    murmur = create_existing_global_murmur

    MingleConfiguration.overridden_to(ENABLE_EMAIL_REPLIES) do
      data = create_murmur_data({:murmur_text => 'murmur reply', :user_id => @bob.id, :murmur_id => murmur.id})
      murmur_reply = MurmurCreator.new.create(data)

      assert_not_nil murmur_reply
      assert_equal 'murmur reply', murmur_reply.murmur
      assert murmur_reply.created_from_email?
      assert_equal @bob, murmur_reply.author
      assert_equal 2, murmur_reply.conversation.murmurs.size
      assert_equal murmur.murmur, murmur_reply.conversation.murmurs.first.murmur
      assert_equal 'murmur reply', murmur_reply.conversation.murmurs.last.murmur
      assert_equal murmur_reply.project_id, @project.id
      assert_nil murmur_reply.origin_id
    end
  end

  def test_should_create_murmur_in_reply_to_card_murmur
    @project.with_active_project do
      murmur = create_existing_card_murmur
      MingleConfiguration.overridden_to(ENABLE_EMAIL_REPLIES) do
      data = create_murmur_data({:murmur_text => 'murmur reply', :user_id => @bob.id, :murmur_id => murmur.id})
      murmur_reply = MurmurCreator.new.create(data)

      assert_not_nil murmur_reply
      assert_equal 'murmur reply', murmur_reply.murmur
      assert murmur_reply.created_from_email?
      assert_equal @bob, murmur_reply.author
      assert_equal 2, murmur_reply.conversation.murmurs.size
      assert_equal murmur.murmur, murmur_reply.conversation.murmurs.first.murmur
      assert_equal 'murmur reply', murmur_reply.conversation.murmurs.last.murmur
      assert_equal murmur_reply.project_id, @project.id
      assert_equal murmur.origin_id, murmur_reply.origin_id
      assert_equal 'Card', murmur_reply.origin_type
      assert_equal ['bob'], murmur.mentioned_users.map(&:login)
      end
    end
  end

  def test_should_return_nil_on_invalid_murmur_id
    MingleConfiguration.overridden_to(ENABLE_EMAIL_REPLIES) do
      murmur_reply = MurmurCreator.new.create(create_murmur_data({:murmur_id => 9292929}))
      assert_nil murmur_reply
    end
  end

  def test_should_not_create_murmur_and_send_auto_reply_if_card_is_deleted
    member = nil
    murmur = nil
    with_new_project do |project|
      member = create_user!
      member2 = create_user!
      project.add_member(member, :full_member)
      project.add_member(member2, :full_member)

      member.with_current do
        card = project.cards.create(:name => 'first_card', :card_type_name => 'Card')
        murmur = card.origined_murmurs.create!(:murmur => "hello",
                                               :author => User.current, :project_id => project.id)
        card.destroy
      end
    end

    MingleConfiguration.overridden_to(ENABLE_EMAIL_REPLIES) do
      murmur_auto_reply_notification = mock
      murmur_auto_reply_notification.expects(:send_auto_reply).with(responds_with(:address, 'murmur-reply@email.com'), responds_with(:address, member.email), 'murmur_subject', :invalid_operation)
      murmur_reply = MurmurCreator.new(murmur_auto_reply_notification).create(create_murmur_data({:murmur_text => 'murmur-reply', :murmur_id => murmur.id, :user_email => member.email, :user_id => member.id}))
      assert_nil murmur_reply
    end
  end

  def test_should_not_create_murmur_and_send_auto_reply_if_user_is_not_authorized
    member = nil
    murmur = nil
    with_new_project do |project|
      member = create_user!
      member2 = create_user!
      project.add_member(member, :full_member)
      project.add_member(member2, :full_member)
      member2.with_current do
        murmur = create_murmur(:murmur => "hi there", :author => member2)
      end
      project.remove_member(member)
    end

    MingleConfiguration.overridden_to(ENABLE_EMAIL_REPLIES) do
      murmur_auto_reply_notification = mock
      murmur_auto_reply_notification.expects(:send_auto_reply).with(responds_with(:address, 'murmur-reply@email.com'), responds_with(:address, member.email), 'murmur_subject', :invalid_operation)
      murmur_reply = MurmurCreator.new(murmur_auto_reply_notification).create(create_murmur_data({:murmur_text => 'murmur-reply', :murmur_id => murmur.id, :user_email => member.email, :user_id => member.id}))
      assert_nil murmur_reply
    end

  end

  def test_global_murmur_creation_should_authorize_for_murmurs_create
    murmur = create_existing_global_murmur

    murmur_creator = MurmurCreator.new
    murmur_creator.expects(:authorized_for?).with(@project, 'murmurs:create').returns(true)

    MingleConfiguration.overridden_to(ENABLE_EMAIL_REPLIES) do
      data = create_murmur_data({:murmur_text => 'murmur reply', :user_id => @bob.id, :murmur_id => murmur.id})
      murmur_reply = murmur_creator.create(data)

      assert_not_nil murmur_reply
    end
  end

  def test_card_murmur_creation_should_authorize_for_cards_add_comment
      murmur = create_existing_card_murmur

      murmur_creator = MurmurCreator.new
      murmur_creator.expects(:authorized_for?).with(@project, 'cards:add_comment').returns(true)

      MingleConfiguration.overridden_to(ENABLE_EMAIL_REPLIES) do
        data = create_murmur_data({:murmur_text => 'murmur reply', :user_id => @bob.id, :murmur_id => murmur.id})
        murmur_reply = murmur_creator.create(data)

        assert_not_nil murmur_reply
      end
  end

  def test_should_not_create_murmur_and_send_auto_reply_if_max_users_limit_reached
    member = nil
    murmur = nil
    with_new_project do |project|
      member = create_user!
      member2 = create_user!
      project.add_member(member, :full_member)
      project.add_member(member2, :full_member)
      member2.with_current do
        murmur = create_murmur(:murmur => "hi there", :author => member2)
      end
    end
    (1..(6 - User.activated_full_users)).each{ create_user_without_validation }
    CurrentLicense.register!({:licensee =>'testuser', :max_active_users => '5' ,:expiration_date => '2008-07-13', :max_light_users => '8', :product_edition => Registration::NON_ENTERPRISE}.to_query, 'testuser')

    MingleConfiguration.overridden_to(ENABLE_EMAIL_REPLIES) do
      murmur_auto_reply_notification = mock
      murmur_auto_reply_notification.expects(:send_auto_reply).with(responds_with(:address, 'murmur-reply@email.com'), responds_with(:address, member.email), 'murmur_subject', :invalid_operation)
      murmur_reply = MurmurCreator.new(murmur_auto_reply_notification).create(create_murmur_data({:murmur_text => 'murmur-reply', :murmur_id => murmur.id, :user_email => member.email, :user_id => member.id}))
      assert_nil murmur_reply
    end
  end

  def test_should_add_create_card_murmur_via_email_monitoring_event
    murmur = create_existing_card_murmur

    MingleConfiguration.overridden_to(ENABLE_METRIC_TRACKING_WITH_ATTACHMENTS) do
      reply_data = create_murmur_data({:murmur_text => 'murmur reply',
                                       :email_client_info => EMAIL_CLIENT_STRING,
                                       :user_id => @bob.id, :murmur_id => murmur.id})

      consumer = MessagingTestHelper::SampleConsumer.new
      tracker = EventsTracker.new(consumer)

      MurmurCreator.new.create reply_data
      EventsTracker.run_once(:processor => tracker)

      event_data = JSON.parse(consumer.sent.last[1])['data']
      assert_equal 'create_card_murmur_via_email', event_data['event']
      assert_equal @project.name, event_data['properties']['project_name']
      assert_equal EMAIL_CLIENT_STRING, event_data['properties']['email_client_info']
    end
  end

  def test_should_add_create_global_murmur_via_email_monitoring_event
    murmur = create_existing_global_murmur

    MingleConfiguration.overridden_to(ENABLE_METRIC_TRACKING_WITH_ATTACHMENTS) do
      reply_data = create_murmur_data({:murmur_text => 'murmur reply',
                                       :email_client_info => EMAIL_CLIENT_STRING,
                                       :user_id => @bob.id, :murmur_id => murmur.id})

      consumer = MessagingTestHelper::SampleConsumer.new
      tracker = EventsTracker.new(consumer)

      MurmurCreator.new.create reply_data
      EventsTracker.run_once(:processor => tracker)

      event_data = JSON.parse(consumer.sent.last[1])['data']
      assert_equal 'create_global_murmur_via_email', event_data['event']
      assert_equal @project.name, event_data['properties']['project_name']
      assert_equal 'Custom User Agent; 1.0', event_data['properties']['email_client_info']
    end
  end

  def test_should_continue_uploading_other_attachments_when_one_fails
    murmur = create_existing_card_murmur

    failing_uploader = mock
    failing_uploader.expects(:execute).raises(StandardError.new('Failing uploader for test'))

    passing_uploader = mock
    passing_uploader.expects(:execute)

    attachment_uploaders = [failing_uploader, passing_uploader]

    MingleConfiguration.overridden_to(ENABLE_EMAIL_REPLIES) do
      reply_data = create_murmur_data({
                                          :murmur_text => 'murmur reply',
                                          :email_client_info => EMAIL_CLIENT_STRING,
                                          :user_id => @bob.id,
                                          :murmur_id => murmur.id,
                                          :attachment_uploaders => attachment_uploaders,
                                      })


      MurmurCreator.new.create reply_data
    end
  end

  def test_should_add_create_card_attachment_via_email_monitoring_event
    murmur = create_existing_card_murmur

    failing_uploader = mock
    failing_uploader.expects(:execute).raises(StandardError.new('Failing uploader for test'))

    passing_uploader = mock
    passing_uploader.expects(:execute)

    attachment_uploaders = [failing_uploader, passing_uploader]

    MingleConfiguration.overridden_to(ENABLE_METRIC_TRACKING_WITH_ATTACHMENTS) do
      reply_data = create_murmur_data({
                                          :murmur_text => 'murmur reply',
                                          :email_client_info => EMAIL_CLIENT_STRING,
                                          :user_id => @bob.id,
                                          :murmur_id => murmur.id,
                                          :attachment_uploaders => attachment_uploaders,
                                      })
      consumer = MessagingTestHelper::SampleConsumer.new
      tracker = EventsTracker.new(consumer)

      MurmurCreator.new.create reply_data
      EventsTracker.run_once(:processor => tracker)

      event_data = JSON.parse(consumer.sent.first[1])['data']
      assert_equal 'create_card_attachment_via_email', event_data['event']
      assert_equal 1, event_data['properties']['succeeded']
      assert_equal 1, event_data['properties']['failed']
      assert_equal @project.name, event_data['properties']['project_name']
    end
  end

  def test_should_add_create_card_attachment_via_email_monitoring_event_without_failed
    murmur = create_existing_card_murmur

    passing_uploader = mock
    passing_uploader.expects(:execute)

    attachment_uploaders = [passing_uploader]

    MingleConfiguration.overridden_to(ENABLE_METRIC_TRACKING_WITH_ATTACHMENTS) do
      reply_data = create_murmur_data({
                                          :murmur_text => 'murmur reply',
                                          :email_client_info => EMAIL_CLIENT_STRING,
                                          :user_id => @bob.id,
                                          :murmur_id => murmur.id,
                                          :attachment_uploaders => attachment_uploaders,
                                      })
      consumer = MessagingTestHelper::SampleConsumer.new
      tracker = EventsTracker.new(consumer)

      MurmurCreator.new.create reply_data
      EventsTracker.run_once(:processor => tracker)

      event_data = JSON.parse(consumer.sent.first[1])['data']
      assert_equal 'create_card_attachment_via_email', event_data['event']
      assert_equal 1, event_data['properties']['succeeded']
      assert_nil event_data['properties']['failed']
      assert_equal @project.name, event_data['properties']['project_name']
    end
  end

  def test_should_skip_attachments_on_global_murmurs_and_send_auto_reply
    murmur = create_existing_global_murmur

    failing_uploader = mock

    attachment_uploaders = [failing_uploader]
    MingleConfiguration.overridden_to(ENABLE_EMAIL_REPLIES) do
      reply_data = create_murmur_data({
                                          :murmur_text => 'murmur reply',
                                          :email_client_info => EMAIL_CLIENT_STRING,
                                          :user_id => @bob.id,
                                          :murmur_id => murmur.id,
                                          :attachment_uploaders => attachment_uploaders,
                                      })

      auto_reply_notifier = mock
      auto_reply_notifier.expects(:send_auto_reply).with(anything, anything, 'murmur_subject', :global_murmur_attachment_error)
      MurmurCreator.new(auto_reply_notifier).create reply_data
    end
  end

  def test_should_send_auto_reply_when_murmur_text_is_empty
    murmur = create_existing_global_murmur

    MingleConfiguration.overridden_to(ENABLE_EMAIL_REPLIES) do
      reply_data = create_murmur_data({
                                          :murmur_text => '',
                                          :email_client_info => EMAIL_CLIENT_STRING,
                                          :user_id => @bob.id,
                                          :murmur_id => murmur.id,
                                      })

      auto_reply_notifier = mock
      auto_reply_notifier.expects(:send_auto_reply).with(anything, anything, 'murmur_subject', :empty_murmur_error)
      MurmurCreator.new(auto_reply_notifier).create reply_data
    end
  end

  def test_should_send_auto_reply_when_murmur_text_is_empty_but_create_attachments_for_card_murmur
    murmur = create_existing_card_murmur

    MingleConfiguration.overridden_to(ENABLE_EMAIL_REPLIES) do
      attachment_uploader = mock
      attachment_uploader.expects(:execute)

      reply_data = create_murmur_data({
                                          :murmur_text => '',
                                          :email_client_info => EMAIL_CLIENT_STRING,
                                          :user_id => @bob.id,
                                          :murmur_id => murmur.id,
                                          :attachment_uploaders => [attachment_uploader]
                                      })

      auto_reply_notifier = mock
      auto_reply_notifier.expects(:send_auto_reply).with(anything, anything, 'murmur_subject', :empty_murmur_error)
      auto_reply_notifier.expects(:send_auto_reply).with(anything, anything, 'murmur_subject', :attachments_on_empty_murmur)
      MurmurCreator.new(auto_reply_notifier).create reply_data
    end
  end

  def test_should_add_create_card_attachment_via_email_monitoring_event_without_succeeded
    murmur = create_existing_card_murmur

    failing_uploader = mock
    failing_uploader.expects(:execute).raises(StandardError.new('Failing uploader for test'))

    attachment_uploaders = [failing_uploader]

    MingleConfiguration.overridden_to(ENABLE_METRIC_TRACKING_WITH_ATTACHMENTS) do
      reply_data = create_murmur_data({
                                          :murmur_text => 'murmur reply',
                                          :email_client_info => EMAIL_CLIENT_STRING,
                                          :user_id => @bob.id,
                                          :murmur_id => murmur.id,
                                          :attachment_uploaders => attachment_uploaders,
                                      })
      consumer = MessagingTestHelper::SampleConsumer.new
      tracker = EventsTracker.new(consumer)

      MurmurCreator.new.create reply_data
      EventsTracker.run_once(:processor => tracker)

      event_data = JSON.parse(consumer.sent.first[1])['data']
      assert_equal 'create_card_attachment_via_email', event_data['event']
      assert_nil event_data['properties']['succeeded']
      assert_equal 1, event_data['properties']['failed']
      assert_equal @project.name, event_data['properties']['project_name']
    end
  end

  private
  def create_murmur_data(data)
    murmur_data = MurmurData.new(data.merge({
                                             :timestamp => Time.now.to_i,
                                             :from => TMail::Address.parse(data[:user_email] || 'test@email.com'),
                                             :recipient => TMail::Address.parse('murmur-reply@email.com'),
                                             :subject => 'murmur_subject'
                                            }))
    murmur_data.set_firebase_data('MurmurCreatorTest', data[:murmur_id], data[:user_id])
    murmur_data
  end

  def create_existing_card_murmur
    murmur = nil
    @project.with_active_project do |project|
      @member.with_current do
        card = project.cards.create(:name => 'first_card', :card_type_name => 'Card')
        murmur = card.origined_murmurs.create!(:murmur => "hello @#{@bob.login}",
                                               :author => User.current, :project_id => @project.id)
      end
    end
    murmur
  end

  def create_existing_global_murmur
    murmur = nil
    @project.with_active_project do
      murmur = create_murmur(:murmur => "hi @#{@bob.login}", :author => @member)
    end
    murmur
  end
end
