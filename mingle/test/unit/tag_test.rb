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

class TagTest < ActiveSupport::TestCase
  
  def setup
    @project = first_project
    @project.activate
    @first_card = @project.cards.find_by_number(1)
    login_as_member
  end

  def test_parse_returns_set
    assert_equal ['foo', 'bar'], Tag.parse('foo,bar,foo')
  end
  
  # bug 2529
  def test_parse_tag_should_handle_spaces_as_one_space
    assert_equal ['foo bar'], Tag.parse('foo     bar')
    @first_card.tag_with("foo    bar").save!
    assert_equal ['foo bar'], @first_card.tags.collect(&:name)
  end
  # bug 2529
  def test_should_ignore_case
    @first_card.tag_with("foo").save!
    @first_card.tag_with("Foo").save!
    assert_equal ['foo'], @first_card.tags.collect(&:name)
  end
  
  def test_tags_have_project_scope
    @first_card.tag_with("foo").save!
    assert_nil project_without_cards.tags.find_by_name("foo")
  end

  def test_should_not_create_new_card_version_when_updating_tag_name
    @first_card.tag_with("bar_foo").save!
    version_count_before = @first_card.versions.count
    @project.tags.find_by_name('bar_foo').update_attribute(:name, 'bar_zoo')
    assert_equal version_count_before, @first_card.reload.versions.count
  end
  
  def test_parse_handles_arrays_properly
    assert_equal ['tag 1', 'tag 2'], Tag.parse([' tag 1 ', '', 'tag 2 '])
  end
  
  def test_tag_names_with_spaces_do_not_get_quoted
    assert_equal 'here be space', Tag.new(:name => 'here be space').name
  end
  
  def test_find_by_name
    assert_equal 'first_tag', @project.tags.find_by_name('first_tag').name
    assert_nil @project.tags.find_by_name('non_existant')
  end
  
  def test_should_not_find_tag_with_same_name_from_other_project
    assert_nil project_without_cards.tags.find_by_name('first_tag')
    tag = project_without_cards.tags.find_or_create_by_name('first_tag')
    assert_not_equal tag.id, @project.tags.find_by_name('first_tag').id
  end
  
  def test_lookup_should_reset_deleted_status_of_a_found_deleted_tag
    @first_card.tag_with("forgotten").save!
    tag = @first_card.tags.first
    assert_equal ['forgotten'], @first_card.reload.tags.collect(&:name)
    tag.safe_delete
    
    found_tag = @project.tags.lookup_by_name_case_insensitively("forgotten")
    assert_equal tag.id, found_tag.id
    assert_nil found_tag.deleted_at
  end
  
  def test_find_tagged_with
    another_card = @project.cards.find_by_name('another card')
    another_card.tag_with('a_big_big_tag')
    assert_equal [another_card], @project.cards.find_tagged_with(['a_big_big_tag'])
    assert_equal [@first_card], @project.cards.find_tagged_with(['first_tag'])
    assert_equal @first_card.tags.collect{|t| t.name},@project.cards.find_tagged_with(['first_tag']).first.tags.collect{|t| t.name}
  end
  
  def test_safe_delete_tag
    @first_card.tag_with("rss").save!
    tag = @first_card.reload.tags.find{|tag| tag.name == 'rss'}
    tag.safe_delete
    assert_nil @project.tags.used.find_by_name("rss")
    assert @project.tags.find_by_name("rss")
    assert !@first_card.reload.tags.any?{|tag| tag.name == 'rss'}
    
    pre_delete_card_version = @first_card.versions[@first_card.versions.size-2]
    pre_delete_card_version.taggings.reload
    assert pre_delete_card_version.tags.any?{|tag| tag.name == 'rss'}
  end
  
  def test_should_catch_up_invalid_tag_name_before_update_or_create
    foo = @project.tags.find_or_create_by_name("foo")
    assert !foo.update_attributes(:name => '')
    
    assert !@project.tags.find_or_create_by_name(',').valid?
    assert !@project.tags.find_or_create_by_name('tag,name').valid?
    assert !foo.update_attributes(:name => ',')
    assert !foo.update_attributes(:name => 'tag,name')
  end

  def test_tagged_count
    tag = @project.tags.find_or_create_by_name("foo")
    assert_equal 0, tag.tagged_count_on(Card)
    @first_card.tag_with(tag.name).save!
    assert_equal 1, tag.tagged_count_on(Card)
    @project.pages.find_by_name('First Page').tag_with(tag.name).save!
    assert_equal 1, tag.tagged_count_on(Page)
    assert_equal 2, tag.tagged_count_on(:all)
  end
  
  def test_can_rename_an_ungrouped_tag_to_an_unused_tag_name
    cheetah_tag = @project.tags.find_or_create_by_name("cheetah")    
    assert cheetah_tag.reload.update_attributes({:name => "zebra"})
  end  
  
  def test_cannot_rename_an_ungrouped_tag_to_a_previously_deleted_tag_name
    zebra_tag = @project.tags.find_or_create_by_name("zebra")
    zebra_tag.safe_delete
    cheetah_tag = @project.tags.find_or_create_by_name("cheetah")   
    assert !cheetah_tag.reload.update_attributes({:name => "zebra"})    
  end
  
  # for bug 1240
  def test_should_strip_tag_names
    assert_equal 'foo', Tag.new(:name => ' foo ').name
  end 
  
  def test_empty_tag_name_is_invalid
    tag = @project.tags.create(:name => '')
    assert tag.invalid?
    assert_nil tag.errors.on(:base)
    assert tag.errors.on(:name)
  end
  
  def test_tag_name_with_comma_is_invalid
    tag = @project.tags.create(:name => 'hello,world')
    assert tag.invalid?
    assert_nil tag.errors.on(:base)
    assert tag.errors.on(:name)    
  end
  
  def test_name_uniqueness_should_be_case_insensitive
    tag = @project.tags.create(:name => 'Dupe')
    tag.save!
    dupe_tag = @project.tags.create(:name => 'DuPE')
    assert dupe_tag.invalid?
    assert dupe_tag.errors.on(:name)
  end
  
  def test_name_uniqueness_excludes_tags_marked_as_deleted
    tag = @project.tags.create(:name => 'Dupe')
    tag.save!
    assert tag.destroy
    dupe_tag = @project.tags.create(:name => 'DuPE')
    assert dupe_tag.valid?
  end
  
  def test_has_tag
    card = create_card!(:name => 'card1')
    assert_false card.has_tag?
    card.reload
    assert_false card.has_tag?
    card.tag_with('foo')
    assert card.has_tag?
    card.reload
    assert card.has_tag?
  end
  
  # for bug 1179
  def test_update_name_updates_saved_views
    view = CardListView.find_or_construct(@project, :tagged_with => 'rss')
    view.name = 'RSS Stories'
    view.save!
    @project.reload
    assert_equal ['rss'], view.tagged_with
    tag = @project.tags.find_or_create_by_name('rss')
    tag.update_attribute(:name, 'atom')
    assert_equal ['atom'], @project.card_list_views.find_by_name('RSS Stories').tagged_with
  end
  
  # Bug 7280
  def test_update_name_should_update_history_subscriptions
    tag = @project.tags.find_or_create_by_name('abc')
    @project.tags.find_or_create_by_name('def')
    
    subscription = @project.create_history_subscription(User.current, history_filter_params("acquired_filter_tags=abc,def").serialize)
    tag.update_attribute :name, 'abc new'
    subscription.reload
    subscription = HistorySubscription.find(subscription.id)
    assert_equal ['abc new', 'def'], subscription.acquired_filter_tags
  end
  
  def history_filter_params(filter_params, period=nil)
    HistoryFilterParams.new(filter_params, period)
  end
end
