# -*- coding: utf-8 -*-

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

# Tags: #921
class ProjectTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree

  def setup
    SmtpConfiguration.load
    @project = first_project
    @project.activate
    login_as_admin
  end

  def teardown
    cleanup_repository_drivers_on_failure
  end

  def test_ownership_properties
    with_new_project do |project|
      setup_user_definition("owner")
      setup_user_definition("dev")
      assert_equal ["dev", "owner"], project.ownership_properties.sort
    end
  end

  def test_create_non_english_project
    proj = with_new_project(:name => '中文', :identifier => '__') do |project|
      project.cards.create! :name => 'works', :card_type_name => 'Card'
    end
    assert proj
    assert proj.identifier =~ /^proj_[\w\d]+/
  end

  def test_clear_active_project
    Project.clear_active_project!
    assert_false Project.activated?
  end

  def test_should_have_a_default_card_type_after_project_created
    project = Project.create!(:name => 'gimme some types', :identifier => 'card_types'.uniquify[0..20])
    assert_equal 1, project.card_types.size
  end

  def test_creating_a_project_creates_a_team_group
    with_new_project do |project|
      assert project.team
    end
  end

  def test_unique
    long_str = '1234567890_1234567890_1234567890_1234567890'
    with_new_project do |project|
      suffix = 'suffix'
      assert_equal "#{project.identifier}1", Project.unique(:identifier, project.identifier)
      assert_equal "#{project.identifier}#{suffix}", Project.unique(:identifier, project.identifier, suffix)
      assert_equal "#{project.identifier}#{long_str}".slice(0, Identifiable::IDENTIFIER_MAX_LEN - suffix.length) + suffix, Project.unique(:identifier, project.identifier + long_str, suffix)
      assert_equal "#{project.name}1", Project.unique(:name, project.name)
      assert_equal "#{project.name.upcase}1", Project.unique(:name, project.name.upcase)
      assert_equal "#{project.name}#{suffix}", Project.unique(:name, project.name, suffix)

      another_project_name = Project.unique(:name, project.name, suffix)
      another_project_identifier = Project.unique(:identifier, project.identifier, suffix)
      another_project = Project.create!(:name => another_project_name, :identifier => another_project_identifier)

      assert_equal "#{project.name}#{suffix}1", Project.unique(:name, project.name, suffix)
      assert_equal "#{project.identifier}#{suffix}1", Project.unique(:identifier, project.identifier, suffix)
    end
  end

  def test_identifier_cant_conflict_with_mingle_internal_table_name_prefix
    project = Project.new(:name => 'Blah', :identifier => 'mi_1234567_blah')
    assert !project.valid?
    assert_equal ["Identifier reserved for internal Mingle use"], project.errors.full_messages
  end

  def test_identifier_should_be_valid
    project = Project.new(:name => 'Project', :identifier => 'this is a bad identifier')
    assert !project.valid?
    assert_equal ["Identifier may contain only lower case letters, numbers and underscore ('_')"], project.errors.full_messages
  end

  def test_identifier_cant_start_with_digit
    project = Project.new(:name => 'Project', :identifier => '1_this_is_a_bad_identifier')
    assert !project.valid?
    assert_equal ["Identifier may not start with a digit"], project.errors.full_messages
  end

  # test for bug #921
  def test_strips_whitespaces_from_name_and_identifier
    project_name = unique_project_name
    project_name_with_whitespace = "  #{project_name}  "
    project_identifier = unique_project_name
    Project.create!(:name => project_name_with_whitespace, :identifier => project_identifier).with_active_project do |project|
      assert_equal project_name, project.name
      assert_equal project_identifier, project.identifier
    end
  end

  def test_identifier_validation_removes_underscores_when_applicable
    # case 1: identifier leading and trailing underscores should be removed if they correspond to leading and trailing spaces in the project name
    project_name = unique_project_name
    project_name_with_whitespace = " #{project_name} "
    project_identifier = "_#{project_name}_"

    Project.create!(:name => project_name_with_whitespace, :identifier => project_identifier).with_active_project do |project|
      assert_equal project_name, project.name
      assert_equal project_name, project.identifier
    end

    # case 2: it's ok for identifier to have leading and trailing underscores when they correspond to special characters in the project name
    project_name = unique_project_name
    project_name_with_brackets = "(#{project_name})"
    project_identifier = "_#{project_name}_"

    Project.create!(:name => project_name_with_brackets, :identifier => project_identifier).with_active_project do |project|
      assert_equal project_name_with_brackets, project.name
      assert_equal project_identifier, project.identifier
    end

    # case 3: it's ok for identifier to have leading and trailing underscores that do not correspond to special characters, provided the identifier
    # was not system generated
    project_name = unique_project_name
    project_identifier = "_#{unique_project_name}_"

    Project.create!(:name => project_name, :identifier => project_identifier).with_active_project do |project|
      assert_equal project_name, project.name
      assert_equal project_identifier, project.identifier
    end

    # case 4: a lot of space in the middle of a name will be trimmed, but the middle underscores will be left alone. This is just how the old code
    # did it and it seems easiest to leave it that way
    project_name = "alotof     spaces"
    project_identifier = "alotof_____spaces"

    Project.create!(:name => project_name, :identifier => project_identifier).with_active_project do |project|
      assert_equal "alotof spaces", project.name
      assert_equal project_identifier, project.identifier
    end
  end

  # test for #1023 and #1024
  def test_can_change_project_identifier_and_still_look_at_cards
    p = with_new_project do |project|
      create_card!(:name => 'My card')

      new_identifier = "proj_#{Time.now.to_i}"
      project.update_attributes!(:identifier => new_identifier)
      project.reload
    end

    p.with_active_project do |project|
      assert_equal 'My card', project.cards.find(:first).name
    end
  end

  def test_default_view_for_tab_returns_empty_view_for_all
    all_view = @project.default_view_for_tab(DisplayTabs::AllTab::NAME)
    assert all_view.tagged_with.empty?
    assert_equal DisplayTabs::AllTab::NAME, all_view.name
  end

  def test_default_view_for_user_defined_tab
    create_tabbed_view('Stories', @project, :filters => ['[type][is][story]'])
    assert_equal 'filters=[type][is][story],style=list', @project.default_view_for_tab('Stories').canonical_string
  end

  def test_can_create_tables_and_add_columns
    with_new_project do |p|

      p.all_property_definitions.create!(:name => 'Iteration')
      p.all_property_definitions.create!(:name => 'Role')
      p.reload

      p.drop_card_schema
      p.reload.create_card_schema

      columns = p.connection.columns(Card.table_name).collect{|c| c.name}
      assert columns.include?('id')
      assert columns.include?('name')
      assert columns.include?('description')
      assert columns.include?('version')
      assert columns.include?('cp_iteration')
      assert columns.include?('cp_role')

      columns = p.connection.columns(Card.versioned_table_name).collect{|c| c.name}
      assert columns.include?('id')
      assert columns.include?('name')
      assert columns.include?('description')
      assert columns.include?('version')
      assert columns.include?('cp_iteration')
      assert columns.include?('cp_role')
    end
  end

  def test_setting_up_owner_property_definition_for_a_project
    with_new_project do |project|
      project.all_property_definitions.create_user_property_definition(:name => 'analyst')
      project.reload
      project.drop_card_schema
      project.reload.create_card_schema

      assert Card.columns.collect(&:name).include?('cp_analyst_user_id')
    end
  end

  def test_can_set_owner_property_on_card
    bob = User.find_by_login('bob')
    create_project(:users => [bob]) do |project|
      ba_def = project.create_user_definition!(:name => 'ba')
      project.card_types.first.add_property_definition(ba_def)
      project.reload
      project.drop_card_schema
      project.reload.create_card_schema
      project.save!

      card = create_card!(:name => 'owned card', :ba => bob.id)
      assert_equal bob.id, project.cards.find_by_name('owned card').cp_ba.id
    end
  end

  def test_can_load_cards_and_look_at_attributes
    card =create_card!(:name => 'Card with attributes', :iteration => '1', :status => 'open')
    card.reload
    assert_equal 'open', card.cp_status
    assert_equal '1', card.cp_iteration
  end

  def test_can_update_card_attributes
    card =create_card!(:name => 'Card with attributes')

    card.cp_iteration = '1'
    card.cp_status = 'open'
    card.save!

    assert_equal 'open', card.cp_status
    assert_equal '1', card.cp_iteration
  end

  def test_empty_project_does_not_have_any_last_activity
    with_new_project do |p|
      assert_nil p.last_activity
    end
  end

  def test_can_know_last_activity
    Clock.fake_now('2011-3-12')
    with_new_project do |p|
      card = create_card!(:name => 'card1') #1
      card.reload.tag_with('foo').save! #2
      card.reload.tag_with('bar').save! #3
      page = p.pages.create(:name => 'new_page') #1
      page.tag_with('random').save! #2

      two_days_ago = Time.parse("2011-3-10").utc
      three_days_ago = Time.parse("2011-3-9").utc
      five_days_ago = Time.parse("2011-3-7").utc

      set_modified_time_with_time(card, 1, five_days_ago)
      set_modified_time_with_time(card, 2, three_days_ago)
      set_modified_time_with_time(card, 3, three_days_ago)
      set_modified_time_with_time(page, 1, five_days_ago)
      set_modified_time_with_time(page, 2, two_days_ago)

      assert_equal two_days_ago.to_s, p.last_activity.to_s
    end
  ensure
    Clock.reset_fake
  end

  def test_can_encrypt_and_decrypt
    @project.generate_secret_key!
    assert_equal(
      "filter_tags=&acquired_tags=Dev-tirsen",
      @project.decrypt(@project.encrypt("filter_tags=&acquired_tags=Dev-tirsen")))
  end

  def test_encrypt_and_decrypt_multiple_times_which_do_not_run_on_blow_fish_with_jruby
    @project.generate_secret_key!
    assert_equal(
      "filter_tags=&acquired_tags=Dev-tirsen",
      @project.decrypt(@project.encrypt("filter_tags=&acquired_tags=Dev-tirsen")))
    assert_equal "filter_tags=", @project.decrypt(@project.encrypt("filter_tags="))
  end

  def test_cant_decrypt_garbage
    assert_raise Project::DecryptionError do
      @project.decrypt("garbage")
    end
  end

  def test_repository_password_still_works_after_secret_key_regeneration
    new_repos_config(@project, :password => 'top-secret-stuff').id
    config = @project.send(:repository_configuration)
    encrypted_password = config.instance_variable_get(:@plugin).attributes['password']
    @project.generate_secret_key!
    assert_not_equal encrypted_password, config.instance_variable_get(:@plugin).attributes['password']
    assert_equal 'top-secret-stuff', config.instance_variable_get(:@plugin).decrypted_password
  end

  def test_card_keywords_should_wrap_data_correctly_and_not_save_unecessary_data_to_db
    @project.update_attributes!(:card_keywords => '#, card, story, bug')
    assert_equal CardKeywords, @project.reload.card_keywords.class
    assert_equal '#, card, story, bug', @project.reload.attributes['card_keywords']
    assert_equal '#, card, story, bug', @project.reload.card_keywords.to_s

    @project.update_attributes!(:card_keywords => CardKeywords::DEFAULT_CARD_KEYWORDS.join(','))
    assert_equal CardKeywords::DEFAULT_CARD_KEYWORDS.join(', '), @project.reload.card_keywords.to_s
    assert_nil @project.reload.attributes['card_keywords']
  end

  def test_should_do_card_keywords_validation_while_validating_project
    project = Project.new(:name => 'blah', :identifier => 'blah', :card_keywords => ',')
    assert !project.valid?
    assert_equal ["Card keywords are limited to words and the '#' symbol"], project.errors.full_messages
  end

  def test_project_identifier_max_length_should_be_30
    project = Project.new(:name => 'blah', :identifier => 'abcd_fghi_1234_6789_abcd_fghi_')
    assert project.valid?

    project = Project.new(:name => 'blah', :identifier => 'abcd_fghi_1234_6789_abcd_fghi_1234_678900')
    assert !project.valid?
    assert_equal ["Identifier is too long (maximum is 30 characters)"], project.errors.full_messages
  end

  def test_validate_project_email_adress
    assert Project.new(:name => 'blah', :identifier => 'blahblah').valid?
    assert Project.new(:name => 'blah', :identifier => 'blahblah', :email_address => 'some@address.com').valid?
    assert !Project.new(:name => 'blah', :identifier => 'blahblah', :email_address => 'invalid address.com').valid?
  end

  def test_find_enumeration_values_returns_correct_values_in_expected_orde
    status_def = @project.find_property_definition('status')
    status_values = @project.find_enumeration_values(status_def)
    assert_equal ['fixed', 'new', 'open', 'closed','in progress'], status_values.collect(&:value)

    status_values[0].update_attribute(:position, 3)
    status_values[2].update_attribute(:position, 1)
    @project.reload
    status_values = @project.find_enumeration_values(status_def)
    assert_equal ['open', 'new', 'fixed', 'closed','in progress'], status_values.collect(&:value)
  end

  def test_find_card_types_returns_correct_values
    story = @project.card_types.create!(:name => 'story')
    bug = @project.card_types.create!(:name => 'bug')
    issue = @project.card_types.create!(:name => 'issue')

    status = @project.find_property_definition('status')
    story.add_property_definition(status)
    bug.add_property_definition(status)
    release = @project.find_property_definition('release')
    issue.add_property_definition(release)

    @project = Project.current.reload
    assert_equal ['bug', 'Card', 'story'], @project.find_property_definition('status').card_types.collect(&:name).smart_sort
    assert_equal ['Card', 'issue'], @project.find_property_definition('release').card_types.collect(&:name).smart_sort
  end

  # for bug 1238
  def test_name_identifier_description_are_striped
    project = Project.new(:name => ' foo ', :identifier => ' foo ', :description => ' foodescription ')
    project.save
    assert_equal 'foo', project.name
    assert_equal 'foo', project.identifier
    assert_equal 'foodescription', project.description
  end

  def test_should_allow_only_mingle_admins_and_team_members_to_subscribe_to_email
    non_team_member_mingle_admin = User.first_admin
    team_member = User.find_by_name('first@email.com')
    non_admin_non_team_member = User.find(:all).reject {|u| @project.users.include?(u) || u.admin? }.first

    admin_susbcription = @project.create_history_subscription(non_team_member_mingle_admin, {})
    assert non_team_member_mingle_admin.history_subscriptions.include?(admin_susbcription)

    member_susbcription = @project.create_history_subscription(team_member, {})
    assert team_member.history_subscriptions.include?(member_susbcription)

    assert_raise RuntimeError do
      @project.create_history_subscription(non_admin_non_team_member, {})
    end
  end

  def test_create_history_subscription_sets_max_versions_from_project
    user = create_user!
    @project.add_member(user)
    max_card_version_id = @project.card_versions.maximum("id")
    assert max_card_version_id > 1  # test seems better when > 1
    max_page_version_id = @project.page_versions.maximum("id")
    assert max_page_version_id > 1 # test seems better when > 1
    @project.revisions.create!(:number => 1, :identifier => '1',
      :commit_message => 'revision 1', :commit_time => Time.now, :commit_user => 'joe')
    @project.revisions.create!(:number => 2, :identifier => '2',
      :commit_message => 'revision 2', :commit_time => Time.now, :commit_user => 'bob')
    @project.revisions.create!(:number => 3, :identifier => '3',
      :commit_message => 'revision 3', :commit_time => Time.now, :commit_user => 'joe')
    max_revision_id = @project.revisions.maximum("id")
    subscription = @project.create_history_subscription(user, "")
    assert_equal max_card_version_id, subscription.last_max_card_version_id
    assert_equal max_page_version_id, subscription.last_max_page_version_id
    assert_equal max_revision_id, subscription.last_max_revision_id
  end

  def test_create_history_subscription_sets_max_versions_to_zero_when_no_versions
    user = create_user!
    with_project_without_cards do |project|
      project.add_member(user)
      subscription = project.create_history_subscription(user, "")
      assert_equal 0, subscription.last_max_card_version_id
      assert_equal 0, subscription.last_max_page_version_id
      assert_equal 0, subscription.last_max_revision_id
    end
  end

  def test_cannot_create_subscription_for_user_who_is_not_a_project_member
    @user = create_user!
    assert !@project.member?(@user)
    begin
      project.create_history_subscription(user, "")
    rescue
      # expected
      return
    end
    fail "should not have created subscription for non-member."
  end

  def test_send_history_notifications_skips_revisions_if_no_repos_config
    ActionMailer::Base.deliveries.clear
    subscription = @project.create_history_subscription(User.find_by_login('member'), "")
    @project.revisions.create!(:number => 1, :identifier => '1',
      :commit_message => 'revision 1', :commit_time => Time.now, :commit_user => 'joe')
    stub_repository(@project, :has_source_repository => false, :source_repository_configured => true)
    @project.send_history_notifications
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def test_send_history_notifications_skips_revisions_if_no_initialized_repos_config
    ActionMailer::Base.deliveries.clear
    subscription = @project.create_history_subscription(User.find_by_login('member'), "")
    @project.revisions.create!(:number => 1, :identifier => '1',
      :commit_message => 'revision 1', :commit_time => Time.now, :commit_user => 'joe')
    stub_repository(@project, :has_source_repository => true, :source_repository_configured => false)
    @project.send_history_notifications
    assert_equal 0, ActionMailer::Base.deliveries.size
  end

  def stub_repository(project, options)

    eval %{
      def project.has_source_repository?
        #{options[:has_source_repository]}
      end
      def project.source_repository_configured?
        #{options[:source_repository_configured]}
      end
    }

    # must survive project de-activation
    def project.repository_configuration
      Object.new.tap do |config|
        def config.method_missing(method, *args)
        end
      end
    end

  end

  def test_only_admin_can_create_text_list_definition
    login_as_member
    assert_raise(UserAccess::NotAuthorizedException) do
      @project.create_text_list_definition(:name => 'new definition')
    end
  end

  def test_properties_for_filter_does_not_include_text_property
    project = first_project
    property_definitions = project.property_definitions_for_filter
    assert property_definitions.select {|d| d.class == TextPropertyDefinition }.empty?
  end

  def test_properties_for_columns_have_type_first_and_other_stuff_last
    property_definitions = @project.property_definitions_for_columns
    assert_equal @project.card_type_definition.name, property_definitions.first.name
    assert_equal ['Created by', 'Modified by'], property_definitions[(property_definitions.size - 2), 2].collect(&:name)
  end

  def test_property_definitions_not_applicable_to_type
    story = @project.card_types.create(:name => 'story')
    story.add_property_definition @project.find_property_definition('status')
    story.add_property_definition @project.find_property_definition('iteration')
    story.add_property_definition @project.find_property_definition('priority')

    bug = @project.card_types.create(:name => 'bug')
    bug.add_property_definition  @project.find_property_definition('assigned')
    bug.add_property_definition  @project.find_property_definition('release')
    bug.add_property_definition  @project.find_property_definition('priority')

    @project.reload

    assert_equal ["Custom property", "Iteration", "Material", "Property without values", "Some property",
     "Stage", "Status", "Unused", "dev", "id", "old_type", "start date"],
      @project.property_defintions_not_applicable_to_type('bug').collect(&:name).sort
    assert_equal   ["Assigned", "Custom property", "Material", "Property without values", "Release",
      "Some property", "Stage", "Unused", "dev", "id", "old_type", "start date"],
      @project.property_defintions_not_applicable_to_type('story').collect(&:name).sort
  end

  def test_property_defintions_not_applicable_to_type_should_not_include_tree_relationship_properties
    create_tree_project(:init_two_release_planning_tree) do |project, tree, config|
      project.reload
      assert_equal ['Planning iteration', 'Planning release'], project.property_defintions_not_applicable_to_type('release').collect(&:name).sort
      assert_equal ['Planning iteration'], project.property_defintions_not_applicable_to_type('iteration').collect(&:name).sort
      assert_equal [], project.property_defintions_not_applicable_to_type('story').collect(&:name).sort
    end
  end

  def test_property_definitions_not_applicable_to_type_should_return_all_property_definitions_for_a_non_existent_card_type
    with_new_project do |project|
      setup_managed_text_definition('some property', ['a', 'b'])
      setup_managed_text_definition('yet another property', ['a', 'b'])
      assert_equal ['some property', 'yet another property'], project.property_defintions_not_applicable_to_type('nonexistenttype').map(&:name).sort
    end
  end

  def test_find_property_definitions_by_card_types
    story = @project.card_types.create!(:name => 'story')
    story.property_definitions = ['release', 'iteration'].collect{|pd_name| @project.find_property_definition(pd_name)}
    bug = @project.card_types.create!(:name => 'bug')
    bug.property_definitions = ['assigned', 'iteration'].collect{|pd_name| @project.find_property_definition(pd_name)}

    story.clear_cache
    bug.clear_cache
    assert_equal ['iteration', 'release', 'type'],
      @project.find_property_definitions_by_card_types([story]).collect(&:name).collect(&:downcase).sort
    assert_equal ['assigned', 'iteration', 'release', 'type'],
      @project.find_property_definitions_by_card_types([story, bug]).collect(&:name).collect(&:downcase).sort
  end

  def test_initial_time_zone_for_new_project_is_server_local_time_zone
    assert_equal ActiveSupport::TimeZone.new(Time.now.gmt_offset).name, Project.new.time_zone
  end

  def test_time_zone
    with_new_project do |project|
      project.time_zone = ActiveSupport::TimeZone.new(0).name
      project.save!
      project.reload
      assert_equal ActiveSupport::TimeZone.new(0).name, project.time_zone
      assert_equal ActiveSupport::TimeZone.new(0), project.time_zone_obj
    end
  end

  def test_find_enumeration_value_raises_record_not_found_if_value_does_not_belong_to_project
    project_a = first_project
    project_b = project_without_cards

    project_a_release_1 = project_a.with_active_project do |project|
      enum = project.find_property_definition('release').find_enumeration_value('1')
      assert_equal project_a.id, enum.property_definition.project_id
      next enum
    end

    project_b_release_1 = project_b.with_active_project do |project|
      enum = project.find_property_definition('release').find_enumeration_value('1')
      assert_equal project_b.id, enum.property_definition.project_id
      next enum
    end

    begin
      project_a.find_enumeration_value(project_b_release_1.id)
    rescue ActiveRecord::RecordNotFound => e
      return # good!
    end
    fail 'EnumerationValue should not have been found'
  end

  def test_property_definitions_of_card_type_should_not_case_sensitive
     with_new_project do |project|
        bug_type = project.card_types.create(:name => 'bug')
        setup_property_definitions 'bug status' => ['open', 'close']
        bug_status = project.find_property_definition('bug status')
        bug_status.card_types = [bug_type]
        property_definitions_of_bug = project.property_definitions_of_card_type('Bug')
        assert_equal 2, property_definitions_of_bug.size
        assert_equal 'bug status', property_definitions_of_bug.last.name
     end
  end

  def test_transitions_dependent_upon_property_definitions_belonging_to_card_types
    with_new_project do |project|
      setup_for_transitions_dependent_upon_property_definitions_belonging_to_card_types_test(project)
      status = project.find_property_definition('status')
      priority = project.find_property_definition('priority')
      severity = project.find_property_definition('severity')
      bug = project.find_card_type('bug')
      story = project.find_card_type('story')
      assert_equal ['requires_story_and_priority', 'requires_story_and_sets_priority',
        'requires_story_and_priority_and_sets_priority', 'requires_story_and_sets_status',
        'sets_status_for_all_card_types', 'sets_severity_on_bug', 'requires_bug_and_sets_priority'].sort,
        project.transitions_dependent_upon_property_definitions_belonging_to_card_types([bug, story], [status, priority, severity]).collect(&:name).sort
    end
  end

  def test_destroy_transitions_dependent_upon_property_definitions_belonging_to_card_types
    with_new_project do |project|
      setup_for_transitions_dependent_upon_property_definitions_belonging_to_card_types_test(project)
      status = project.find_property_definition('status')
      priority = project.find_property_definition('priority')
      severity = project.find_property_definition('severity')
      bug = project.find_card_type('bug')
      story = project.find_card_type('story')
      project.destroy_transitions_dependent_upon_property_definitions_belonging_to_card_types([bug, story], [status, priority, severity])
      assert_equal ['requires_story_and_sets_release', 'requires_bug_and_sets_resolution'].sort,
        project.reload.transitions.collect(&:name).sort
    end
  end

  def setup_for_transitions_dependent_upon_property_definitions_belonging_to_card_types_test(project)
    setup_property_definitions(:release => ['1','2'], :status => ['new', 'open'],
      :priority => ['low', 'high'], :severity => ['low', 'high'], :resolution => ['fixed', 'as designed'])

    story = setup_card_type(project, 'story', :properties => ['release', 'status', 'priority'])
    bug = setup_card_type(project, 'bug', :properties => ['release', 'status', 'priority'])

    # these are dependent
    create_transition(project, 'requires_story_and_priority', :card_type => story,
      :required_properties => {:priority => 'high'}, :set_properties => {:release => '1'})
    create_transition(project, 'requires_story_and_sets_priority', :card_type => story,
      :set_properties => {:priority => 'low'})
    create_transition(project,
      'requires_story_and_priority_and_sets_priority', :card_type => story,
      :required_properties => {:priority => 'high'}, :set_properties => {:priority => 'low'})
    create_transition(project, 'requires_story_and_sets_status',
      :card_type => story, :set_properties => {:status => 'open'})
    create_transition(project, 'sets_status_for_all_card_types', :set_properties => {:status => 'open'})
    create_transition(project, 'sets_severity_on_bug', :card_type => bug, :set_properties => {:severity => 'low'})
    create_transition(project, 'requires_bug_and_sets_priority',
      :card_type => bug, :set_properties => {:priority => 'high'})

    # these are not dependent
    create_transition(project, 'requires_story_and_sets_release',
      :card_type => story, :set_properties => {:release => '1'})
    create_transition(project, 'requires_bug_and_sets_resolution',
      :card_type => bug, :set_properties => {:resolution => 'as designed'})
  end

  def test_should_keep_card_defaults_associated_to_the_project_when_the_project_id_is_changed
    project = create_project(:name => unique_project_name, :identifier => unique_project_name)
    card_defaults_size = project.card_defaults.size
    assert card_defaults_size != 0
    project.identifier = unique_project_name().gsub(/[^a-z0-9_]/, '_')
    project.save!
    project = Project.find_by_identifier(project.identifier)
    assert_equal card_defaults_size, project.card_defaults.size
    assert project.card_types.all? {|card_type| !card_type.card_defaults.nil? }
  end

  def test_save_does_not_load_associations
    with_first_project do |project|
      project.cards.find(:first)
      project.card_versions.find(:first)
      project.pages.find(:first)
      project.name = 'new name'
      project.save!
      assert !project.cards.loaded?
      assert !project.card_versions.loaded?
      assert !project.pages.loaded?
    end
  end

  def test_numeric_precision_should_be_an_integer_between_0_and_10
    a_project_name = unique_project_name
    project = Project.new(:name => a_project_name, :identifier => a_project_name, :precision => 'x')
    assert !project.valid?
    assert_equal ["Precision must be an integer between 0 and 10"], project.errors.full_messages
    project = Project.new(:name => a_project_name, :identifier => a_project_name, :precision => 1.1)
    assert !project.valid?
    assert_equal ["Precision must be an integer between 0 and 10"], project.errors.full_messages
    project = Project.new(:name => a_project_name, :identifier => a_project_name, :precision => '1x')
    assert !project.valid?
    assert_equal ["Precision must be an integer between 0 and 10"], project.errors.full_messages
    project = Project.new(:name => a_project_name, :identifier => a_project_name, :precision => -1)
    assert !project.valid?
    assert_equal ["Precision must be an integer between 0 and 10"], project.errors.full_messages
    project = Project.new(:name => a_project_name, :identifier => a_project_name, :precision => 11)
    assert !project.valid?
    assert_equal ["Precision must be an integer between 0 and 10"], project.errors.full_messages
  end

  def test_to_num_maintain_precision_should_not_remove_any_precision_less_than_project_precision
    project = create_project(:name => unique_project_name, :identifier => unique_project_name, :precision => 2)
    # assert_equal '1', project.to_num_maintain_precision('1.')
    assert_equal '1.0', project.to_num_maintain_precision('1.0')
    assert_equal '1.00', project.to_num_maintain_precision('1.00')
    assert_equal '1.00', project.to_num_maintain_precision('1.000')
    assert_equal '1.00', project.to_num_maintain_precision('1.0000000000')
    assert_equal '1.00', project.to_num_maintain_precision('1.004')
    assert_equal '1.01', project.to_num_maintain_precision('1.005')
  end

  def test_compare_numbers
    assert @project.compare_numbers(0.999, 1)
    assert @project.compare_numbers(0.999, 0.996)
    assert @project.compare_numbers(0.999, 1.004)
    assert @project.compare_numbers(0.999, 1.004)
    assert !@project.compare_numbers(0.99, 0.999)

    assert @project.compare_numbers(9, 9.0)
  end

  def test_format_number_when_it_is_out_of_precision
     assert_equal '9', @project.format_number('9')
     assert_equal '9.0', @project.format_number('9.0')
     assert_equal '9.00', @project.format_number('9.00')
     assert_equal '9.99', @project.format_number('9.99')
     assert_equal '10.00', @project.format_number('9.996')
     assert_equal '10.00', @project.format_number('9.999')
     assert_equal '10.00', @project.format_number('10.000')
  end

  def test_aggregate_associated_property_definitions
    with_new_project do |project|
      story = project.card_types.create!(:name => 'story')
      size = setup_numeric_text_property_definition('size')
      some_agg = setup_aggregate_property_definition('some agg', AggregateType::SUM, size, -1, story.id, AggregateScope::ALL_DESCENDANTS)
      assert_equal ['size'], project.aggregate_associated_property_definitions.collect(&:name)
    end
  end

  def test_target_property_definitons_ignores_count_aggregates
    with_new_project do |project|
      story = project.card_types.create!(:name => 'story')
      size = setup_numeric_text_property_definition('size')
      sum_agg = setup_aggregate_property_definition('sum agg', AggregateType::SUM, size, -1, story.id, AggregateScope::ALL_DESCENDANTS)
      count_agg = setup_aggregate_property_definition('count agg', AggregateType::COUNT, nil, -1, story.id, AggregateScope::ALL_DESCENDANTS)
      assert_equal 1, project.aggregate_associated_property_definitions.size
      assert_equal ['size'], project.aggregate_associated_property_definitions.collect(&:name)
    end
  end

  def test_relationship_property_definitions
    with_new_project do |project|
      tree_config = project.tree_configurations.create!(:name => 'Planning')
      type_release, type_iteration, type_story = init_planning_tree_types
      tree_config.update_card_types({
        type_release => {:position => 0, :relationship_name => 'release'},
        type_iteration => {:position => 1, :relationship_name => 'iteration'},
        type_story => {:position => 2}
      })

      assert_equal ['iteration', 'release'], project.reload.relationship_property_definitions.collect(&:name).sort
    end
  end

  def test_delete_project_repository_configuration
    repos_driver = with_cached_repository_driver(name) do |driver|
      driver.create
    end
    new_repos_config(@project, :repository_path => repos_driver.repos_dir)
    assert @project.has_source_repository?

    @project.delete_repository_configuration
    assert SubversionConfiguration.find_by_project_id(@project.id).marked_for_deletion
  end

  def test_project_property_definitions_without_tree
    create_project.with_active_project do |project|
      setup_property_definitions 'status' => ['open', 'close']
      size = setup_numeric_property_definition 'size', ['1', '2']
      type_release,type_iteration,type_story = init_planning_tree_types
      type_story.add_property_definition(size)
      type_story.save!
      tree = create_three_level_tree
      setup_aggregate_property_definition('sum size', AggregateType::SUM, size, tree.configuration.id, type_release.id, AggregateScope::ALL_DESCENDANTS)

      assert_equal ['status', 'size',"Planning iteration", "Planning release",'sum size'].sort, project.property_definitions.collect(&:name).sort
      assert_equal ['status', 'size'].sort, project.property_definitions_without_tree.collect(&:name).sort
    end
  end

  def test_can_find_predefined_property_definitions
    assert_find_predefined_property_definition('number')
    assert_find_predefined_property_definition('name')
    assert_find_predefined_property_definition('description')
    assert_find_predefined_property_definition('created by')
    assert_find_predefined_property_definition('modified by')
  end

  def test_should_be_able_to_get_predefined_properties
    predefined_properties = PredefinedPropertyDefinitions::TYPES.keys.collect do |key|
      PredefinedPropertyDefinitions.find(@project, key)
    end
    assert_equal predefined_properties.collect(&:name).sort, @project.predefined_property_definitions.collect(&:name).sort
  end

  def assert_find_predefined_property_definition(def_name)
    prop_def = @project.find_property_definition(def_name)
    assert_equal def_name.downcase, prop_def.name.downcase
    assert !prop_def.editable?
  end

  def test_predefined_property_definitions_are_cached_but_not_across_project_instances
    created_by_prop_def = @project.find_property_definition('created by')
    assert_equal created_by_prop_def.object_id, @project.find_property_definition('created by') .object_id
    assert_not_equal created_by_prop_def.object_id, Project.find(@project.id).find_property_definition('created by').object_id
  end

  def test_two_projects_cannot_have_same_name_with_different_capitalizations
    project_1 = Project.create!(:name => 'hello1', :identifier => 'hello1')
    project_2 = Project.create(:name => 'Hello1', :identifier => 'goodbye1')
    assert_equal ["Name has already been taken"], project_2.errors.full_messages
  end

  def test_numeric_list_property_definitions_with_hidden_should_return_all_managed_numeric_list_properties
    with_new_project do |project|
      setup_numeric_property_definition("attendees", [1, 2, 3, 4, 5])
      setup_managed_text_definition("status", ['open', 'done'])
      numeric_property_definitions = project.numeric_list_property_definitions_with_hidden
      assert 1, numeric_property_definitions.size
      assert_equal "attendees", numeric_property_definitions.first.name
    end
  end

  def test_text_list_property_definitions_with_hidden_should_return_all_managed_text_list_properties
    with_new_project do |project|
      setup_numeric_property_definition("attendees", [1, 2, 3, 4, 5])
      setup_managed_text_definition("status", ['open', 'done'])
      text_property_definitions = project.text_list_property_definitions_with_hidden
      assert 1, text_property_definitions.size
      assert_equal "status", text_property_definitions.first.name
    end
  end

  # bug 4505
  def test_all_numeric_property_definitions_method_should_return_numeric_formulas
    with_new_project do |project|
      our_date = setup_date_property_definition('ourdate')
      numeric_formula = setup_formula_property_definition('formula', '1 + 2')
      date_formula = setup_formula_property_definition('date formula', 'ourdate + 2')
      numeric_text = setup_numeric_text_property_definition('numeric text')
      numeric_regular = setup_numeric_property_definition('numeric regular', [1, 2, 3])

      assert_equal ['formula', 'numeric text', 'numeric regular'].sort, project.all_numeric_property_definitions.collect(&:name).sort
    end
  end

  def test_has_revisions_when_project_has_no_revisions
    Revision.destroy_all(:project_id => @project.id)
    assert !@project.has_revisions?
  end

  def test_has_revisions_when_project_has_revisions
    @project.revisions.create!(:number => 13, :identifier => '13',
      :commit_message => '', :commit_time => Time.now, :commit_user => 'joe')
    assert @project.has_revisions?
  end

  def test_cards_table_and_card_versions_table_is_populated_when_project_created
    project = create_project(:identifier => 'this_is_a_long_identifier', :skip_activation => true)
    for_postgresql do
      assert_equal 'this_is_a_long_identifier_cards', project.cards_table
      assert_equal 'this_is_a_long_identifier_card_versions', project.card_versions_table
    end
    for_oracle do
      assert_not_equal 'this_is_a_long_identifier_cards', project.cards_table
      assert_not_equal 'this_is_a_long_identifier_card_versions', project.card_versions_table
    end
  end

  def test_cards_table_and_card_versions_table_is_updated_when_project_identifier_is_updated
    with_new_project(:identifier => 'foo') do |project|
      project.identifier = 'this_is_a_long_identifier'
      project.save!
      for_postgresql do
        assert_equal 'this_is_a_long_identifier_cards', project.cards_table
        assert_equal 'this_is_a_long_identifier_card_versions', project.card_versions_table
      end
      for_oracle do
        assert_not_equal 'this_is_a_long_identifier_cards', project.cards_table
        assert_not_equal 'this_is_a_long_identifier_card_versions', project.card_versions_table
      end
    end
  end

  def test_cards_table_and_card_versions_table_is_not_updated_when_project_identifier_is_not_updated
    with_new_project(:identifier => 'foo') do |project|
      project.cards_table = "blah"
      project.card_versions_table = "barf"
      project.name = "new name"
      project.save!
      project.reload
      assert_equal "blah", project.cards_table
      assert_equal "barf", project.card_versions_table
    end
  end

  def test_rebuild_card_murmur_links_should_delete_all_murmur_card_links
    CardMurmurLink.delete_all
    card = create_card!(:name => 'I am an new card')
    murmur = create_murmur(:author => @member, :murmur => "murmur for ##{card.number}")
    link = CardMurmurLink.create(:card => card, :murmur => murmur, :project_id => @project.id)
    @project.rebuild_card_murmur_links
    assert_equal [], CardMurmurLink.all
  end

  def test_events_should_be_in_order_of_id_if_timestamp_is_same
    with_project_without_cards do |project|
      first_event = create_card!(:name => 'first').versions.last.event
      second_event = create_card!(:name => 'second').versions.last.event
      third_event = create_card!(:name => 'third').versions.last.event
      t = 1.day.ago
      set_event_timestamp(first_event, t)
      set_event_timestamp(second_event, t)
      set_event_timestamp(third_event, t)

      assert_equal [first_event, second_event, third_event], project.events
    end
  end

  def test_last_activity_for_export_should_return_the_timestamp_for_latest_event
    with_project_without_cards do |project|
      first_event = create_card!(:name => 'first').versions.last.event
      second_event = create_card!(:name => 'second').versions.last.event
      third_event = create_card!(:name => 'third').versions.last.event

      first_event.update_attributes(:created_at => "24 Jul 2017 11:00 UTC")
      second_event.update_attributes(:created_at => "21 Jul 2018 12:00 UTC")
      third_event.update_attributes(:created_at => "14 Nov 2017 1:00 UTC")

      assert_equal second_event.created_at, project.last_activity_for_export
    end
  end

  def test_last_activity_for_export_should_return_the_updated_at_for_project_when_there_are_no_events
    with_project_without_cards do |project|
      assert_equal project.updated_at, project.last_activity_for_export
    end
  end

  def test_older_events_come_first
    with_project_without_cards do |project|
      first_event = create_card!(:name => 'first').versions.last.event
      second_event = create_card!(:name => 'second').versions.last.event
      third_event = create_card!(:name => 'third').versions.last.event

      set_event_timestamp(first_event, 1.day.ago)
      set_event_timestamp(second_event, 2.days.ago)
      set_event_timestamp(third_event, 3.days.ago)

      assert_equal [third_event, second_event, first_event], project.events
    end
  end

  def test_varchar255_attributes_are_limited_to_255
    [:time_zone, :name, :secret_key, :email_sender_name, :date_format, :auto_enroll_user_type, :cards_table, :card_versions_table].each do |attr|
      project = Project.new(attr => "a" * 256)
      assert project.invalid?
      assert project.errors[attr].present?
    end
  end

  def test_email_address_limited_to_255
    project = Project.new(:email_address => "#{'a' * 250}@toobig.com")
    assert project.invalid?
    assert project.errors[:email_address].present?
  end

  def test_when_invalid_name_supplied_you_dont_get_validation_errors_on_unrelated_blank_attributes
    project = Project.new(:name => 'z' * 256)
    assert project.invalid?
    assert project.errors[:name].present?
    [:time_zone, :secret_key, :email_sender_name, :date_format, :auto_enroll_user_type, :cards_table, :card_versions_table].each do |attr|
      assert_nil project.errors[attr]
    end
  end

  def test_identifier_not_validated_when_name_not_present
    project = Project.new(:name => "")
    assert !project.valid?
    assert_equal ["Name can't be blank"], project.errors.full_messages
  end

  def test_identifier_format_not_validated_when_identifier_empty
    project = Project.new(:name => 'foo', :identifier => "")
    assert !project.valid?
    assert_equal ["Identifier can't be blank"], project.errors.full_messages
  end

  def test_project_can_have_a_landing_favorite
    with_new_project do |project|
      view = CardListView.construct_from_params(project, :name => "Story Wall", :style => 'grid')
      view.tab_view = true
      view.save!

      project.landing_tab = view.favorite
      project.save!

      assert_equal view.favorite.to_params, project.landing_tab.to_params

    end
  end

  def test_project_can_store_list_of_ordered_tab_identifiers
    @project.ordered_tab_identifiers = [1,2,3]
    assert @project.save
    assert_equal ['1','2','3'], @project.reload.ordered_tab_identifiers
  end

  def test_project_can_gsub_ordered_tab_identifiers_with_old_to_new_map
    @project.ordered_tab_identifiers = 'Overview,1,2,3'
    assert @project.save
    @project.gsub_ordered_tab_identifiers('1' => '2', '2' => '5', '3' => '3')
    assert @project.save
    assert_equal ['Overview', '2','5','3'], @project.reload.ordered_tab_identifiers
  end

  def test_admins_list_should_give_project_admins_list
    with_new_project(:name => 'foo') do |project|
      first_user = create_user!(:login => "first_user", :email => "first_user@email.com", :name => "first_user")
      second_user = create_user!(:login => "second_user", :email => "second_user@email.com", :name => "second_user")
      project.add_member(first_user, MembershipRole[:project_admin])
      project.add_member(second_user, MembershipRole[:project_admin])
      expected1 = {'project_name' => 'foo', 'admin_name' => 'second_user','email' =>'second_user@email.com'}
      expected2 = {'project_name' => 'foo', 'admin_name' => 'first_user', 'email' =>'first_user@email.com'}
      assert Project.admins_list.include?(expected1)
      assert Project.admins_list.include?(expected2)
    end
  end

  def test_all_selected_should_return_all_project_with_given_identifiers
    project_1 = create_project
    create_project
    project_3 = create_project

    projects_identifier = Project.all_selected([project_1.identifier, project_3.identifier]).map(&:identifier)

    projects_identifier.each do |identifier|
      assert_include identifier, [project_1.identifier, project_3.identifier]
    end
  end

  def test_export_dir_name_should_remove_non_word_characters
    project = create_project(name: 'proj/ $%with- @#nonword. chars')
    assert_equal 'proj_ _with- _nonword. chars', project.export_dir_name
  end

  protected

  def youngest_revision_returns_nil_when_no_revisions
    Revision.destroy_all(:project_id => @project.id)
    assert_nil @project.youngest_revision
  end

  def new_repos_config(project, options = {})
    config = SubversionConfiguration.create!({:project_id => project.id, :repository_path => "foorepository"}.merge(options))
    project.reload
    config
  end
end
