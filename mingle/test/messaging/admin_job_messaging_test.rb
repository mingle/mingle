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
class AdminJobMessagingTest < ActionController::TestCase
  include MessagingTestHelper

  def setup
    @controller = create_controller ProjectsController, :own_rescue_action => true
    @request    = ActionController::TestRequest.new
    @response   = ActionController::TestResponse.new
    rescue_action_in_public!
    login_as_admin
  end

  def test_should_create_message_group_for_admin_job_after_requested_regenerate_changes
    with_first_project do |project|
      post :regenerate_changes, :project_id => project.identifier
      assert_response :redirect
      group = MessageGroup.find_by_action(project.id, Project::AdminJobs::REGENERATE_CHANGES_ACTION)
      assert group
    end
  end
  
  def test_should_not_allow_to_request_regenerate_changes_again_when_previous_message_group_is_not_done
    with_first_project do |project|
      post :regenerate_changes, :project_id => project.identifier
      post :regenerate_changes, :project_id => project.identifier
      assert flash[:error]
    end
  end
  
  def test_should_not_find_message_group_after_grouped_messages_all_were_processed
    with_first_project do |project|
      post :regenerate_changes, :project_id => project.identifier
      assert_response :redirect
      HistoryGeneration.run_once
      group = MessageGroup.find_by_action(project.id, Project::AdminJobs::REGENERATE_CHANGES_ACTION)
      assert_nil group
    end
  end

  def test_should_group_sent_messages_when_regenerate_history_changes
    with_first_project do |project|
      project.generate_changes_as_admin
      assert_message_sent_as_group(project, Project::AdminJobs::REGENERATE_CHANGES_ACTION, HistoryGeneration::ProjectChangesGenerationProcessor::QUEUE)
    end
  end
  
  def test_should_group_sent_messages_when_rebuild_card_murmur_links
    with_first_project do |project|
      m = create_murmur(:murmur => "#1 blabla...")
      project.rebuild_card_murmur_links_as_admin
      assert_message_sent_as_group(project, Project::AdminJobs::REBUILD_CARD_MURMUR_LINKS, CardMurmurLinkProcessor::ProjectCardMurmurLinksProcessor::QUEUE)
    end
  end
  
  def test_should_group_sent_messages_when_recompute_aggregates
    create_project.activate do |project|
      tree_configuration = project.tree_configurations.create!(:name => 'Release tree')
      init_three_level_tree(tree_configuration)
      aggregate_prop_def = project.all_property_definitions.create_aggregate_property_definition(:name => 'I am aggregate prop def')

      project.recompute_aggregates_as_admin
      assert_message_sent_as_group(project, Project::AdminJobs::RECOMPUTE_AGGREGATES, AggregateComputation::ProjectsProcessor::QUEUE)
    end
  end
  
  def test_should_mark_destroy_message_group_when_zero_message_sent_for_the_job
    with_first_project do |project|
      project.recompute_aggregates_as_admin
      assert_nil MessageGroup.find_by_action(project.id, Project::AdminJobs::RECOMPUTE_AGGREGATES)
    end
  end

  def assert_message_sent_as_group(project, action, queue)
    assert MessageGroup.find_by_action(project.id, action)
    msg = all_messages_from_queue(queue).first
    group_id = msg.property 'message_group_id'
    assert MessageGroup.find_by_group_id(group_id)
  end
end
