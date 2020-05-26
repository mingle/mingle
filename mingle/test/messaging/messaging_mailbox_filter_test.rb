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

class MessagingMailboxFilterTest < ActionController::TestCase
  include MessagingTestHelper
  
  def setup
    @controller = create_controller CardsController
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
  end
  
  def test_should_deliver_messages_after_responed
    with_first_project do |project|
      login_as_member
      with_mailbox_enabled do
        post :create, {:project_id => project.identifier, :card => {:name => 'my new card', :card_type => project.card_types.first}}
        assert_redirected_to :action => 'list'
        assert all_messages_from_queue(::FullTextSearch::IndexingCardsProcessor::QUEUE).size > 0
      end
    end
  end
end
