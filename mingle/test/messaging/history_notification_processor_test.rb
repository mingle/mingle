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

# Tags: messaging, adminjob, messagegroup
class HistoryNotificationTest < ActionController::TestCase
  include HistoryMailerTestHellper
  include MessagingTestHelper

  def setup
    setup_mailer_project
  end

  def test_history_notification_processor_processing_message
    page = @project.pages.create!(:name => 'some page')
    subscription = @project.create_history_subscription(@member, HistoryFilterParams.new(:page_identifier => page.identifier).serialize)
    page.tag_with('panda, koala')
    page.save!
    HistoryGeneration.run_once

    ActionMailer::Base.deliveries.clear
    HistoryNotificationProcessor.run_once

    assert ActionMailer::Base.deliveries.first
  end
end
