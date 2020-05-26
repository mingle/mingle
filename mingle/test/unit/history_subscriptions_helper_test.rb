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

class HistorySubscriptionsHelperTest < ActionView::TestCase
  include HistorySubscriptionsHelper
  
  def setup
    @project = first_project
    @project.activate
  end
  
  def test_filter_properties_and_tags_as_sentence_returns_tags_at_end
    HistorySubscription.with_options(:user => User.first, :project_id => @project.id, :last_max_card_version_id => 1, :last_max_page_version_id => 1, :last_max_revision_id => 1) do |history|
      subscription = history.create :filter_params => { :acquired_filter_properties => { 'Type' => 'Story', 'Priority' => 'low' }, :acquired_filter_tags => "demonworm" }

      actual = filter_properties_and_tags_as_sentence(subscription.project, subscription.acquired_filter_properties, subscription.acquired_filter_tags)
      assert_equal "<div>Priority is #{'low'.bold}</div><div>Type is #{'Story'.bold}</div><div>Tagged with #{'demonworm'.bold}</div>", actual
    end
  end

  def test_filter_properties_and_tags_as_sentence_returns_no_extra_word_AND_when_no_filter_tags_exist
    HistorySubscription.with_options(:user => User.first, :project_id => @project.id, :last_max_card_version_id => 1, :last_max_page_version_id => 1, :last_max_revision_id => 1) do |history|
      subscription = history.create :filter_params => { :acquired_filter_properties => { 'Type' => 'Story', 'Priority' => 'low' } }

      actual = filter_properties_and_tags_as_sentence(subscription.project, subscription.acquired_filter_properties, subscription.acquired_filter_tags)
      assert_equal "<div>Priority is #{'low'.bold}</div><div>Type is #{'Story'.bold}</div>", actual
    end
  end
  
  def test_filter_properties_and_tags_as_sentence_returns_anything_if_nothing_applies
    HistorySubscription.with_options(:user => User.first, :project_id => @project.id, :last_max_card_version_id => 1, :last_max_page_version_id => 1, :last_max_revision_id => 1) do |history|
      subscription = history.create :filter_params => {}

      actual = filter_properties_and_tags_as_sentence(subscription.project, subscription.acquired_filter_properties, subscription.acquired_filter_tags)
      assert_equal '(anything)', actual
    end
  end
  
  def test_filter_properties_and_tags_as_sentence_escapes_properties
    assert_equal "<div>&lt;h3&gt;&quot;iron&quot; mike&lt;/h3&gt; is #{'tyson'.bold}</div>", filter_properties_and_tags_as_sentence(@project, [['<h3>"iron" mike</h3>', 'tyson']], [])
  end
  
  def test_filter_properties_and_tags_as_sentence_escapes_values
    assert_equal "<div>owner is #{h "<h3>\"iron\" mike</h3>".bold}</div>", filter_properties_and_tags_as_sentence(@project, [['owner', '<h3>"iron" mike</h3>']], [])
  end
  
  def test_filter_properties_and_tags_as_sentence_escapes_tags
    assert_equal "<div>Tagged with #{h "<h3>\"iron\" mike</h3>".bold} and #{'tyson'.bold}</div>", filter_properties_and_tags_as_sentence(@project, [], ['<h3>"iron" mike</h3>', 'tyson'])
  end
end
