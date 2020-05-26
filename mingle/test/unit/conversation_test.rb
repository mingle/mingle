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

class ConversationTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def test_conversation_murmurs_are_loaded_in_oldest_first_order
    conversation = @project.conversations.create
    conversation.murmurs.create(:murmur => 'first', :project_id => @project.id)
    conversation.murmurs.create(:murmur => 'reply', :project_id => @project.id)
    conversation.save!
    assert_equal ['first', 'reply'], conversation.murmurs.map(&:murmur)
  end

  def test_validates_presence_of_project_id
    assert_false Conversation.new.valid?
    assert Conversation.new(:project_id => @project.id)
  end

end
