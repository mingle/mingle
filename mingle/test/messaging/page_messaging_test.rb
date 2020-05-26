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

class PageMessagingTest < ActiveSupport::TestCase
  include MessagingTestHelper

  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def test_diff_should_show_the_attachments_change
    page = @project.pages.create(:name => "page five for attachments")
    page.attach_files(sample_attachment("1.gif"))
    page.save!
    HistoryGeneration.run_once
    assert page.reload.versions.last.describe_changes.include?("Attachment added 1.gif")
    page.attach_files(sample_attachment("2.gif"))
    page.save!
    HistoryGeneration.run_once
    assert page.reload.versions.last.describe_changes.include?("Attachment added 2.gif")
  end

  def test_should_show_history_when_delete_attachments_from_pages
    page = @project.pages.create!(:name => "card for testing attachment version")
    page.attach_files(sample_attachment)
    page.save!
    page.remove_attachment(page.attachments.first.file_name)
    page.save!
    HistoryGeneration.run_once
    assert_equal 'Attachment removed sample_attachment.txt', page.find_version(3).describe_changes.first
  end

  def test_content_change_does_not_provide_to_and_from_values
    page = @project.pages.create(:name => 'first name', :content => "v1")
    page.update_attributes(:content => "v2")
    HistoryGeneration.run_once
    assert_equal "Content changed", page.reload.versions[1].changes.first.describe
  end

  def test_diff_against_nil_version_returns_tags
    page = @project.pages.new(:name => 'first name', :content => "")
    page.tag_with('hey,boy').save!
    HistoryGeneration.run_once
    assert ['hey', 'boy'].contains_all?(page.reload.versions[0].tag_additions.collect(&:name))
  end

  def test_diff_against_nil_version_empty_if_no_tags
    page = @project.pages.create(:name => 'first name')
    HistoryGeneration.run_once
    assert_equal 1, page.reload.versions[0].changes.size
  end

  def test_diff_includes_content_change
    page = @project.pages.create(:name => 'first name', :content => 'original contents')
    page.update_attributes(:content => 'modified contents')
    HistoryGeneration.run_once
    assert_change({:Content => [nil, nil]}, page.reload.versions[1].changes)
  end

  def test_diff_includes_new_tags
    page = @project.pages.new(:name => 'first name', :content => "")
    page.tag_with('foo').save!
    page.tag_with('open,hey').save!
    HistoryGeneration.run_once
    assert(['open', 'hey'].contains_all?(page.reload.versions[1].tag_additions.collect(&:name)))
    assert(['foo'].contains_all?(page.reload.versions[1].tag_deletions.collect(&:name)))
  end

  def test_diff_includes_removed_tags
    page = @project.pages.new(:name => 'first name', :content => "")
    page.tag_with('open,2, hey').save!
    page.tag_with('bar').save!
    versions = page.reload.versions
    HistoryGeneration.run_once
    assert_equal 4, versions[0].changes.size
    assert_equal 4, versions[1].changes.size
    assert_not_nil versions[0].changes.detect { |change| change.matches?(:field => 'Name', :new_value => 'first name') }
    assert versions[0].tag_additions.collect(&:name).contains_all?(['2', 'hey', 'open'])
    assert versions[1].tag_deletions.collect(&:name).contains_all?(['2', 'hey', 'open'])
    assert versions[1].tag_additions.collect(&:name).contains_all?(['bar'])
  end

  def assert_change(expected_changes, actual_changes)
    assert_equal expected_changes.size, actual_changes.size
    actual_changes.each do |change|
      assert(expected_changes.any? do |field_name, values|
        change.field == field_name.to_s and [change.old_value, change.new_value] == values
      end)
    end
  end

end
