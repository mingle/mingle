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

class CardTypeDetectorTest < ActiveSupport::TestCase
  
  def setup
    @project = card_query_project
    @project.activate
    login_as_member
  end
  
  def test_should_specify_included_types
    assert_equal ['Story'], CardQuery.parse('Type = Story').explicit_card_type_names[:included]
    assert_equal ['Story', 'Bug'], CardQuery.parse('Type = Story OR Type = Bug').explicit_card_type_names[:included]
    assert_equal ['Story', 'Bug'], CardQuery.parse('Type IN (Story, Bug)').explicit_card_type_names[:included]
  end

  def test_should_specify_excluded_types
    assert_equal ['Bug'], CardQuery.parse('Type != Bug').explicit_card_type_names[:excluded]
    assert_equal ['Bug'], CardQuery.parse('NOT (Type = Bug)').explicit_card_type_names[:excluded]
    assert_equal ['Story', 'Bug'].sort, CardQuery.parse('NOT (Type = Bug OR Type = Story)').explicit_card_type_names[:excluded].sort
    assert_equal ['Story', 'Bug'], CardQuery.parse('NOT Type IN (Story, Bug)').explicit_card_type_names[:excluded]
  end

  def test_should_specify_both_included_and_excluded
    assert_equal({ :included => ['Story'], :excluded => ['Bug'] }, CardQuery.parse('Type = Story AND Type != Bug').explicit_card_type_names)
    assert_equal({ :included => ['Story'], :excluded => ['Bug'] }, CardQuery.parse('Type = Story OR NOT (Type = Bug)').explicit_card_type_names)
  end

  def test_deduplicates_only_per_set
    assert_equal({ :included => ['Story'], :excluded => [] }, CardQuery.parse('Type IN (Story, Story)').explicit_card_type_names)
    assert_equal({ :included => [], :excluded => ['Story'] }, CardQuery.parse('NOT (Type IN (Story, Story))').explicit_card_type_names)
    assert_equal({ :included => [], :excluded => ['Story'] }, CardQuery.parse('Type != Story OR Type != Story').explicit_card_type_names)
    assert_equal({ :included => ['Story'], :excluded => ['Story'] }, CardQuery.parse('Type = Story AND NOT (Type = Story)').explicit_card_type_names)
  end

  def test_deduplicates_included_set
    assert_equal({ :included => ['Story'], :excluded => [] }, CardQuery.parse('Type = Story AND Type = Story').explicit_card_type_names)
    assert_equal({ :included => ['Story'], :excluded => [] }, CardQuery.parse('Type = Story OR Type = Story').explicit_card_type_names)
    assert_equal({ :included => ['Story'], :excluded => [] }, CardQuery.parse('NOT (Type != Story) OR NOT (Type != Story)').explicit_card_type_names)
  end

  def test_deduplicates_excluded_set
    assert_equal({ :included => [], :excluded => ['Story'] }, CardQuery.parse('Type != Story AND Type != Story').explicit_card_type_names)
    assert_equal({ :included => [], :excluded => ['Story'] }, CardQuery.parse('Type != Story OR Type != Story').explicit_card_type_names)
    assert_equal({ :included => [], :excluded => ['Story'] }, CardQuery.parse('NOT (Type = Story) OR NOT (Type = Story)').explicit_card_type_names)
  end

  def test_uses_detection_should_be_case_insensitive
    assert CardQuery::CardTypeDetector.new(CardQuery.parse('Type = Story AND Type != Bug')).uses?('bug')
  end
  
end
