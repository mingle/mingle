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

class CardVersionArchiveTest < ActiveSupport::TestCase
  def setup
    @project = project_without_cards
    @project.activate
    login_as_member
  end
  
  def test_should_support_changes_generation
    card = create_card!(:name => 'first card') 
    card.cp_iteration = '1'
    card.tag_with('foo')
    card.add_comment(:content => 'hello')
    card.save!
    
    create_event = card.versions.first.event.target
    update_event = card.versions.last.event.target
    
    card.destroy
    
    create_event.reload.send(:generate_changes)
    update_event.reload.send(:generate_changes)
    assert_equal ['CardTypeChange', 'NameChange'], create_event.changes.reload.collect(&:class).collect(&:name).sort
    assert_equal ['CommentChange', 'PropertyChange', 'TagAdditionChange'], update_event.changes.reload.collect(&:class).collect(&:name).sort
  end
end
