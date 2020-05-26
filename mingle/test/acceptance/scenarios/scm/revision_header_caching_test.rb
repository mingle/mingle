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

require File.expand_path(File.dirname(__FILE__) + '/../../../unit_test_helper')

class RevisionsHeaderCachingTest < ActiveSupport::TestCase

  does_not_work_without_subversion_bindings

  def setup
    @driver_one = with_cached_repository_driver(name + '_setup_1') do |driver|
      driver.create
      driver.import("#{Rails.root}/test/data/test_repository")
      driver.checkout
      driver.add_file('new_file_1.txt', 'some content for project one')
      driver.commit 'added new_file_1.txt for #1 and #4'
    end

    @driver_two = with_cached_repository_driver(name + '_setup_2') do |driver|
      driver.create
      driver.import("#{Rails.root}/test/data/test_repository")
      driver.checkout
      driver.add_file('new_file_2.txt', 'some content for project two')
      driver.commit 'added new_file_2.txt for #2 and #3'
    end

    login_as_admin
  end

  def teardown
    cleanup_repository_drivers_on_failure
  end

  def test_should_link_card_when_there_is_card_keyword_included_in_commit_message
    with_new_project do |project|
      first_card = project.cards.create!(:number => 1, :name => 'first card', :description => 'this is the first card', :card_type => project.card_types.first)

      config = new_repos_config(project, :repository_path => @driver_one.repos_dir)
      project.cache_revisions
      assert_equal Revision.find_by_project_id_and_number(project.id, '2'), project.cards.find_by_number(1).revisions.find_by_number(2)
    end
  end

  def test_should_store_commit_time_as_utc_when_cache_revisions
    with_new_project do |project|
      driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
      end
      config = new_repos_config(project, :repository_path => driver.repos_dir)
      project.cache_revisions
      first_revision = project.reload.revisions.first
      assert first_revision.commit_time.gmt?
    end
  end

  def test_should_create_one_revision_from_one_subversion_revision
    with_new_project do |project|
      driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
      end
      config = new_repos_config(project, :repository_path => driver.repos_dir)
      project.cache_revisions
      assert_equal 1, project.reload.revisions.size
      assert_equal project.id, project.revisions.first.project_id
    end
  end

  def test_cache_revisions_rebuilds_revision_cache_if_repository_not_initialized
    with_new_project do |project|
      driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
      end
      config = new_repos_config(project, :repository_path => driver.repos_dir)
      project.cache_revisions
      original_revision_id = project.reload.revisions.first.id
      config.update_attribute(:initialized, false)
      project.reload.cache_revisions
      assert_not_equal original_revision_id, project.reload.revisions.first.id
      assert project.reload.source_repository_initialized?
    end
  end

  def test_cache_revisions_caches_at_max_as_many_revisions_as_batch_size
    with_new_project do |project|
      driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
        driver.add_file('new_file_1.txt', 'some content')
        driver.commit "add 2nd file"
        driver.add_file('new_file_2.txt', 'some content')
        driver.commit "add 3rd file"
      end
      config = new_repos_config(project, :repository_path => driver.repos_dir)
      assert_nil project.youngest_revision
      batch_size = 2
      project.cache_revisions(batch_size)
      assert_equal batch_size, project.reload.youngest_revision.number
    end
  end

  def test_cache_revisions_handles_no_new_revisions
    with_new_project do |project|
      driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
      end
      config = new_repos_config(project, :repository_path => driver.repos_dir)
      project.cache_revisions
      assert_equal 1, project.reload.revisions.size
      project.cache_revisions
      assert_equal 1, project.reload.revisions.size
    end
  end

  def test_cache_revisions_rebuilds_card_links_if_card_links_invalid
    with_new_project do |project|
      project.cards.create!(:number => 100, :name => 'first card', :card_type_name => 'card')

      repos_driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
        driver.add_file('new_file_1.txt', 'some content')
        driver.commit "play #100"
        driver.add_file('nw_file_2.txt', 'some content')
        driver.commit "for story 100"
        driver.add_file('new_file_3.txt', 'some content')
        driver.commit "for requirement 100"
      end
      config = new_repos_config(project, :repository_path => repos_driver.repos_dir)
      project.cache_revisions

      card_100_revisions = project.reload.cards.find_by_number(100).revisions
      assert_equal 1, card_100_revisions.size
      assert_equal 'play #100', card_100_revisions[0].commit_message

      project.card_keywords = "story, requirement"
      project.save!
      project.cache_revisions

      card_100_revisions = project.cards.find_by_number(100).revisions
      assert_equal 2, card_100_revisions.size
      assert_equal ['for requirement 100', 'for story 100'], card_100_revisions.collect(&:commit_message).sort

      assert !config.reload.card_revision_links_invalid
    end
  end

  def test_cache_revisions_keeps_existing_revisions_and_card_links_when_unable_to_connect_to_previously_valid_repository
    with_new_project do |project|
      project.cards.create!(:number => 100, :card_type => project.card_types.first, :name => 'boo')

      repos_driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
        driver.add_file('new_file_1.txt', 'some content')
        driver.commit "play #100"
      end
      config = new_repos_config(project, :repository_path => repos_driver.repos_dir)
      project.cache_revisions

      config.reload.update_attributes(:repository_path => '/un/connect/able')

      # project.reload.cache_revisions
      assert_equal 2, project.reload.revisions.size
      assert_equal 1, project.card_revision_links.size
      assert config.reload.initialized
      assert !config.card_revision_links_invalid
    end
  end

  def test_cache_revisions_first_time_against_bogus_repository_deletes_all_revisions_and_card_links
    with_new_project do |project|
      project.cards.create!(:number => 100, :card_type => project.card_types.first, :name => 'boo')

      repos_driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
        driver.add_file('new_file_1.txt', 'some content')
        driver.commit "play #100"
      end
      config = new_repos_config(project, :repository_path => repos_driver.repos_dir)
      project.cache_revisions

      assert_equal 2, project.reload.revisions.size
      assert_equal 1, project.card_revision_links.size

      project.delete_repository_configuration
      config = new_repos_config(project, :repository_path => '/bogus/path')
      project.cache_revisions

      # project.reload.cache_revisions
      assert_equal 0, project.reload.revisions.size
      assert_equal 0, project.card_revision_links.size
      assert config.reload.initialized
      assert !config.card_revision_links_invalid
    end
  end

  # to avoid spamming team when pointing to a new repository ...
  def test_cache_revisions_updates_all_subscriptions_to_latest_revision_after_rebuild_of_revisions
    with_new_project do |project|
      user = create_user!
      project.add_member(user)
      subscription = project.create_history_subscription(user, '')
      subscription.update_attribute :last_max_revision_id, -1

      repos_driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
        driver.add_file('new_file_1.txt', 'some content')
        driver.commit "hiya!"
      end

      config = new_repos_config(project, :repository_path => repos_driver.repos_dir)
      project.cache_revisions
      new_highest_revision = Revision.find(:first, :conditions => {:project_id => project.id}, :order => 'id desc')
      assert new_highest_revision.id > 0
      assert_equal 'hiya!', new_highest_revision.commit_message
      assert_equal new_highest_revision.id, subscription.reload.last_max_revision_id
    end
  end

  def test_cache_revisions_does_not_update_subscription_last_max_revision_id_if_repository_was_already_initialized
    with_new_project do |project|
      user = create_user!
      project.add_member(user)
      subscription = project.create_history_subscription(user, '')

      repos_driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
      end
      config = new_repos_config(project, :repository_path => repos_driver.repos_dir)
      project.cache_revisions
      last_max_revision_for_subscription = subscription.reload.last_max_revision_id

      repos_driver.add_file('new_file_1.txt', 'some content')
      repos_driver.commit "add another revision"
      project.cache_revisions
      assert_equal last_max_revision_for_subscription, subscription.reload.last_max_revision_id
    end
  end


  def test_run_once_caches_for_all_projects
    project_one = first_project
    project_one.with_active_project do |p|
      configure_subversion_for(p, {:repository_path => @driver_one.repos_dir})
    end

    project_two = project_without_cards
    project_two.with_active_project do |p|
      configure_subversion_for(p, {:repository_path => @driver_two.repos_dir})
    end

    RevisionsHeaderCaching.run_once

    sorted_commits = project_one.revisions.sort_by(&:number)
    assert_equal 2, project_one.revisions.size
    assert sorted_commits.last.commit_message.index('added new_file_1')

    sorted_commits = project_two.revisions.sort_by(&:number)
    assert_equal 2, sorted_commits.size
    assert sorted_commits.last.commit_message.index('added new_file_2')
  end

  # this test random failed on build at lease 1 time
  def test_run_once_cleans_up_when_repository_config_is_marked_for_deletion
    ActionController::Base.perform_caching = true

    begin
      project = with_new_project do |p|
        p.cards.create(:number => 1, :name => 'first card', :card_type_name => 'card')
        p.cards.create(:number => 2, :name => 'second card', :card_type_name => 'card')
        p.cards.create(:number => 3, :name => 'third card', :card_type_name => 'card')
        p.cards.create(:number => 4, :name => 'fourth card', :card_type_name => 'card')
        configure_subversion_for(p, {:repository_path => @driver_one.repos_dir})
      end

      RevisionsHeaderCaching.run_once
      cache_revisions_content_for project

      # check that revisions and revision card links are built form first repos
      sorted_commits = project.revisions.sort_by(&:number)
      assert_equal 2, project.reload.revisions.size
      assert sorted_commits.last.commit_message.index('added new_file_1')
      assert project.cards[0].revisions[0]
      assert !project.cards[1].revisions[0]
      assert !project.cards[2].revisions[0]
      assert project.cards[3].revisions[0]

      first_revision_content_cache_path = File.join(SwapDir::RevisionCache.pathname, project.id.to_s, project.repository_configuration.plugin_db_id.to_s)
      assert File.exist?(first_revision_content_cache_path)

      # delete first and switch to second repos
      project.delete_repository_configuration
      project.reload
      configure_subversion_for(project, {:repository_path => @driver_two.repos_dir})

      # simulate real background procesing -- there will not be an active project
      Project.current.deactivate rescue nil

      RevisionsHeaderCaching.run_once

      # check that revisions and revision card links are now built form second repos
      project.reload.with_active_project do |p|
        assert_equal 2, p.reload.revisions.size
        sorted_commits = p.revisions.sort_by(&:number)
        assert sorted_commits.last.commit_message.index('added new_file_2')
        assert !p.cards[0].revisions[0]
        assert p.cards[1].revisions[0]
        assert p.cards[2].revisions[0]
        assert !p.cards[3].revisions[0]
      end

      # now check that old stuff was deleted
      assert_equal 1, SubversionConfiguration.count(:conditions => ['project_id = ?', project.id])
      assert_equal 2, Revision.count(:conditions => ['project_id = ?', project.id])
      assert_equal 2, CardRevisionLink.count(:conditions => ['project_id = ?', project.id])

      assert !File.exist?(first_revision_content_cache_path)
    ensure
      ActionController::Base.perform_caching = false
    end
  end

  def test_does_nothing_when_scm_feature_disabled
    with_new_project do |project|
      config = new_repos_config(project, :repository_path => @driver_one.repos_dir)
      FEATURES.deactivate("scm")
      assert_no_difference "Revision.count" do
        project.cache_revisions
      end
    end
  ensure
    FEATURES.activate("scm")
  end

  def test_should_not_start_transaction_while_getting_next_revisions
    with_new_project do |project|
      driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
      end
      config = new_repos_config(project, :repository_path => driver.repos_dir)

      config.repository.class.class_eval do

        include Test::Unit::Assertions
        @@transaction_count = Project.connection.open_transactions

        alias :next_revisions_old :next_revisions
        def next_revisions(*args, &block)
          assert_equal @@transaction_count, Project.connection.open_transactions
          next_revisions_old(*args, &block)
        end
      end

      project.cache_revisions
      first_revision = project.reload.revisions.first
      assert first_revision.commit_time.gmt?
    end
  end

  private

  def new_repos_config(project, options = {})
    config = SubversionConfiguration.create!({:project_id => project.id}.merge(options))
    project.reload
    config
  end


end
