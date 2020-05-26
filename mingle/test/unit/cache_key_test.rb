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

class CacheKeyTest < ActiveSupport::TestCase
  
  def setup
    login_as_admin
  end
  
  def test_should_update_key_when_project_updated
    with_new_project do |project|
      assert_project_structure_key_changed do
        project.update_attribute(:name, 'new name')
      end
    end
  end
  
  def test_touch_structure_key_should_leave_key_nondirty
    with_new_project do |project|
      cache_keys = CacheKey.find(:all, :conditions => {:deliverable_id => project.id, :deliverable_type => Deliverable::DELIVERABLE_TYPE_PROJECT})
      cache_keys.first.touch_structure_key
      assert_false cache_keys.first.structure_key_changed?
    end
  end
  
  def test_touch_structure_key_should_set_updated_at_correctly
    with_new_project do |project|
      cache_keys = CacheKey.find(:all, :conditions => {:deliverable_id => project.id, :deliverable_type => Deliverable::DELIVERABLE_TYPE_PROJECT})
      cache_key = cache_keys.first
      existing_updated_at = cache_key.updated_at
      cache_key.touch_structure_key
      assert cache_key.updated_at > existing_updated_at
    end
  end

  def test_should_destroy_key_when_project_is_deleted
    with_new_project do |project|
      project.destroy
      assert CacheKey.find(:all, :conditions => {:deliverable_id => project.id, :deliverable_type => Deliverable::DELIVERABLE_TYPE_PROJECT}).empty?
    end
  end
  
  def test_should_change_key_after_added_property_definition
    with_new_project do |project|
      assert_project_structure_key_changed do
        project.create_text_list_definition!(:name => "story status")
      end
    end
  end
  
  def test_should_change_key_after_updated_property_definition
    with_new_project do |project|
      property = project.create_text_list_definition!(:name => "story status")
      assert_project_structure_key_changed do
        property.update_attribute :name, 'story_status'
      end
    end
  end

  def test_should_change_key_after_destroyed_property_definition
    with_new_project do |project|
      property = project.create_text_list_definition!(:name => "story status")
      assert_project_structure_key_changed do
        property.destroy
      end
    end
  end

  def test_should_change_key_after_deleted_a_tag
    with_first_project do |project|
      tag = project.tags.find_by_name('first_tag')
      assert_project_structure_key_changed do
        tag.destroy
      end
    end
  end
  
  def test_should_create_structure_key_on_access
    project = create_project
    assert project.cache_key.structure_key
  end
  
  def test_should_create_card_key_on_access
    project = create_project
    assert project.cache_key.card_key
  end
  
  def test_should_change_feeds_key_when_correction_event_happened
    with_new_project do |project|
      property = project.create_text_list_definition!(:name => "story status")
      assert_feed_key_changed { property.update_attribute(:name, 'new name') }
      assert_feed_key_changed { project.update_attribute(:precision, 3) }
      assert_feed_key_changed { project.update_attribute(:card_keywords, 'WpcLeftMeAlone') }
      assert_feed_key_changed { CorrectionEvent.create_for_repository_settings_change(project) }
    end
  end
  
  def test_should_not_change_feed_key_on_event_that_is_not_correction_event
    with_new_project do |project|
      assert_feed_key_not_changed { project.create_text_list_definition!(:name => "story status") }
      assert_feed_key_not_changed { create_card!(:name => 'hello') }
    end
  end
  
  def test_should_change_feeds_key_when_user_name_changed
    bob = User.find_by_login('bob')
    with_first_project do |project|
      assert_feed_key_changed { bob.update_attribute(:name, 'newbob') }
    end
  end
  
  def test_should_change_feeds_key_when_user_email_changed
    bob = User.find_by_login('bob')
    with_first_project do |project|
      assert_feed_key_changed { bob.update_attribute(:email, 'newmail@gmail.com') }
    end
  end

  def test_should_change_feeds_key_when_version_control_user_name_changed
    bob = User.find_by_login('bob')
    with_first_project do |project|
      assert_feed_key_changed { bob.update_attribute(:version_control_user_name, 'iamnobody') }
    end
  end

  def test_should_change_feeds_key_when_user_icon_changed
    bob = User.find_by_login('bob')
    with_first_project do |project|
      assert_feed_key_changed { bob.update_attributes(:icon => sample_attachment("user_icon.png")) }
    end
  end

  def test_should_not_change_feeds_key_when_user_login_changed
    bob = User.find_by_login('bob')
    with_first_project do |project|
      assert_feed_key_not_changed { bob.update_attribute(:login, 'newbob') }
    end
  end

  def assert_project_structure_key_changed
    ThreadLocalCache.clear!
    key = Project.current.cache_key.structure_key
    yield
    assert_not_equal key, Project.current.cache_key.structure_key, "project structure key, #{key.inspect}, should be different"
  end

  def assert_feed_key_changed
    ThreadLocalCache.clear!
    old_key = Project.current.cache_key.feed_key
    yield
    assert_not_equal old_key, Project.current.reload.cache_key.feed_key, "feed key changed"
  end

  def assert_feed_key_not_changed
    ThreadLocalCache.clear!
    old_key = Project.current.cache_key.feed_key
    yield
    assert_equal old_key, Project.current.reload.cache_key.feed_key, "feed key changed"
  end
end
