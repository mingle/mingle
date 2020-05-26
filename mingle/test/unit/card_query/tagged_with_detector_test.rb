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

class CardQueryTaggedWithDetectorTest < ActiveSupport::TestCase
  def setup
    @project = card_query_project
    @project.activate
    login_as_member
  end

  def test_tagged_with_returns_empty_in_absence_of_TAGGED_WITH_clause
    assert_equal({ :tagged_with => [], :not_tagged_with => [] }, CardQuery.parse("SELECT name").tags)
  end

  def test_tagged_with_returns_empty_in_absence_of_TAGGED_WITH_clause_in_complex_conditions
    assert_equal({ :tagged_with => [], :not_tagged_with => [] }, CardQuery.parse("status = open AND number > 3").tags)
  end

  def test_tagged_with_tags_returns_specified_tags
    assert_equal({ :tagged_with => ['foo'], :not_tagged_with => [] }, CardQuery.parse("TAGGED WITH 'foo'").tags)
    assert_equal({ :tagged_with => ['foo', 'bar'], :not_tagged_with => [] }, CardQuery.parse("TAGGED WITH 'foo' OR TAGGED WITH 'bar'").tags)
    assert_equal({ :tagged_with => ['foo', 'bar'], :not_tagged_with => [] }, CardQuery.parse("TAGGED WITH 'foo' AND TAGGED WITH 'bar'").tags)
  end

  def test_tagged_with_tags_returns_specified_tags_in_complex_conditions
    assert_equal({ :tagged_with => ['foo'], :not_tagged_with => [] }, CardQuery.parse("TAGGED WITH 'foo' OR status = open").tags)
    assert_equal({ :tagged_with => ['bar'], :not_tagged_with => [] }, CardQuery.parse("status = open AND TAGGED WITH 'bar'").tags)
    assert_equal({ :tagged_with => ['foo', 'bar'], :not_tagged_with => [] }, CardQuery.parse("status = open AND TAGGED WITH 'foo' OR TAGGED WITH 'bar'").tags)
  end

  def test_deduplicates_tagged_with
    assert_equal({ :tagged_with => ['foo'], :not_tagged_with => [] }, CardQuery.parse("TAGGED WITH 'foo' OR TAGGED WITH 'foo'").tags)
    assert_equal({ :tagged_with => ['foo'], :not_tagged_with => [] }, CardQuery.parse("TAGGED WITH 'foo' AND TAGGED WITH 'foo'").tags)
  end

  def test_deduplicates_only_per_set
    assert_equal({ :tagged_with => ['foo'], :not_tagged_with => ['foo'] }, CardQuery.parse("NOT TAGGED WITH 'foo' AND NOT TAGGED WITH 'foo' OR TAGGED WITH 'foo'").tags)
    assert_equal({ :tagged_with => ['foo'], :not_tagged_with => ['foo'] }, CardQuery.parse("NOT (TAGGED WITH 'foo' AND TAGGED WITH 'foo') OR (TAGGED WITH 'foo' OR TAGGED WITH 'foo')").tags)
  end

  def test_deduplicates_not_tagged_with
    assert_equal({ :tagged_with => [], :not_tagged_with => ['foo'] }, CardQuery.parse("NOT TAGGED WITH 'foo' OR NOT TAGGED WITH 'foo'").tags)
    assert_equal({ :tagged_with => [], :not_tagged_with => ['foo'] }, CardQuery.parse("NOT TAGGED WITH 'foo' AND NOT TAGGED WITH 'foo'").tags)
  end

  def test_not_tagged_with_tags_return_specified_tags
    assert_equal({ :tagged_with => [], :not_tagged_with => ['foo'] }, CardQuery.parse("NOT TAGGED WITH 'foo'").tags)
    assert_equal({ :tagged_with => [], :not_tagged_with => ['foo', 'bar'] }, CardQuery.parse("NOT TAGGED WITH 'foo' OR NOT TAGGED WITH 'bar'").tags)
    assert_equal({ :tagged_with => [], :not_tagged_with => ['foo', 'bar'] }, CardQuery.parse("NOT (TAGGED WITH 'foo' AND TAGGED WITH 'bar')").tags)
  end

  def test_combining_tagged_with_and_not_tagged_with
    assert_equal({ :tagged_with => ['bar'], :not_tagged_with => ['foo'] }, CardQuery.parse("NOT TAGGED WITH 'foo' AND TAGGED WITH 'bar'").tags)
    assert_equal({ :tagged_with => ['foo'], :not_tagged_with => ['bar'] }, CardQuery.parse("TAGGED WITH 'foo' OR NOT TAGGED WITH 'bar'").tags)

    assert_equal({ :tagged_with => ['present_1'], :not_tagged_with => ['not_1', 'not_2'] }, CardQuery.parse("NOT TAGGED WITH 'not_1' AND TAGGED WITH 'present_1' OR NOT TAGGED WITH 'not_2'").tags)
    assert_equal({ :tagged_with => ['present_1'], :not_tagged_with => ['not_1', 'not_2'] }, CardQuery.parse("NOT (TAGGED WITH 'not_1' AND TAGGED WITH 'not_2') OR TAGGED WITH 'present_1'").tags)
  end

end
