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

require File.expand_path(File.dirname(__FILE__) + '/project_import_export_test_helper')

# this test will fail if there's residue in the database
# and we are having trouble with transactionality in this test
# let's ensure there's nothing weird there before we start the test
class ImportExportHistorySubscriptionsTest < ActiveSupport::TestCase
  include ProjectImportExportTestHelper
  
  def test_history_subscriptions_are_exported_and_imported_for_projects
    @user = login_as_member
    @project = create_project(:users => [@user])

    bug_page = @project.pages.create!(:name => 'bug page')
    bug_page_subscription = @project.create_history_subscription(@user, "page_identifier=#{bug_page.identifier}")
    
    @export_file = create_project_exporter!(@project, @user).export
    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!

    assert_equal 1, imported_project.history_subscriptions.count
    
    imported_subscription = imported_project.history_subscriptions.first
    imported_bug_page = imported_project.pages.find_by_name('bug page')
    imported_user = imported_project.users.find_by_login('member')
    
    assert imported_subscription.is_page_subscription?(imported_bug_page)
    assert_equal imported_user, imported_subscription.user
  end
  
  def test_history_subscriptions_are_not_imported_for_projects_with_smtp_not_set_up
    @user = login_as_member
    @project = create_project(:users => [@user])
    begin
      pretend_smtp_configuration_is_not_loaded
      bug_page = @project.pages.create!(:name => 'bug page')
      bug_page_subscription = @project.create_history_subscription(@user, "page_identifier=#{bug_page.identifier}")

      @export_file = create_project_exporter!(@project, User.current, :template => false).export
      @project_importer = create_project_importer!(User.current, @export_file)
      imported_project = @project_importer.process!

      assert_equal 0, imported_project.history_subscriptions.count
    ensure
      reenable_smtp_configuration_load_method
    end
  end

  def test_history_subscriptions_are_not_exported_for_templates
    @user = login_as_member
    @project = create_project(:users => [@user])

    bug_page = @project.pages.create!(:name => 'bug page')
    bug_page_subscription = @project.create_history_subscription(@user, "page_identifier=#{bug_page.identifier}")

    @export_file = create_project_exporter!(@project, User.current, :template => true).export
    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!

    assert_equal 0, imported_project.history_subscriptions.count
  end

  def test_history_subscriptions_with_user_ids_in_the_filters_get_converted_to_the_new_ids
    @user = login_as_member
    @project = create_project(:users => [@user])
    setup_property_definitions :status => ['new', 'open', 'fixed'], :iteration => [1,2], :release => [1]
    create_card!(:name => 'Exported Card')

    existing_user = create_user!
    imported_user_login = existing_user.login
    begin
      owner = setup_user_definition('owner')
      @project.add_member existing_user
      initial_filter_params = "acquired_filter_properties[owner]=#{existing_user.id}&filter_types[cards]=Card::Version&filter_user=#{existing_user.id}&involved_filter_properties[status]=new&involved_filter_properties[owner]=#{existing_user.id}"
      @project.create_history_subscription(@user, initial_filter_params)

      @export_file = create_project_exporter!(@project, User.current, :template => false).export

      # change the user so that when we import him/her, he/she gets created as a new user with a new user id
      existing_user_with_new_properties = existing_user
      existing_user_with_new_properties.login = 'zinga'.uniquify
      existing_user_with_new_properties.name = 'zingaman'
      existing_user_with_new_properties.email = existing_user_with_new_properties.login + '@aslkdfj.com'
      existing_user_with_new_properties.save!

      # now import like you've never imported before!
      @project_importer = create_project_importer!(User.current, @export_file)
      imported_project = @project_importer.process!
      imported_user = User.find_by_login(imported_user_login)
      assert_not_nil imported_user

      assert_equal 1, imported_project.history_subscriptions.count

      params = imported_project.history_subscriptions.first.filter_params
      assert_include "acquired_filter_properties[owner]=#{imported_user.id}", params
      assert_include "filter_types[cards]=Card::Version", params
      assert_include "filter_user=#{imported_user.id}&involved_filter_properties[owner]=#{imported_user.id}", params
      assert_include "involved_filter_properties[status]=new", params

    ensure
      existing_user.delete # destroy does not really delete users here :(
      if imported_user = User.find_by_login(imported_user_login)
        imported_user.delete # destroy does not really delete users here :(
      end
    end
  end

  def test_history_subscriptions_containing_the_any_change_special_value_are_correctly_imported
    user = login_as_member
    project = create_project(:users => [user])
    create_card!(:name => 'Exported Card')

    existing_user = create_user!
    imported_user_login = existing_user.login

    begin
      owner = setup_user_definition('owner')
      project.add_member existing_user

      filter_params_with_any_change = {
        "involved_filter_properties" => { "owner" => "" },
        "acquired_filter_properties" => { "owner" => "(any change)" },
        "filter_types" => { "cards" => "Card::Version" }
      }

      project.create_history_subscription(existing_user, filter_params_with_any_change)

      export_file = create_project_exporter!(project, User.current, :template => false).export

      # change the user so that when we import him/her, he/she gets created as a new user with a new user id
      existing_user_with_new_properties = existing_user
      existing_user_with_new_properties.login = 'zinga'.uniquify
      existing_user_with_new_properties.name = 'zingaman'
      existing_user_with_new_properties.email = existing_user_with_new_properties.login + '@aslkdfj.com'
      existing_user_with_new_properties.save!

      project_importer = create_project_importer!(User.current, export_file)
      imported_project = project_importer.process!
      imported_user = User.find_by_login(imported_user_login)
      assert_not_nil imported_user

      assert_equal 1, imported_project.history_subscriptions.count
      assert_equal filter_params_with_any_change, imported_project.history_subscriptions.first.filter_params
    ensure
      existing_user.delete # destroy does not really delete users here :(
      if imported_user = User.find_by_login(imported_user_login)
        imported_user.delete # destroy does not really delete users here :(
      end
    end
  end

  def test_history_subscriptions_with_card_ids_in_the_filters_get_converted_to_the_new_ids
    @member = login_as_member

    create_tree_project(:init_three_level_tree) do |project, tree, configuration|
      project.add_member(@member)

      release1 = project.cards.find_by_name('release1')
      iteration1 = project.cards.find_by_name('iteration1')

      initial_filter_params = "acquired_filter_properties[Planning+release]=#{release1.id}&involved_filter_properties[Planning+iteration]=#{iteration1.id}"
      project.create_history_subscription(@member, initial_filter_params)

      @export_file = create_project_exporter!(project, User.current, :template => false).export
      @project_importer = create_project_importer!(User.current, @export_file)
      imported_project = @project_importer.save_file(@export_file).process!

      assert_equal 1, imported_project.history_subscriptions.count

      imported_project.activate
      imported_release1 = imported_project.cards.find_by_name('release1')
      imported_iteration1 = imported_project.cards.find_by_name('iteration1')

      imported_project.history_subscriptions.reload # reloading here tests that project_import saves the altered history subscription
      assert_equal "acquired_filter_properties[Planning+release]=#{imported_release1.id}&involved_filter_properties[Planning+iteration]=#{imported_iteration1.id}",
                   imported_project.history_subscriptions.first.filter_params
    end
  end

  def test_history_subscription_last_max_card_page_and_revision_ids_get_changed
    @user = login_as_member
    @project = create_project(:users => [@user])

    revision = @project.revisions.create(:number => 1, :identifier => '1',
      :commit_message => 'revision 1', :commit_time => Time.now, :commit_user => 'svn user')
    bug_page = @project.pages.create!(:name => 'bug page')
    card = @project.cards.create!(:name => 'hi there', :card_type_name => 'Card')
    bug_page_subscription = @project.create_history_subscription(@user, "page_identifier=#{bug_page.identifier}")

    @export_file = create_project_exporter!(@project, @user, :template => false).export
    @project_importer = create_project_importer!(@user, @export_file)
    imported_project = @project_importer.process!

    assert_equal 1, imported_project.history_subscriptions.count

    imported_subscription = imported_project.history_subscriptions.first
    imported_last_max_card_version_id = imported_subscription.last_max_card_version_id
    imported_subscription_last_max_page_version_id = imported_subscription.last_max_page_version_id
    imported_subscription_last_max_revision_id = imported_subscription.last_max_revision_id

    imported_project.make_history_subscription_current(imported_subscription)
    assert_equal imported_subscription.last_max_card_version_id, imported_last_max_card_version_id
    assert_equal imported_subscription.last_max_page_version_id, imported_subscription_last_max_page_version_id
    assert_equal imported_subscription.last_max_revision_id, imported_subscription_last_max_revision_id
  end

  # Bug 8028
  def test_should_include_history_subscriptions_for_admins_who_are_not_members_of_the_exported_project
    @user = login_as_member
    @project = create_project(:users => [@user])

    bug_page = @project.pages.create!(:name => 'bug page')
    admin = User.find_by_login("admin")
    bug_page_subscription = @project.create_history_subscription(admin, "page_identifier=#{bug_page.identifier}")

    @export_file = create_project_exporter!(@project, @user).export
    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!

    assert_equal 1, imported_project.history_subscriptions.count

    imported_subscription = imported_project.history_subscriptions.first

    assert_equal admin, imported_subscription.user
    assert_not imported_project.member?(admin)
  end
end
