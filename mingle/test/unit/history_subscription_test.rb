#encoding: UTF-8

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

class HistorySubscriptionTest < ActiveSupport::TestCase
  
  def test_filter_types_returns_whether_cards_pages_or_revisions_are_set_in_filter
    subscription = HistorySubscription.new :filter_params => { 'filter_types' => { 'cards' => 'Card::Version', 'pages' => 'Page::Version', 'revisions' => 'Revision' } }
    assert_equal ['cards', 'pages', 'revisions'], subscription.filter_types
  end
  
  def test_filter_types_display_name_should_return_repository_vocabulary_for_revisions
    with_first_project do |project|
      configuration = add_repository_configuration_to_project(project)
      subscription = project.history_subscriptions.build :filter_params => { 'filter_types' => { 'cards' => 'Card::Version', 'revisions' => 'Revision' } }
      subscription_project = subscription.project
      def subscription_project.repository_vocabulary
        { 'revision' => 'changeset' }
      end
      subscription_project.reload
      assert_equal ['Cards', 'Changesets'], subscription.filter_types_display_names
    end
  end

  def test_filter_types_display_name_should_return_empty_array_when_no_filter_types_exist
    subscription = HistorySubscription.new :filter_params => { 'filter_user' => User.first.id }
    assert_equal [], subscription.filter_types_display_names
  end
  
  def test_filter_types_returns_empty_array_when_no_filter_types_are_set_in_filter
    subscription = HistorySubscription.new :filter_params => {}
    assert_equal [], subscription.filter_types
  end
  
  def test_filter_user_returns_user_that_subscription_is_filtering_by
    subscription = HistorySubscription.new :filter_params => { 'filter_user' => User.first.id }
    assert_equal User.first, subscription.filter_user
  end
  
  def test_filter_user_returns_nil_if_no_filtering_user_in_filter
    subscription = HistorySubscription.new :filter_params => {}
    assert_nil subscription.filter_user
  end
  
  def test_filter_user_returns_nil_if_filter_user_does_not_exist
    subscription = HistorySubscription.new :filter_params => { 'filter_user' => -999 }
    assert_nil subscription.filter_user
  end
  
  def test_involved_filter_properties_returns_smart_sorted_array_of_key_value_pairs
    subscription = HistorySubscription.new :filter_params => { 'involved_filter_properties' => { 'Type' => 'Story', 'Owner' => 'schu' } }
    assert_equal [ ['Owner', 'schu'], ['Type', 'Story'] ], subscription.involved_filter_properties
  end
  
  def test_involved_filter_properties_returns_empty_array_when_no_such_filter_properties_were_in_filter
    subscription = HistorySubscription.new :filter_params => {}
    assert_equal [], subscription.involved_filter_properties
  end

  def test_acquired_filter_properties_returns_smart_sorted_array_of_key_value_pairs
    subscription = HistorySubscription.new :filter_params => { 'acquired_filter_properties' => { 'Type' => 'Story', 'Owner' => 'schu' } }
    assert_equal [ ['Owner', 'schu'], ['Type', 'Story'] ], subscription.acquired_filter_properties
  end
  
  def test_acquired_filter_properties_returns_empty_array_when_no_such_filter_properties_were_in_filter
    subscription = HistorySubscription.new :filter_params => {}
    assert_equal [], subscription.acquired_filter_properties
  end
  
  def test_filter_card_returns_card
    with_first_project do |project|
      subscription = HistorySubscription.new :project => project, :filter_params => { 'card_number' => 1 }
      assert_equal project.cards.find_by_number(1), subscription.filter_card
    end
  end
  
  def test_filter_page_returns_page
    with_first_project do |project|
      page = project.pages.first
      subscription = HistorySubscription.new :project => project, :filter_params => { 'page_identifier' => page.identifier }
      assert_equal page, subscription.filter_page
    end
  end
  
  # bug 7279
  def test_rename_property_renames_serialized_history_filter_params_correctly
    with_new_project do |project|
      setup_text_property_definition('unrelated')
      setup_text_property_definition('abcold')
      setup_text_property_definition('abcnew')
      setup_text_property_definition('abc - new')
      setup_text_property_definition('abc - old')
      
      HistorySubscription.with_options :project => project, :user_id => User.current, :last_max_card_version_id => 1, :last_max_page_version_id => 1, :last_max_revision_id => 1 do |history_subscription|
        subscription = history_subscription.create! :filter_params => HistoryFilterParams.new(:acquired_filter_properties => { 'unrelated' => '' }).to_hash
        subscription.rename_property('abcnew', 'abcold') and subscription.save!
        assert_equal 'acquired_filter_properties[unrelated]=', subscription.reload.filter_params
      
        subscription = history_subscription.create! :filter_params => HistoryFilterParams.new(:involved_filter_properties => { 'abcold' => 'foo' }).to_hash
        subscription.rename_property('abcold', 'abcnew') and subscription.save!
        assert_equal 'involved_filter_properties[abcnew]=foo', subscription.reload.filter_params
        
        
        subscription = history_subscription.create! :filter_params => HistoryFilterParams.new(:involved_filter_properties => { 'abc - new' => 'foo' }).to_hash
        subscription.rename_property('abc - new', 'abc - old') and subscription.save!
        assert_equal 'involved_filter_properties[abc+-+old]=foo', subscription.reload.filter_params
        
        subscription = history_subscription.create! :filter_params => HistoryFilterParams.new(:involved_filter_properties => { 'abc - new' => 'foo bar' }).to_hash
        subscription.rename_property('abc - new', 'abc - old') and subscription.save!
        assert_equal 'involved_filter_properties[abc+-+old]=foo+bar', subscription.reload.filter_params
        
      end
    end
  end
  
  # Bug 7280
  def test_rename_tag_should_rename_saved_involved_filter_tags
    with_new_project do |project|
      subscription = HistorySubscription.new :filter_params => { 'involved_filter_tags' => %w{apple} }
      subscription.rename_tag('apple', 'orange')
      assert_equal %w{orange}, subscription.involved_filter_tags
    end
  end
  
  # Bug 7280
  def test_rename_tag_should_rename_saved_acquired_filter_tags
    with_new_project do |project|
      subscription = HistorySubscription.new :filter_params => { 'acquired_filter_tags' => %w{apple} }
      subscription.rename_tag('apple', 'orange')
      assert_equal %w{orange}, subscription.acquired_filter_tags
    end
  end
  
  # Bug 7386
  def test_should_delete_history_subscription_when_filter_user_is_removed_from_project
    admin = login_as_admin
    with_new_project do |project|
      project.add_member bob = User.find_by_login('bob')
      project.create_history_subscription admin, HistoryFilterParams.new('filter_user' => bob.id).to_hash
      assert_equal 1, project.history_subscriptions.size
      project.remove_member bob
      assert_equal 0, project.reload.history_subscriptions.size
    end
  end
  
  # Bug 7386
  def test_should_not_delete_history_subscription_when_filter_user_does_not_match_user_removed_from_project
    admin = login_as_admin
    with_new_project do |project|
      project.add_member bob = User.find_by_login('bob')
      project.add_member long_bob = User.find_by_login('longbob')
      project.create_history_subscription admin, HistoryFilterParams.new('filter_user' => bob.id).to_hash
      assert_equal 1, project.history_subscriptions.size
      project.remove_member long_bob
      assert_equal 1, project.reload.history_subscriptions.size
    end
  end
  
  # Bug 7386
  def test_should_delete_history_subscription_when_involed_filter_user_is_removed_from_project
    admin = login_as_admin
    with_new_project do |project|
      project.add_member bob = User.find_by_login('bob')
      owner = setup_user_definition 'owner'
      project.create_history_subscription admin, HistoryFilterParams.new('involved_filter_properties' => { 'owner' => bob.id }).to_hash
      assert_equal 1, project.history_subscriptions.size
      project.remove_member bob
      assert_equal 0, project.reload.history_subscriptions.size
    end
  end
  
  # Bug 7386
  def test_should_not_delete_history_subscription_when_involved_filter_user_does_not_match_user_removed_from_project
    admin = login_as_admin
    with_new_project do |project|
      project.add_member bob = User.find_by_login('bob')
      project.add_member long_bob = User.find_by_login('longbob')
      owner = setup_user_definition 'owner'
      project.create_history_subscription admin, HistoryFilterParams.new('involved_filter_properties' => { 'owner' => bob.id }).to_hash
      assert_equal 1, project.history_subscriptions.size
      project.remove_member long_bob
      assert_equal 1, project.reload.history_subscriptions.size
    end
  end
  
  # Bug 7386
  def test_should_delete_history_subscription_when_acquired_filter_user_is_removed_from_project
    admin = login_as_admin
    with_new_project do |project|
      project.add_member bob = User.find_by_login('bob')
      owner = setup_user_definition 'owner'
      project.create_history_subscription admin, HistoryFilterParams.new('acquired_filter_properties' => { 'owner' => bob.id }).to_hash
      assert_equal 1, project.history_subscriptions.size
      project.remove_member bob
      assert_equal 0, project.reload.history_subscriptions.size
    end
  end
  
  # Bug 7386
  def test_should_not_delete_history_subscription_when_acquired_filter_user_does_not_match_user_removed_from_project
    admin = login_as_admin
    with_new_project do |project|
      project.add_member bob = User.find_by_login('bob')
      project.add_member long_bob = User.find_by_login('longbob')
      owner = setup_user_definition 'owner'
      project.create_history_subscription admin, HistoryFilterParams.new('acquired_filter_properties' => { 'owner' => bob.id }).to_hash
      assert_equal 1, project.history_subscriptions.size
      project.remove_member long_bob
      assert_equal 1, project.reload.history_subscriptions.size
    end
  end
  
  # Bug 7386
  def test_should_delete_history_subscription_when_user_that_created_subscription_is_removed_from_project
    with_new_project do |project|
      setup_allow_any_text_property_definition 'some_property'
      project.add_member bob = User.find_by_login('bob')
      project.create_history_subscription bob, HistoryFilterParams.new('some_property' => 'some_value').to_hash
      assert_equal 1, project.history_subscriptions.size
      project.remove_member bob
      assert_equal 0, project.reload.history_subscriptions.size
    end
  end
  
  # Bug 7386
  def test_should_not_delete_history_subscription_when_user_that_created_subscription_does_not_match_user_removed_from_project
    with_new_project do |project|
      setup_allow_any_text_property_definition 'some_property'
      project.add_member bob = User.find_by_login('bob')
      project.add_member long_bob = User.find_by_login('longbob')
      project.create_history_subscription bob, HistoryFilterParams.new('some_property' => 'some_value').to_hash
      assert_equal 1, project.history_subscriptions.size
      project.remove_member long_bob
      assert_equal 1, project.reload.history_subscriptions.size
    end
  end
  
  # Bug 7386
  def test_should_not_delete_history_subscription_when_user_that_created_subscription_is_removed_from_project_but_user_is_mingle_admin
    admin = login_as_admin
    with_new_project do |project|
      setup_allow_any_text_property_definition 'some_property'
      project.create_history_subscription admin, HistoryFilterParams.new('some_property' => 'some_value').to_hash
      assert_equal 1, project.history_subscriptions.size
      project.add_member admin
      project.remove_member admin
      assert_equal 1, project.reload.history_subscriptions.size
    end
  end
  
  def test_should_expose_iterable_filters
    with_first_project do |project|
      subscription = project.history_subscriptions.new :filter_params => { 'involved_filter_properties' => { 'dev' => 'schu' } }
      subscription.filters.each do |filter|
        assert_equal 'dev', filter.property_definition.name
        assert_equal 'schu', filter.value
      end
    end
  end

  def test_should_store_and_retrieve_unicode_filter_params
    admin = login_as_admin
    with_first_project do |project|
      project.pages.create!(:identifier => "ééuipe_ccmd", :name => "équipe ccmd")
      filter_params = { 'page_identifier' => "ééuipe_ccmd" }
      subscription = project.create_history_subscription admin, HistoryFilterParams.new(filter_params).to_hash
      assert_equal(filter_params, subscription.reload.filter_params)
      subscription.save
      assert_equal(filter_params, subscription.reload.filter_params)
    end
  end

  def test_should_store_backslash_as_escaping_char_for_filter_params
    admin = login_as_admin
    with_first_project do |project|
      project.pages.create!(:identifier => "\\", :name => "\\")
      filter_params = { 'page_identifier' => "\\" }
      subscription = project.create_history_subscription admin, HistoryFilterParams.new(filter_params).to_hash
      assert_equal(filter_params, subscription.reload.filter_params)
      subscription.save
      assert_equal(filter_params, subscription.reload.filter_params)
    end
  end
  
  protected
  
  def add_repository_configuration_to_project(project)
    config = SubversionConfiguration.create!(:project_id => project.id, :username => 'foousername',
      :password => 'foopassword',  :repository_path => 'foorepository_path',  :card_revision_links_invalid => false,
      :initialized => false, :marked_for_deletion => false)

    config.username = 'barusername'
    config.password = 'barpassword'
    config.repository_path = 'barrepository_path'
    config.initialized = true
    config.marked_for_deletion = true
    project.reload
    config
  end

end
