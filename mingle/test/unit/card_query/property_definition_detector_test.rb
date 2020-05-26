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

class CardQuery::PropertyDefinitionDetectorTest < ActiveSupport::TestCase
  def setup
    @project = create_project
    login_as_member
  end
  
  def test_detect_pd_in_numbers_in_clause
    setup_card_property_definition('related_card', @project.card_types.first)
    assert_equal ['related_card'], detect("related_card numbers in (1, 2)")
    assert_equal ['related_card'], detect("related_card number in (1, 2)")
  end
  
  def test_detect_pd_in_comparision_with_number_clause
    setup_card_property_definition('related_card', @project.card_types.first)
    assert_equal ['related_card'], detect("related_card = number 2")    
  end
  
  def test_detect_this_card_property_usages
    setup_card_property_definition('related_card', @project.card_types.first)
    assert_equal ['Number', 'related_card'], detect("number = THIS CARD.related_card").sort
  end
  
  private
  
  def detect(mql)
    query = CardQuery.parse(mql)
    CardQuery::PropertyDefinitionDetector.new(query).execute.collect(&:name)
  end
  
end
