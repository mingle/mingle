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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

class PropertyValueDetectorTest < ActiveSupport::TestCase

  def setup
    @project = card_query_project
    @project.activate
    login_as_member
  end
  
  def test_should_get_correct_usage_from_mql_and_or_condition
    release = @project.find_property_definition('release')
    detector = CardQuery::PropertyValueDetector.new(CardQuery.parse('release = 1 OR release = 2'))
    assert_equal [release.property_value_from_db(1), release.property_value_from_db(2)], detector.execute
  end
  
  def test_should_detect_user_properties
    member = User.find_by_login('member')
    release = @project.find_property_definition('tester')
    detector = CardQuery::PropertyValueDetector.new(CardQuery.parse('tester = member'))
    assert_equal [release.property_value_from_db(member.id)], detector.execute
  end
  
  def test_should_get_correct_usage_from_mql_using_an_and_condition
    release = @project.find_property_definition('release')
    detector = CardQuery::PropertyValueDetector.new(CardQuery.parse('release = 1 AND release = 2'))
    assert_equal [release.property_value_from_db(1), release.property_value_from_db(2)], detector.execute
  end
  
  def test_should_get_correct_usage_from_negated_mql_condition
    release = @project.find_property_definition('release')
    detector = CardQuery::PropertyValueDetector.new(CardQuery.parse('release != 1'))
    assert_equal [release.property_value_from_db(1)], detector.execute
  end

  def test_should_get_correct_usage_from_in_clause
    release = @project.find_property_definition('release')
    detector = CardQuery::PropertyValueDetector.new(CardQuery.parse('release IN (1,2)'))
    assert_equal [release.property_value_from_db(1), release.property_value_from_db(2)], detector.execute
  end
  
  def test_should_associate_properties_with_values
    release = @project.find_property_definition('release')
    detector = CardQuery::PropertyValueDetector.new(CardQuery.parse('release IN (1,2)'))
    assert_equal ({release => [release.property_value_from_db(1), release.property_value_from_db(2)]}), detector.property_definitions_with_values
  end
  
  # bug 13124
  def test_should_ignore_card_relationship_values
    with_new_project do |project|
      property_definition = project.create_card_relationship_property_definition!(:name => 'Papa Card')
      project.card_types.first.add_property_definition property_definition
      property_definition.save!
      detector = CardQuery::PropertyValueDetector.new(CardQuery.parse("'Papa Card' = Something"))
      assert_equal 0, detector.property_definitions_with_values.size
    end
  end
  
end
