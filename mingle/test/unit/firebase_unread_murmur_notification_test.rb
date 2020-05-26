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



class FirebaseUnreadMurmurNotificationTest < ActiveSupport::TestCase

  class ResponseStub
    attr_reader :url
    def initialize(url)
      @url = url
    end

    def success?
      true
    end
  end

  class ClientStub
    attr_reader :data
    def initialize
      @data = {}
    end

    def push(key, val)
      @data[key] ||= []
      @data[key] << val
      ResponseStub.new(key)
    end
  end


  def setup
    @admin = User.find_by_login('admin')
    @bob = User.find_by_login('bob')
    @member = User.find_by_login('member')
    @project = create_project(:users =>[@member, @bob])
    @client = ClientStub.new
    @notification = FirebaseUnreadMurmurNotification.new(@client)
    @project.activate
    login_as_member
  end

  def test_send_unread_to_targeted_user
    murmur_text = "@#{@bob.login} likes murmur"
    murmur = @project.murmurs.create!(:murmur => murmur_text,
                                      :author => @member)
    @notification.deliver_notify([@bob], @project, murmur)
    assert_equal([{'author' => {'name' => @member.name}.to_json, 'card_number' => nil, 'created_at' => murmur.created_at, 'id' => murmur.id, 'text' => murmur_text }], @client.data[FirebaseKeys.unread_murmurs_key(@bob, @project)])
  end

  def test_deliver_should_skip_author
    murmur = @project.murmurs.create!(:murmur => "@#{@bob.login} likes murmur",
                                      :author => @member)
    @notification.deliver_notify([@member], @project, murmur)
    assert_equal 0, @client.data.size
  end

  def test_should_deliver_notification_to_group_members
    murmur_text = "@team likes murmur"
    murmur = @project.murmurs.create!(:murmur => murmur_text,
                                      :author => @admin)

    @notification.deliver_notify([@bob, @member], @project, murmur)
    assert_equal 2, @client.data.size
    firebase_data = [{'author' => {'name' => @admin.name}.to_json,'id' => murmur.id, 'card_number' => nil, 'created_at' => murmur.created_at, 'text' => murmur_text}]
    assert_equal(firebase_data, @client.data[FirebaseKeys.unread_murmurs_key(@bob, @project)])
    assert_equal(firebase_data, @client.data[FirebaseKeys.unread_murmurs_key(@member, @project)])
  end

  def test_push_to_real_firebase
    MingleConfiguration.overridden_to(:firebase_app_url => "https://mingle-test.firebaseio.com",
                                      :firebase_secret => "cLhtT3Rr3Oxj4JXSheSy3uzgWEngZN7V6PNMo2qX",
                                      :app_namespace => 'acme') do

      client = FirebaseClient.new(MingleConfiguration.firebase_app_url, MingleConfiguration.firebase_secret)
      client.delete("/unread_murmurs")

      notification = FirebaseUnreadMurmurNotification.new(client)

      murmur_text = "@#{@bob.login} likes murmur"
      murmur = @project.murmurs.create!(:murmur => murmur_text,
                                        :author => @member)

      notification.deliver_notify([@bob], @project, murmur)

      response = client.get(FirebaseKeys.unread_murmurs_key(@bob, @project)).values

      assert response.first.delete("fbPublishedAt").present?, "should have a firebase timestamp"
      assert_equal [{'author' => {'name' => @member.name}.to_json ,'created_at' => murmur.created_at.strftime("%Y-%m-%dT%H:%M:%SZ"), 'id' => murmur.id, 'text' => murmur_text}], response
    end
  end

end
