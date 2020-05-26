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

class CardMurmurLinkTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  
  def setup
    @project = first_project
    @project.activate
    login_as_member
    @card = @project.cards.first
    @murmur = create_murmur

  end
  
  def test_link_murmur_and_card_together
    CardMurmurLink.create!(:project => @project,:card => @card, :murmur => @murmur)
    assert_equal [@murmur], @card.reload.murmurs
  end
  
  def test_should_not_allow_create_duplicate_links
    CardMurmurLink.create!(:project => @project, :card => @card, :murmur => @murmur)
    again = CardMurmurLink.create(:project => @project, :card => @card, :murmur => @murmur)
    assert again.errors.any?
  end
end
