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

# Tags: messaging
class CardMurmurLinkProcessorTest < ActiveSupport::TestCase
  include MessagingTestHelper

  def setup
    login_as_member
    @project = create_project
    @project.activate
  end

  def test_on_message_should_create_murmur_card_links
    @project.cards.create!(:number => 6, :name => 'card one', :card_type_name => 'Card')
    @project.cards.create!(:number => 7, :name => 'card two', :card_type_name => 'Card')

    murmur = Murmur.create!(:murmur => 'Jay likes track #6 and #7 the best', :project_id => @project.id, :packet_id => '12345abc'.uniquify, :author => User.current)
    CardMurmurLinkProcessor::CardMurmurLinkProcessor.run_once

    murmur_card_links = CardMurmurLink.find_all_by_project_id_and_murmur_id(@project.id, murmur.id)
    assert_equal 2, murmur_card_links.size

    cards = murmur_card_links.map(&:card)
    assert_equal [6, 7].sort, cards.map(&:number).sort
  end

  def test_should_not_create_duplicate_links_with_duplicate_message
    card = @project.cards.create!(:number => 6, :name => 'card one', :card_type_name => 'Card')
    murmur = create_murmur(:murmur => "murmur for card #6")
    5.times do
      CardMurmurLinkProcessor::ProjectCardMurmurLinksProcessor.request_rebuild_links(@project)
      CardMurmurLinkProcessor::ProjectCardMurmurLinksProcessor.run_once
    end
    CardMurmurLinkProcessor::CardMurmurLinkProcessor.run_once
    assert_equal 1, CardMurmurLink.find_all_by_project_id_and_murmur_id_and_card_id(@project.id, murmur.id, card.id).size
  end

  def test_on_message_should_ignore_non_existing_projects
    project = create_project
    murmur = nil
    project.with_active_project do |project|
      murmur = Murmur.create!(:murmur => 'Money for nothing', :project_id => project.id, :packet_id => '12345abc'.uniquify, :author => User.current)
    end

    project.destroy
    CardMurmurLinkProcessor.run_once
    assert_nil CardMurmurLink.find_by_project_id_and_murmur_id(project.id, murmur.id)
  end

  def test_on_message_should_ignore_non_existing_murmurs
    murmur = create_murmur(:murmur => "murmur for card #6")
    murmur.destroy
    CardMurmurLinkProcessor.run_once
    assert_nil CardMurmurLink.find_by_project_id_and_murmur_id(@project.id, murmur.id)
  end

  def test_message_with_no_card_numbers_should_not_result_in_creation_of_link
    murmur = Murmur.create!(:murmur => 'Jay likes tracks six and seven the best', :project_id => @project.id, :packet_id => '12345abc'.uniquify, :author => User.current)
    CardMurmurLinkProcessor.run_once
    murmur_card_links = CardMurmurLink.find_all_by_project_id_and_murmur_id(@project.id, murmur.id)
    assert murmur_card_links.empty?
  end

  def test_rebuild_project_card_murmur_should_send_message_for_all_murmur
    m1 = create_murmur(:murmur => "murmur 1")
    m2 = create_murmur(:murmur => "murmur 2")
    get_all_messages_in_queue(CardMurmurLinkProcessor::CardMurmurLinkProcessor::QUEUE)
    CardMurmurLinkProcessor::ProjectCardMurmurLinksProcessor.request_rebuild_links(@project)
    CardMurmurLinkProcessor::ProjectCardMurmurLinksProcessor.run_once
    assert_sort_equal [m1.id, m2.id], get_all_messages_in_queue(CardMurmurLinkProcessor::CardMurmurLinkProcessor::QUEUE).collect { |m| m.property(:murmurId).to_i }
  end

  def test_rebuild_project_card_murmur_when_project_is_not_exist
    project = create_project
    CardMurmurLinkProcessor::ProjectCardMurmurLinksProcessor.request_rebuild_links(project)
    project.destroy
    CardMurmurLinkProcessor::ProjectCardMurmurLinksProcessor.run_once
    assert_equal [], get_all_messages_in_queue(CardMurmurLinkProcessor::CardMurmurLinkProcessor::QUEUE)
  end

  def test_do_not_create_card_murmur_link_to_origin_card_for_card_comment_murmurs
    card = create_card!(:number => 7, :name => 'card seven', :card_type_name => 'Card')
    card.add_comment :content => "#7 is great"
    murmur = find_murmur_from(card)
    CardMurmurLinkProcessor.run_once
    murmur_card_links = CardMurmurLink.find_all_by_project_id_and_murmur_id(@project.id, murmur.id)
    assert_equal 0, murmur_card_links.size
  end

  def test_card_comment_murmur_should_create_links_for_cards_which_arent_origin_card
    create_card!(:number => 6, :name => 'card six', :card_type_name => 'Card')
    card = create_card!(:number => 7, :name => 'card seven', :card_type_name => 'Card')
    card.add_comment :content => "#6 is great"
    murmur = find_murmur_from(card)
    CardMurmurLinkProcessor.run_once
    murmur_card_links = CardMurmurLink.find_all_by_project_id_and_murmur_id(@project.id, murmur.id)
    assert_equal 1, murmur_card_links.size
  end
end
