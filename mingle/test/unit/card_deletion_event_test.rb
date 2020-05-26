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


class CardDeletionEventTest < ActiveSupport::TestCase
  def setup
    @project = project_without_cards
    @project.activate
    login_as_member
  end
  
  def test_action_description_should_always_be_deleted
    card = create_card!(:name => 'a card')
    card.destroy
    
    assert_equal 'deleted', last_version(card).event.action_description
  end
  
  def test_should_generate_card_deletion_changes
    card = create_card!(:name => 'a card')
    card.destroy
    deletion_event = last_version(card).event
    deletion_event.send :generate_changes
    
    assert_equal [CardDeletionChange], deletion_event.changes.reload.collect(&:class)
    assert deletion_event.history_generated?
  end
  
  def last_version(card)
    card.versions.find(:first, :order => 'version DESC')
  end
end
