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

class CardTest < ActiveSupport::TestCase
  include TreeFixtures::PlanningTree
  include CardRankingTestHelper

  def setup
    @project = first_project
    @project.activate
    @member = login_as_member
  end

  def teardown
    cleanup_repository_drivers_on_failure
    Clock.reset_fake
  end

  def test_all_comments_does_not_load_all_card_versions
    card = @project.cards.find_by_number(1)
    card.add_comment(:content => 'The first comment')
    card.save!

    assert_false card.versions.loaded?

    assert_equal 1, card.all_comments.size
    assert_equal "The first comment", card.all_comments.first.content
    assert_false card.versions.loaded?
  end

  def test_comments_are_fetched_from_card_versions_if_they_are_loaded
    card = @project.cards.find_by_number(1)
    card.add_comment(:content => 'hey')
    card.save!

    card.versions.find_all
    assert card.versions.loaded?
    assert_equal "hey", card.comments.first.content
  end

  def test_revisions_in_should_be_empty_when_project_repository_is_deleted_even_there_is_revision_existing
    does_not_work_without_subversion_bindings do
      driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
        driver.commit_file_with_comment 'new_file.txt', 'some content', '#1 added new_file.txt for story 11'
      end

      configure_subversion_for(@project, {:repository_path => driver.repos_dir})
      recreate_revisions_for(@project)
      @project.delete_repository_configuration

      assert_equal [], @project.cards.find_by_number(1).revisions_in
    end
  end

  def test_should_not_load_all_versions_when_update
    card = @project.cards.find_by_number(1)
    assert !card.versions.loaded?
    card.name = "it's a little funky"
    card.save!
    assert !card.versions.loaded?
  end

  def test_number_assigned_on_creation
    card = create_card!(:name => "not so funky card")
    assert card.number >= 1
  end

  def test_get_revisions_without_revisions_match
    does_not_work_without_subversion_bindings do
      driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
        driver.commit_file_with_comment 'new_file.txt', 'some content', 'added new_file.txt for story 11'
        driver.commit_file_with_comment 'another_file.txt', 'more content', 'added another_file for story 1'
        driver.commit_file_with_comment 'third_file.txt', 'more more content', 'added third_file for # 1'
        driver.commit_file_with_comment 'fourth_file.txt', 'funky content', 'added 4th file for story card 1'
        driver.update_file_with_comment 'fourth_file.txt', 'funky content', 'added 1th file'
      end

      configure_subversion_for(@project, {:repository_path => driver.repos_dir})
      recreate_revisions_for(@project)
      revisions = @project.cards[1].reload.revisions
      assert_equal 2, revisions.size

      assert_equal 'added 4th file for story card 1', revisions[0].commit_message
      assert_equal 'added third_file for # 1', revisions[1].commit_message
    end
  end

  # bug 392
  def test_revision_linking
    does_not_work_without_subversion_bindings do
      @project.activate
      driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
        driver.commit_file_with_comment 'new_file.txt', 'some content', 'story 193: the tab  ... nished due to 100% CPU usa(on win32)'
      end
      configure_subversion_for(@project, {:repository_path => driver.repos_dir})

      card_100 = create_card!(:number => 100, :name => "test card")
      card_193 = create_card!(:number => 193, :name => "test card")
      @project.update_attributes(:card_keywords => "story")

      recreate_revisions_for(@project)

      assert_equal 0, card_100.revisions.size
      assert_equal 1, card_193.revisions.size
    end
  end

  def test_can_get_revisions_by_revisions_match
    does_not_work_without_subversion_bindings do
      driver = with_cached_repository_driver(name) do |driver|
        driver.initialize_with_test_data_and_checkout
        driver.commit_file_with_comment 'new_file.txt', 'some content', 'added new_file.txt for story 11'
        driver.commit_file_with_comment 'another_file.txt', 'more content', 'added another_file for story 1'
        driver.update_file_with_comment 'another_file.txt', 'update content', 'update another_file for story 1'
        driver.update_file_with_comment 'new_file.txt', 'update content', 'update file No.1 for story'
      end

      assert @project.update_attributes(:card_keywords => "story")
      configure_subversion_for(@project, {:repository_path => driver.repos_dir})
      recreate_revisions_for(@project)

      card = @project.reload.cards.find_by_number(1)
      assert_equal 2, card.revisions.size
    end
  end

  def test_add_tag
    card = @project.cards.find_by_number(1)
    card.add_tag 'rss'
    card.save!
    assert card.reload.tag_list.split(' ').include?('rss')
  end

  def test_add_tag_creates_tagging_with_position
    with_new_project do |project|
      card = project.cards.create!(:name => 'test card', :card_type_name => 'Card')
      card.add_tag("tag1")
      card.save!

      assert_equal 1, card.taggings.reload.size, "Should only have 1 tagging association. Instead, got #{card.taggings.size} taggings: #{card.taggings.map(&:inspect)}"
      assert_equal [1], card.taggings.map(&:position).sort

      card.add_tag("tag2")
      card.save!
      assert_equal [1, 2], card.taggings.reload.map(&:position).sort
    end
  end

  def test_remove_and_create_tag_incrementally_adds_positions
    with_new_project do |project|
      card = project.cards.create(:name => 'test card', :card_type_name => 'Card')
      card.tag_with(['tag1', 'tag2', 'tag3', 'tag4']).save!
      assert_equal [1, 2, 3, 4], card.taggings.map(&:position)

      card.remove_tag('tag2')
      card.add_tag('tag5')
      card.add_tag('tag6')
      card.save!
      assert_equal [1, 2, 3, 4, 5], card.reload.taggings.map(&:position)
      assert_equal ['tag1', 'tag3', 'tag4', 'tag5', 'tag6'], card.tags.map(&:name)
    end
  end

  def test_card_versions_have_tag_positions
    with_new_project do |project|
      card = project.cards.create(:name => 'test card', :card_type_name => 'Card')
      card.tag_with(['tag1', 'tag2', 'tag3', 'tag4']).save!
      assert_equal [1, 2, 3, 4], card.versions.last.taggings.map(&:position)

      card.remove_tag('tag4')
      card.remove_tag('tag3')
      card.add_tag('tag5')
      card.add_tag('tag6')
      card.save!

      assert_equal [1, 2, 3, 4], card.versions.last.taggings.map(&:position)
    end
  end

  def test_reorder_tag_positions
    with_new_project do |project|
      card = project.cards.create(:name => 'test card', :card_type_name => 'Card')
      card.tag_with(['tag1', 'tag2', 'tag3', 'tag4']).save!
      taggings = card.taggings
      new_order = ['tag3', 'tag1', 'tag2', 'tag4']
      card.reorder_tags(new_order)
      assert_equal ['tag3', 'tag1', 'tag2', 'tag4'], card.reload.tags.map(&:name)
    end
  end

  def test_reorder_tag_positions_when_initial_positions_are_zero
    with_new_project do |project|
      card = project.cards.create(:name => 'test card', :card_type_name => 'Card')
      tag1 = project.tags.create(:name => 'tag1')
      tag2 = project.tags.create(:name => 'tag2')
      tag3 = project.tags.create(:name => 'tag3')
      tag4 = project.tags.create(:name => 'tag4')
      card.taggings.create(:tag_id => tag1.id, :position => 0)
      card.taggings.create(:tag_id => tag2.id, :position => 0)
      card.taggings.create(:tag_id => tag3.id, :position => 0)
      card.taggings.create(:tag_id => tag4.id, :position => 1)

      taggings = card.taggings
      new_order = ['tag3', 'tag1', 'tag4', 'tag2']
      card.reorder_tags(new_order)
      assert_equal ['tag3', 'tag1', 'tag4', 'tag2'], card.reload.tags.map(&:name)
      assert_equal [1, 2, 3, 4], card.taggings.map(&:position).sort
    end
  end

  def test_can_handle_hooky_subversion_repo
    recreate_revisions_for(@project)
    assert_equal [], @project.cards.find_by_number(1).revisions
  end

  def test_can_retrieve_old_versions_of_a_card_including_its_tags_and_properties
    card = @project.cards.new
    card.project = @project

    card.name = 'First name'
    card.tag_with('rss')
    card.cp_iteration = '1'
    card.cp_status = 'new'
    card.card_type = @project.card_types.first
    card.save!
    assert_equal 1, card.version

    card.name = 'New name'
    card.cp_iteration = '2'
    card.cp_status = 'fixed'
    card.add_tag('funky')
    card.save!

    assert_equal 2, card.version

    version_1 = card.find_version(1)
    assert_equal 'First name', version_1.name
    assert_equal '1', version_1.cp_iteration
    assert_equal 'new', version_1.cp_status
    assert_equal 'rss', version_1.tag_list

    version_2 = card.find_version(2)
    assert_equal 'New name', version_2.name
    assert_equal '2', version_2.cp_iteration
    assert_equal 'fixed', version_2.cp_status
    assert_equal 'funky rss', version_2.tag_list
  end

  def test_can_add_tag_and_then_save
    requires_update_full_text_index do
      card = @project.cards.find_by_number(1)
      card.add_tag('a_complete_new_tag')
      card.add_tag('foo-bar')
      card.save!
      assert_equal 'a_complete_new_tag first_tag foo-bar', card.tag_list
    end
  end

  def test_export_attributes_should_get_values_for_all_header_columns
    card = @project.cards.find_by_number(1)
    card.tag_with('rss')
    card.cp_old_type = 'bug'
    card.save!
    assert_equal 'bug', card.cp_old_type
    assert_equal ['first card', 'bug', 'rss',"",""], card.export_attributes(['name', 'old_type'])
  end

  def test_should_know_created_by
    admin = User.find_by_login('admin')
    Thread.current[:user] = admin
    card = create_card!(:name => "new card")
    card.save!
    assert_equal "admin@email.com", card.reload.created_by.email
  end

  def test_card_version_should_be_modified_by_person_creating_the_version_not_the_person_that_modified_the_version_parent
    admin = User.find_by_login('admin')
    bob = User.find_by_login('bob')

    set_current_user(admin) do
      create_card!(:name=>'new_card', :number=>42)
    end
    assert_equal admin.id, @project.cards.find_by_number(42).modified_by.id

    set_current_user(bob) do
      card = @project.cards.find_by_number(42)
      card.description = 'here be description'
      card.save!
    end
    assert_equal bob.id, @project.cards.find_by_number(42).modified_by.id
    assert_equal admin.id, @project.cards.find_by_number(42).created_by.id
  end

  def test_updating_a_card_with_no_changes_should_not_create_new_version
    card = create_card!(:name => 'My card')
    assert_equal 1, card.versions.size

    card = Card.find(card.id)
    assert !card.altered?
    card.save!

    card = Card.find(card.id)
    assert_equal 1, card.versions.size

    card = Card.find(card.id)
    card.cp_iteration = '1'
    card.save!
    card = Card.find(card.id)
    assert_equal 2, card.versions.size
  end

  def test_taggability_by_special_chars
    card = @project.cards.find_by_number(1)
    card.tag_with("ugly_tag_more\r\ncontent")
    assert card.errors.empty?
  end

  def test_set_custom_property_with_special_chars
    @project.find_property_definition("some property").update_attributes(:restricted => false)

    card = @project.cards.find_by_number(1)
    card.cp_some_property = "ugly\r\nvalue"
    card.save!
    assert_equal "ugly value", card.reload.cp_some_property
  end

  def test_attach_files_will_generate_new_card_version
    card = create_card!(:name => "card for testing attachment version")
    assert_equal 1, card.versions.size
    card.attach_files(sample_attachment("1.gif"))
    card.save!
    assert_equal 2, card.reload.versions.size
    card.attach_files(sample_attachment("2.gif"))
    assert_equal 2, card.attachments.size
    card.save!
    assert_equal 3, card.reload.versions.size
    assert_equal 2, card.reload.attachments.size
    assert_equal 2, card.reload.versions.last.attachments.size
  end

  def test_attachments_will_copyed_to_versions
    card = create_card!(:name => "card for testing attachment version")
    card.attach_files(sample_attachment("1.gif"))
    card.save!
    card.attach_files(sample_attachment("2.gif"))
    card.save!
    assert_equal 3, card.reload.versions.size
    assert_equal 2, card.attachments.size
    assert_equal 0, card.versions[0].attachments.size
    assert_equal 1, card.versions[1].attachments.size
    assert_equal 2, card.versions[2].attachments.size
  end

  def test_card_version_should_keep_attachment_urls
    card = create_card!(:name => "card for testing attachment version")
    card.attach_files(sample_attachment)
    card.save!
    card.reload
    assert_equal card.attachments.first.url, card.versions.last.attachments.first.url
  end

  def test_should_be_able_to_delete_attachments_from_cards
    card = create_card!(:name => "card for testing attachment version")
    card.attach_files(sample_attachment)
    card.save!
    assert_equal 1, card.reload.attachments.size
    assert_equal 2, card.versions.size

    card.remove_attachment(card.attachments.first.file_name)
    card.save!

    assert_equal 0, card.reload.attachments.size
    assert_equal 3, card.versions.size
  end

  def test_should_not_be_able_to_delete_attachments_from_old_card_versions
    card = create_card!(:name => "card for testing attachment version")
    card.attach_files(sample_attachment)
    card.save!
    assert_equal 1, card.reload.attachments.size
    assert_equal 2, card.versions.size

    older_version = card.versions.last

    card.remove_attachment(card.attachments.first.file_name)
    card.description = "new description"
    card.save!

    assert_raise RuntimeError do
      older_version.remove_attachment(older_version.attachments.first.file_name)
    end
  end

  def test_update_against_no_changes_will_not_generate_new_card_version
    card = create_card!(:name => "card for testing attachment version")
    card.attach_files(sample_attachment)
    card.save!
    assert_equal 2, card.reload.versions.size
    card.save!
    assert_equal 2, card.reload.versions.size
  end

  def test_remove_tag
    card = create_card!(:name => 'test card')
    card.tag_with(['first', 'second'])
    card.save!
    card.remove_tag('first')
    assert_equal 'second', card.tag_list
    card.remove_tag('not tagged with this one')
    assert_equal 'second', card.tag_list
    card.remove_tag('second')
    assert_equal '', card.tag_list
    card.remove_tag('should not fail without tags')
  end

  def test_tags_not_represented_in_returns_tags_in_self_but_not_in_the_other
    card1 = create_card!(:name => 'card1')
    card1.tag_with('rss, foobar').save!
    card2 = create_card!(:name => 'card2')
    card2.tag_with('foobar, funky').save!
    assert_equal ['funky'], card2.tags_not_represented_in(card1)
    assert_equal ['rss'], card1.tags_not_represented_in(card2)
  end

  def test_should_not_create_version_if_two_differnt_users_both_make_no_changes
    bob = User.find_by_login 'bob'
    longbob = User.find_by_login 'longbob'

    set_current_user(bob) do
      card = create_card!(:name => 'interesting card', :description => 'rather delightful description')
      assert_equal 1, card.versions.size
      card.save!
      assert_equal 1, card.reload.versions.size
    end
    set_current_user(longbob) do
      card = @project.cards.find_by_name('interesting card')
      assert_equal 1, card.versions.size
      card.save!
      assert_equal 1, card.reload.versions.size
    end
  end

  def test_color_delegates_to_property_definition
    status_property_def = @project.find_property_definition('status')
    status_property_def.find_enumeration_value('new').update_attribute :color, '#ABC'

    card = create_card!(:name => 'a card')
    assert_nil card.color(status_property_def)
    assert_nil card.color('status')

    card.cp_status = 'new'
    assert_equal '#ABC', card.color(status_property_def)
    assert_equal '#ABC', card.color('status')
  end

  def test_knows_latest
    card = create_card!(:name => 'card with versions');
    assert card.latest_version?
    card.tag_with('rss').save!
    assert !card.reload.versions.first.latest_version?
    assert card.latest_version?
  end

  def test_property_definitions_with_values
    card1 = create_card!(:name => 'my first card')
    card1.cp_status = 'open'
    card1.cp_priority = 'high'

    defs_with_value = card1.property_definitions_with_value
    assert_equal 2, defs_with_value.size
    assert_equal 'Priority', defs_with_value[0].name
    assert_equal 'Status', defs_with_value[1].name
  end

  def test_cannot_set_property_to_value_not_in_enumeration_values
    @project.find_property_definition('iteration').update_attributes(:restricted => true)
    @project.find_property_definition('Property without values').update_attributes(:restricted => true)
    @project.all_property_definitions.reload

    card1 = create_card!(:name => 'my first card')
    card1.cp_property_without_values = 'open'
    card1.cp_iteration = '12'

    assert !card1.save
    assert_equal "#{'Iteration'.bold} is restricted to #{'1'.bold} and #{'2'.bold}", card1.errors.full_messages[0]
    assert_equal "#{'Property without values'.bold} does not have any defined values", card1.errors.full_messages[1]
  end

  def test_update_properties_should_treat_blank_values_as_null
    card = create_card!(:name => 'my first card')
    card.update_properties('status' => 'fixed', 'iteration' => '')
    card.save!
    assert_equal nil, card.reload.cp_iteration
  end

  def test_should_not_add_new_enumerated_property_value_when_update_property_which_is_restricted
    card = create_card!(:name => 'new card')
    status = @project.find_property_definition(:status)
    status.update_attribute(:restricted, true)

    card.update_properties(:status => 'new status')
    card.save

    assert !card.errors.empty?
    assert_nil card.reload.cp_status
  end

  def test_should_add_enumerated_property_values_when_update_properties_with_new_enumerated_property_value
    card = create_card!(:name => 'my first card')
    card.update_properties('status' => 'new status')
    card.save!
    assert_equal 'new status', card.reload.cp_status
  end

  def test_should_be_case_insensitive_when_update_properties_with_new_enumerated_property_value
    card = create_card!(:name => 'my first card')
    card.update_properties('status' => 'new status')
    card.save!
    card.update_properties('status' => 'NEW STATUS')
    card.save!
    assert_equal 'new status', card.reload.cp_status
  end

  def test_cards_properties_should_include_all_property_for_card_type_of_card
    status = @project.find_property_definition('status')
    iteration = @project.find_property_definition('iteration')
    release = @project.find_property_definition('release')
    story_type = @project.card_types.create :name => 'story'
    story_type.add_property_definition status

    card = create_card!(:name => 'my first card', :status => 'fixed', :release => '1', :card_type => story_type)
    assert_include status.property_value_from_db('fixed'), card.property_values
    assert_not_include release.property_value_from_db('1'), card.property_values
    assert_not_include iteration.property_value_from_db('1'), card.property_values
  end

  def test_get_property_value_with_property_definition
    card  = create_card!(:name => 'card1', :stage => '25')
    assert_equal '25', card.property_value(@project.find_property_definition('stage')).display_value
  end

  def test_get_property_value_with_property_definition_name
    card  = create_card!(:name => 'card1', :stage => '25')
    assert_equal '25', card.property_value('stage').display_value
  end


  def test_should_strip_card_name_and_properties
    assert_equal 'moo', @project.cards.new(:name => "   moo   ").name
    assert_equal 'moo', @project.cards.new(:cp_status => "   moo   ").cp_status
  end

  def test_trailing_white_space_should_be_strip_for_description
    card = @project.cards.new(:description => "   cow   ")
    assert_equal '   cow', card.description
    multiline_description = "h3. As a\n\np(. regional sales manager\n\nh3. I want to\n\np(. see my sales history\n\nh3. So that\n\np(. I know if I am meeting my targets"
    card.description = multiline_description
    assert_equal multiline_description, card.description
  end

  def test_property_summary_should_get_user_name_when_the_enum_value_is_a_user
    member = User.find_by_login('member')
    create_project(:users => [member]) do |project|
      setup_property_definitions(:status =>['open'] )
      setup_user_definition('owner')

      card = create_card!(:name => 'This is my first card')
      card.update_attribute('cp_owner', member)
      assert_equal ["owner: #{member.name}"], card.property_summary

      card = create_card!(:name => 'This is my second card')
      card.update_attribute('cp_status','open')
      assert_equal ['status: open'], card.property_summary
    end
  end

  def test_display_value_of_card
    member = User.find_by_login('member')
    create_project(:users => [member]) do |project|
      owner = setup_user_definition('owner')
      card = create_card!(:name => 'This is my first card')
      assert_equal PropertyValue::NOT_SET, card.display_value(owner)
      card.update_attribute(:cp_owner, member)
      assert_equal member.name, card.display_value(owner)
    end
  end

  def test_should_delete_all_card_subscriptions_on_card_delete
    subscribed_card = create_card!(:name => 'subscribed')
    @project.create_history_subscription(User.find_by_login('member'), HistoryFilterParams.new(:card_number => subscribed_card.number).serialize)
    subscriptions_before_card_delete = @project.history_subscriptions.size
    subscribed_card.destroy
    subscriptions_after_card_delete = @project.reload.history_subscriptions.size
    assert_equal 1, subscriptions_before_card_delete - subscriptions_after_card_delete
  end

  def test_destroy_removes_taggings_for_card
    card = create_card!(:name => 'timmy')
    card.tag_with('rss')
    card.save!
    card.tag_with('adam')
    card.save!
    versions = card.versions.to_a
    card.destroy

    assert_equal [], @project.connection.select_all("SELECT * FROM #{Tagging.table_name} WHERE taggable_id = #{card.id} AND taggable_type='Card'")
  end

  def test_property_definitions_through_card_type
    with_new_project do |project|
      setup_property_definitions :status => ['new'], :size => [1, 2]
      card_type = project.card_types.create :name => 'new card type'
      card = create_card!(:name => 'card 1', :card_type => card_type)
      assert_equal 0, card.card_type.property_definitions.size
      assert_equal card.property_definitions, card.card_type.property_definitions

      status_def = project.find_property_definition 'status'
      size_def = project.find_property_definition 'size'

      card_type.add_property_definition status_def
      card_type.save!
      card.reload.clear_cached_results_for :card_type
      project.reload

      assert_equal 1, card.card_type.property_definitions.size
      assert_equal card.property_definitions, card.card_type.property_definitions

      card_type.add_property_definition size_def
      card_type.save!
      card.reload.clear_cached_results_for :card_type
      project.reload

      assert_equal 2, card.card_type.property_definitions.size
      assert_equal card.property_definitions, card.card_type.property_definitions
    end
  end

  def test_property_definitions_through_card_type_should_not_contain_hidden_property
    with_new_project do |project|
      setup_property_definitions :status => ['new'], :size => [1, 2]
      status_def = project.find_property_definition 'status'
      size_def = project.find_property_definition 'size'
      size_def.update_attribute :hidden, true

      card_type = project.card_types.create! :name => 'new card type'
      card_type.property_definitions = [status_def, size_def]
      card = create_card!(:name => 'card 1', :card_type => card_type)

      card.reload
      project.reload

      assert_equal [status_def.name], card.property_definitions.collect(&:name)
    end
  end

  def test_can_tell_contain_hidden_properties
    card = @project.cards.first
    assert !card.contain_hidden_properties?

    status = @project.find_property_definition('status')
    status.update_attribute(:hidden, true)

    assert card.reload.contain_hidden_properties?, "card should have hidden properties"
  end

  def test_must_have_card_type_name
    card = Card.new(:name => 'card 1', :project_id => @project.id)
    assert !card.save
    assert card.errors.invalid?('card_type_name')
  end

  def test_must_have_a_valid_card_type_name
    card = Card.new(:name => 'card 1', :project_id => @project.id, :card_type_name => 'nobody knows')
    assert !card.save
    assert card.errors.full_messages.include?("Card type nobody knows does not exist in project #{@project.name}.")
  end

  def test_should_normalize_card_type_name_for_case
    @project.card_types.create!(:name => 'CamelCase')
    card = create_card!(:name => 'card 1', :card_type_name => 'camelcase')
    assert_equal 'CamelCase', card.reload.card_type_name
  end

  def test_update_properties_ignores_non_existant_properties_and_existing_property_still_set
    card = @project.cards[0]
    assert_nil @project.find_property_definition_or_nil('doesnotexist')
    new_properties = {:name => 'A new name', :doesnotexist => 'foo'}
    card.update_properties(new_properties)
    assert_equal 'A new name', card.name
  end

  def test_should_signal_errors_on_setting_bad_values_for_date_properties
    card = @project.cards.first
    card.update_properties('start date' => 'Jlats')
    assert_equal "start date: #{'Jlats'.bold} is an invalid date. Enter dates in #{'dd mmm yyyy'.bold} format or enter existing project variable which is available for this property.", card.errors.full_messages.join
  end

  def test_saves_whether_card_has_macros
    has_macro = @project.cards.create!(:name => 'Has macro', :card_type_name => 'Card', :description => '{{ value query: SELECT SUM(Release) }}')
    no_macro = @project.cards.create!(:name => 'No macro', :card_type_name => 'Card', :description => '[Link]')

    assert has_macro.has_macros?
    assert !no_macro.has_macros?

    has_macro.update_attribute(:description, '[[Link]]')
    no_macro.update_attribute(:description, '{{ value query: SELECT SUM(Release) }}')

    assert !has_macro.has_macros?
    assert no_macro.has_macros?
  end

  def test_properties_not_belonging_to_type_are_set_to_nil_after_type_change
    story = @project.card_types.create(:name => 'story')
    story.add_property_definition @project.find_property_definition('status')
    iteration = @project.find_property_definition('iteration')
    story.add_property_definition iteration
    iteration.update_attribute(:hidden, true)
    bug = @project.card_types.create(:name => 'bug')
    bug.add_property_definition  @project.find_property_definition('assigned')
    bug.add_property_definition  @project.find_property_definition('release')

    @project.reload

    card = @project.cards.first
    card.update_attributes(:card_type_name => 'story', :cp_status => 'new', :cp_iteration => '1')

    card.card_type_name = 'bug'
    card.cp_assigned = 'jen'
    card.cp_release = '1'
    card.save!
    card.reload
    assert_nil card.cp_status
    assert_nil card.cp_iteration
    assert_equal 'jen', card.cp_assigned
    assert_equal '1', card.cp_release

    properties_removed = card.properties_removed_as_not_applicable_to_card_type.sort_by{|prop| prop.property_definition.name}
    assert_equal 'Iteration', properties_removed[0].name
    assert_equal '1', properties_removed[0].display_value
    assert_equal 'Status', properties_removed[1].name
    assert_equal 'new', properties_removed[1].display_value
  end

  def test_set_not_applicable_properties_to_nil_bypasses_transition_only_protection
    story = @project.card_types.create(:name => 'story')
    status = @project.find_property_definition('status')
    status.update_attribute(:transition_only, true)
    story.add_property_definition status
    @project.card_types.create(:name => 'bug')
    @project.reload

    card = @project.cards.create!(:name => 'a card', :card_type_name => 'story', :cp_status=> 'new')
    card.update_attribute(:card_type_name, 'bug')
    assert_nil card.reload.cp_status
  end

  def test_should_not_update_property_which_is_transition_only
    story = @project.card_types.create(:name => 'story')
    status = @project.find_property_definition('status')
    status.update_attribute(:transition_only, true)
    status.save!
    story.add_property_definition status

    card = @project.cards.create!(:name => 'a card', :card_type_name => 'story', :cp_status=> 'new')
    card.update_properties({:status => 'open'})
    assert_equal ['Status: is a transition only property.'], card.errors.full_messages
  end

  def test_should_be_able_to_validate_name_using_db_validations
    test_card = @project.cards.create!(:name => 'test', :card_type_name => 'Card')
    long_name = (['a'] * 300).join
    test_card.update_attributes(:name => long_name, :cp_status => long_name)
    assert test_card.errors.full_messages.include?("Name is too long (maximum is 255 characters)")
    assert test_card.errors.full_messages.include?("Status's value is too long (maximum is 255 characters)")

    # test the happy path too, esp. for Oracle's sake
    long_but_valid_name = (['a'] * 255).join
    test_card.update_attributes(:name => long_but_valid_name, :cp_status => long_but_valid_name)
    assert_equal [], test_card.errors.full_messages
  end

  # bug 6308
  def test_name_of_attribute_should_match_hashed_property_definition_column_name
    with_new_project do |project|
      pd = setup_allow_any_text_property_definition 'long name property aaaaaaaaaaaaaaaaaaaaa'
      quoted_name = Card.connection.quote_column_name('cp_long_name_property_aaaaaaaaaaaaaaaaaaaaa')
      card1 = create_card!(:name => 'card one')

      assert_equal "#{pd.name}'s value", card1.name_of_attribute(quoted_name)
    end
  end

  def test_card_should_be_able_to_represent_the_layout_of_the_view
    ['new', 'open', 'closed'].each {|status| @project.cards.create!(:name => "#{status} card", :cp_status => status, :card_type_name => 'Card')}
    grid_of_cards_grouped_by_status = CardListView.find_or_construct(@project, :filters => ['[Type][is][Card]'], :group_by => 'Status')
    assert_equal ['(not set)', 'closed', 'new', 'open'], grid_of_cards_grouped_by_status.group_lanes.visibles(:lane).collect(&:title).sort

    closed_card = @project.cards.find_by_name('closed card')
    closed_card_view_as_reached_from_grid = closed_card.view_from(grid_of_cards_grouped_by_status)
    assert_equal ['(not set)', 'closed', 'new', 'open'], closed_card_view_as_reached_from_grid.group_lanes.visibles(:lane).collect(&:title).sort
  end

  def test_should_update_formula_properties_when_saving
    with_new_project do |project|
      setup_numeric_text_property_definition('Release')
      setup_formula_property_definition('Next Release', 'Release + 1')

      card = project.cards.create!(:name => 'Next Release Advisory', :card_type_name => 'Card', :cp_release => '1')
      assert_equal '1', card.cp_release
      assert_equal '2', card.cp_next_release
      card.cp_release = '2'
      card.save!
      assert_equal '3', card.cp_next_release
    end
  end

  def test_should_give_difference_in_days_between_two_dates_as_result_of_subtracting_to_date_properties
    with_new_project do |project|
      setup_date_property_definition 'start date'
      setup_date_property_definition 'end date'
      @project.reload
      duration = setup_formula_property_definition('duration in days', "'end date' - 'start date'")

      card = project.cards.create!(:name => 'card one', :card_type_name => project.card_types.first.name, :cp_start_date => '2001-09-07', :cp_end_date => '2001-09-10')
      assert_equal '3', card.cp_duration_in_days
    end
  end

  def test_should_be_able_to_generate_system_generated_comments_for_cards
    card = @project.cards.first
    version_before_save = card.version
    card.system_generated_comment = 'You has system generated comment'
    card.save!
    version_after_save = card.reload.version
    assert_equal version_after_save, (version_before_save + 1)
  end

  def test_should_not_be_able_to_set_values_for_formula_properties_directly
    with_new_project do |project|
      release = setup_numeric_text_property_definition('release')
      next_release = setup_formula_property_definition('next release', "release + 1")

      card_one = project.cards.create!(:name => 'Card One', :card_type_name => project.card_types.first.name, :cp_release => '41')
      assert_equal 42, next_release.value(card_one)

      ['rubbish', 1, '1'].each do |non_calculated_value|
        card_one.update_properties('next release' => non_calculated_value)
        assert_equal 42, next_release.value(card_one)
      end
    end
  end

  def test_method_missing_writes_and_reads_user_properties
    card = @project.cards.first
    assert !card.respond_to?(:cp_dev)
    assert_nil card.cp_dev
    bob = User.find_by_login('bob')
    card.cp_dev = bob
    assert_equal bob, card.cp_dev
  end

  def test_method_missing_writes_and_reads_card_properties
    with_new_project do |project|
      setup_card_property_definition('linked to', project.card_types.first)
      first_card = project.cards.create(:name => 'first card', :card_type_name => 'Card')
      second_card = project.cards.create(:name => 'second card', :card_type_name => 'Card')
      assert !first_card.respond_to?(:cp_linked_to)
      assert_nil first_card.cp_linked_to
      first_card.cp_linked_to = second_card
      assert_equal second_card, first_card.cp_linked_to
    end
  end

  def test_change_card_type_should_move_card_directly_beneath_root_of_its_belonging_tree
    create_planning_tree_project do |project, tree, config|
      iteration1 = project.cards.find_by_name('iteration1')
      iteration1.update_properties('type' => 'story')
      iteration1.save!
      iteration1.reload
      assert config.include_card?(iteration1)
      assert_equal ['Planning'], iteration1.tree_configurations.collect(&:name)
      assert_equal ['story1', 'story2', 'story3'], config.create_tree.find_node_by_name('release1').children.collect(&:name).sort
      assert_nil project.cards.find_by_name('story1').cp_planning_iteration_card_id
      assert_nil iteration1.cp_planning_release_card_id
      assert_nil iteration1.cp_planning_iteration_card_id
    end
  end
  def test_previous_version_or_nil
    release = @project.find_property_definition('Release')
    card = @project.cards.first
    release.update_card(card, '3')
    card.save!
    release.update_card(card, '4')
    card.save!
    assert_equal '3', release.value(card.previous_version_or_nil)

    card = @project.cards.create(:name => 'new card', :card_type => @project.card_types.first)
    assert_nil card.previous_version_or_nil
  end

  def test_move_leaf_card_by_updating_properties_with_tree_relationship_property
    create_tree_project(:init_three_level_tree) do |project, tree, config|
      @story1 = project.cards.find_by_name('story1')
      @iteration2 = project.cards.find_by_name("iteration2")
      @type_iteration = project.card_types.find_by_name('iteration')

      @story1.update_properties({config.tree_relationship_name(@type_iteration) => @iteration2.id})
      @story1.save

      assert_equal 'release1', @story1.cp_planning_release.name
      assert_equal 'iteration2', @story1.cp_planning_iteration.name
    end
  end


  # bug 3748
  def test_should_be_able_to_determine_if_a_card_can_have_children_or_not_in_mutiple_trees
    create_tree_project(:init_three_level_tree) do |project, tree, config|
      type_release , type_iteration, type_story = find_planning_tree_types
      type_issue = project.card_types.create(:name =>'issue')

      signoff_config = project.tree_configurations.create!(:name => 'sign-off issues tree')
      signoff_config.update_card_types({
                                         type_story => {:position => 0, :relationship_name => 'story for sign off'},
                                         type_issue => {:position => 1, :relationship_name => 'sign off issue'}
      })

      story1 = project.cards.find_by_name('story1')
      assert !story1.can_have_children?(config)
      assert !story1.can_have_children?(signoff_config)
    end
  end

  ##################################################################
  #                                     Planning tree
  #                             -------------|---------
  #                            |                      |
  #                    ----- release1----           release2
  #                   |                 |             |
  #            ---iteration1----    iteration2    iteration3
  #           |                |                      \
  #       story1            story2                [story1]
  #         \-----------------------------------------/
  ##################################################################
  def test_move_leaf_card_by_updating_properties_with_tree_relationship_property2
    create_tree_project(:init_two_release_planning_tree) do |project, tree, config|
      @story1 = project.cards.find_by_name('story1')
      @iteration3 = project.cards.find_by_name("iteration3")
      @type_iteration = project.card_types.find_by_name('iteration')

      @story1.update_properties({config.tree_relationship_name(@type_iteration) => @iteration3.id})
      @story1.save!

      assert_equal 'release2', @story1.cp_planning_release.name
      assert_equal 'iteration3', @story1.cp_planning_iteration.name
    end
  end

  def test_should_update_all_children_cards_while_updating_and_saving_properties_of_sub_tree
    create_tree_project(:init_two_release_planning_tree) do |project, tree, config|
      @iteration1 = project.cards.find_by_name('iteration1')
      @release2 = project.cards.find_by_name("release2")
      @type_release = project.card_types.find_by_name('release')

      @iteration1.update_properties({config.tree_relationship_name(@type_release) => @release2.id})
      @iteration1.save

      assert_equal 'release2', @iteration1.cp_planning_release.name
      assert_nil @iteration1.cp_planning_iteration

      @story1 = project.cards.find_by_name('story1')
      assert_equal 'release2', @story1.cp_planning_release.name
      assert_equal 'iteration1', @story1.cp_planning_iteration.name

      @story2 = project.cards.find_by_name('story2')
      assert_equal 'release2', @story2.cp_planning_release.name
      assert_equal 'iteration1', @story2.cp_planning_iteration.name
    end
  end

  def test_should_update_all_children_cards_while_updating_and_saving_properties_of_sub_tree2
    create_tree_project(:init_two_release_planning_tree) do |project, tree, config|
      @iteration1 = project.cards.find_by_name('iteration1')
      @release2 = project.cards.find_by_name("release2")
      @type_release = project.card_types.find_by_name('release')

      config.find_relationship(@type_release).update_card(@iteration1, @release2.id)
      @iteration1.save

      assert_equal 'release2', @iteration1.cp_planning_release.name
      assert_nil @iteration1.cp_planning_iteration

      @story1 = project.cards.find_by_name('story1')
      assert_equal 'release2', @story1.cp_planning_release.name
      assert_equal 'iteration1', @story1.cp_planning_iteration.name

      @story2 = project.cards.find_by_name('story2')
      assert_equal 'release2', @story2.cp_planning_release.name
      assert_equal 'iteration1', @story2.cp_planning_iteration.name
    end
  end

  def test_should_not_reset_values_of_child_properties_when_value_of_a_parent_property_is_not_changed
    create_tree_project(:init_two_release_planning_tree) do |project, tree, config|
      @release1 = project.cards.find_by_name("release1")
      @type_release = project.card_types.find_by_name('release')
      @story1 = project.cards.find_by_name('story1')
      @story2 = project.cards.find_by_name('story2')

      assert_equal ['release1', 'iteration1'], [@story1.cp_planning_release, @story1.cp_planning_iteration].collect(&:name)
      assert_equal ['release1', 'iteration1'], [@story2.cp_planning_release, @story2.cp_planning_iteration].collect(&:name)

      @story1.update_properties({config.tree_relationship_name(@type_release) => @release1.id})
      @story1.save
      @story2.reload

      assert_equal ['release1', 'iteration1'], [@story1.cp_planning_release, @story1.cp_planning_iteration].compact.collect(&:name)
      assert_equal ['release1', 'iteration1'], [@story2.cp_planning_release, @story2.cp_planning_iteration].compact.collect(&:name)
    end
  end

  def test_should_have_error_after_updated_card_with_inconsistent_tree_values
    create_tree_project(:init_two_release_planning_tree) do |project, tree, config|
      @release2 = project.cards.find_by_name('release2')
      @iteration2 = project.cards.find_by_name('iteration2')
      @story1 = project.cards.find_by_name('story1')
      @type_release = project.card_types.find_by_name("release")
      @type_iteration = project.card_types.find_by_name("iteration")

      @release_relationship = config.find_relationship(@type_release)
      @iteration_relationship = config.find_relationship(@type_iteration)

      @release_relationship.update_card(@story1, @release2.id)
      @iteration_relationship.update_card(@story1, @iteration2.id)

      release2_display = "##{@release2.number} #{@release2.name}".bold
      iteration2_display = "##{@iteration2.number} #{@iteration2.name}".bold

      assert !@story1.valid?
      assert_equal "Suggested location on tree #{config.name.bold} is invalid.Cannot have #{@release_relationship.name.bold} as #{release2_display} and #{@iteration_relationship.name.bold} as #{iteration2_display} at the same time.", @story1.errors.full_messages.join
    end
  end

  def test_should_allow_destroy_card_when_card_belongs_to_a_tree
    create_tree_project(:init_three_level_tree) do |project, tree, config|
      story1 = project.cards.find_by_name("story1")

      assert story1.destroy
      assert story1.errors.empty?
      assert !project.cards.find_by_id(story1.id)
      assert !config.reload.tree_belongings.find_by_card_id(story1.id)
    end
  end

  def test_should_allow_destroy_card_when_card_belongs_to_a_tree_for_bulk_destroy
    create_tree_project(:init_three_level_tree) do |project, tree, config|
      story2 = project.cards.find_by_name("story2")
      selection = CardSelection.new(project, [story2])
      assert selection.destroy
      assert selection.errors.empty?
      assert_nil config.reload.tree_belongings.find_by_card_id(story2.id)
    end
  end

  def test_card_property_definitions_without_tree
    with_new_project do |project|
      setup_property_definitions 'status' => ['open', 'close']
      size = setup_numeric_property_definition 'size', ['1', '2']
      type_release,type_iteration,type_story = init_planning_tree_types
      type_story.add_property_definition(size)
      type_story.save!
      tree = create_three_level_tree
      story1= project.cards.find_by_name('story1')
      assert_equal ['size'].sort, story1.property_definitions_without_tree.collect(&:name).sort

      setup_aggregate_property_definition('sum size', AggregateType::SUM, size, tree.configuration.id, type_release.id, AggregateScope::ALL_DESCENDANTS)
      release1 = project.cards.find_by_name('release1')
      assert_equal [],release1.property_definitions_without_tree.collect(&:name)
    end

  end

  def test_available_tree_configurations
    with_new_project do |project|
      type_release,type_iteration,type_story = init_planning_tree_types
      tree = create_three_level_tree

      new_story = create_card!(:name => 'I am a new story', :card_type => type_story)
      assert_equal [], new_story.tree_configurations
      assert_equal [tree.name], new_story.available_tree_configurations.collect(&:name)
    end
  end

  def test_property_values_grouped_by_tree_configuration
    with_new_project do |project|
      size = setup_numeric_property_definition('size', [1, 2])
      priority = setup_text_property_definition('priority')
      type_release,type_iteration,type_story = init_planning_tree_types
      type_story.add_property_definition(size)
      type_story.add_property_definition(priority)
      type_story.save!
      tree = create_three_level_tree
      story1= project.cards.find_by_name('story1')
      story1.update_attributes(:cp_size => 2, :cp_priority => 'high')
      property_groups = story1.grouped_properties_with_value
      assert_equal 2, property_groups.size
      assert_nil property_groups.first.name
      assert_equal ['size', 'priority'], property_groups.first.properties.collect(&:name)

      assert_equal tree.name, property_groups[1].name
      assert_equal ['Planning release', 'Planning iteration'], property_groups[1].properties.collect(&:name)
    end
  end

  # bug3324
  def test_grouped_properties_with_value_should_show_card_type_if_it_is_no_any_property_definition
    with_new_project do |project|
      card1 = create_card!(:name => 'card1')
      assert_equal [OpenStruct.new(:name => nil, :properties => [])], card1.grouped_properties_with_value
    end
  end

  def test_should_convert_tab_character_to_single_space_when_card_save
    card = create_card!(:name => 'I am card with tab character', :description => "I am description\twith tab character")
    assert_equal "I am description with tab character", card.reload.description
  end


  def test_should_not_show_changes_if_we_do_nothing
    card = create_card!(:name => 'card for test do nothing')
    versions_before_change = card.versions.size
    card.save!
    versions_after_change = card.reload.versions.size
    assert_equal 0, versions_after_change - versions_before_change
  end

  def test_comment_will_create_card_version
    card = @project.cards.first

    versions_before_change = card.versions.size
    card.add_comment :content => "say something"
    versions_after_change = card.reload.versions.size

    assert_equal 1, versions_after_change - versions_before_change
  end

  # bug 4602
  def test_card_type_change_should_not_result_in_removal_from_tree_if_new_type_is_valid_for_tree
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.first
      planning_iteration = project.find_property_definition('Planning iteration')
      planning_release = project.find_property_definition('Planning release')

      release1 = project.cards.find_by_name('release1')
      iteration1 = project.cards.find_by_name('iteration1')
      story1 = project.cards.find_by_name('story1')

      iteration1.update_properties({"Planning release" => release1.number.to_s, "Planning iteration" => "", "Type" => "Story"})
      iteration1.save!

      assert tree_configuration.include_card?(iteration1)
      assert_nil planning_iteration.value(iteration1)
      assert_equal 'release1', planning_release.value(iteration1).name

      assert tree_configuration.include_card?(story1.reload)
      assert_equal 'release1', planning_release.value(story1).name
      assert_nil planning_iteration.value(story1)
    end
  end

  # bug 4602
  def test_card_type_change_that_does_not_specify_relationship_values_should_result_in_relationships_being_not_set
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.first
      planning_iteration = project.find_property_definition('Planning iteration')
      planning_release = project.find_property_definition('Planning release')

      release1 = project.cards.find_by_name('release1')
      iteration1 = project.cards.find_by_name('iteration1')
      story1 = project.cards.find_by_name('story1')

      iteration1.update_properties({"Type" => "Story"})
      iteration1.save!

      assert tree_configuration.include_card?(iteration1)
      assert_nil planning_iteration.value(iteration1)
      assert_nil planning_release.value(iteration1)

      assert tree_configuration.include_card?(story1.reload)
      assert_equal 'release1', planning_release.value(story1).name
      assert_nil planning_iteration.value(story1)
    end
  end

  def test_should_not_result_in_relationships_being_not_set_when_update_properties_with_same_card_type
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.first
      planning_iteration = project.find_property_definition('Planning iteration')
      planning_release = project.find_property_definition('Planning release')

      release1 = project.cards.find_by_name('release1')
      iteration1 = project.cards.find_by_name('iteration1')
      story1 = project.cards.find_by_name('story1')

      story1.update_properties({"Type" => "Story"})
      story1.save!

      story1.reload
      assert tree_configuration.include_card?(story1)
      assert_equal iteration1, planning_iteration.value(story1)
      assert_equal release1, planning_release.value(story1)
    end
  end

  # bug 4602
  def test_card_type_change_should_result_in_removal_from_tree_if_new_type_is_not_valid_for_tree
    with_three_level_tree_project do |project|
      tree_configuration = project.tree_configurations.first
      planning_iteration = project.find_property_definition('Planning iteration')
      planning_release = project.find_property_definition('Planning release')

      release1 = project.cards.find_by_name('release1')
      iteration1 = project.cards.find_by_name('iteration1')
      story1 = project.cards.find_by_name('story1')

      iteration1.update_properties({"Type" => "Card"})
      iteration1.save!

      assert !tree_configuration.include_card?(iteration1)
      assert_nil planning_iteration.value(iteration1)
      assert_nil planning_release.value(iteration1)

      assert tree_configuration.include_card?(story1.reload)
      assert_equal 'release1', planning_release.value(story1).name
      assert_nil planning_iteration.value(story1)
    end
  end

  def test_destroy_the_card_that_belongs_to_the_tree_and_with_children
    with_three_level_tree_project do |project|
      iteration1 = project.cards.find_by_name('iteration1')
      iteration1.destroy
      assert_nil project.cards.find_by_name('iteration1')

      planning_iteration = project.find_property_definition('Planning iteration')
      story1 = project.cards.find_by_name('story1')
      assert_nil planning_iteration.value(story1)

      planning_release = project.find_property_definition('Planning release')
      assert_equal 'release1', planning_release.value(story1).name
    end
  end

  def test_initial_card_type_name_should_be_nil
    assert_nil @project.cards.new.card_type_name
  end

  #bug 5597
  def test_card_type_name_with_double_space
    type = @project.card_types.create!(:name => 'Top  Release')
    card = @project.cards.build(:name => '2.2', :card_type_name => 'Top   Release')
    assert_equal 'Top Release', card.card_type_name
    assert_equal type, card.card_type
  end

  def test_card_id_should_be_unique_across_projects
    card1, card2 = [nil, nil]
    with_first_project do |project|
      card1 = create_card!(:name => 'card in first project')
    end

    with_project_without_cards do |project|
      card2 = create_card!(:name => 'card in project without cards')
    end

    assert card2.id > card1.id
  end

  def test_latest_version_object_return_most_lates_even_some_version_get_deleted
    with_project_without_cards do |project|
      card = create_card!(:name => 'poor target')
      card.update_attribute(:name, 'more poor target')
      Project.connection.execute("Delete from #{Card::Version.quoted_table_name} where id=#{card.versions.last.id}")
      card.reload
      assert_equal 2, card.version
      assert_equal 1, card.versions.count
      assert_equal 1, card.latest_version_object.version
    end
  end

  # bug 6751: we found that the eager loading of versions does not maintain order, at least on Oracle
  def test_latest_version_object_returns_the_latest_version_even_when_versions_are_eager_loaded
    card = @project.cards.first
    # create some versions
    card.update_attribute(:name, 'new name 1')
    card.update_attribute(:name, 'new name 2')
    card.update_attribute(:name, 'new name 3')
    card = @project.cards.find_by_number(card.number, :include => [:versions])
    assert_equal card.version, card.latest_version_object.version
  end

  # bug 6340
  def test_update_properties_creates_value_when_property_definition_name_is_too_long_that_oracle_needs_to_hash
    with_new_project do |project|
      setup_managed_text_definition 'some long property definition name', ['open', 'close']
      card = create_card! :name => 'Uno'
      card.update_properties('some long property definition name' => ['persist me'])
      assert_equal 3, project.find_property_definition('some long property definition name').enumeration_values.size
    end
  end

  # bug 6851
  def test_attachments_do_not_get_renamed_to_CGI_xxxx_xxxx
    requires_jruby do
      card = create_card! :name => 'boo'
      expected_filename = "#{Process.pid}.card_test.bug_6851"
      attachment = ActionController::UploadedTempfile.new('CGI')
      attachment.original_path = File.join(File.dirname(attachment.path), File::SEPARATOR, expected_filename)
      attachment << '1'
      attachment.flush
      card.attach_files(attachment)
      assert_equal expected_filename, File.basename(card.reload.attachments.first.file_name)
    end
  end

  def test_copiable_projects_includes_own_project
    target_project = with_new_project do |project|
      project.card_types.first.update_attribute :name, "foo"
      project.add_member(User.current)
    end

    with_new_project do |same_card_type|
      same_card_type.card_types.first.update_attribute :name, "foo"
      same_card_type.add_member(User.current)

      card = create_card! :name => "card"
      assert_equal [same_card_type, target_project].map(&:identifier).sort, card.copiable_projects.map(&:identifier).sort
    end
  end

  def test_copiable_projects_excludes_projects_without_same_card_type_or_user_without_project_card_creation_permissions
    target_project = with_new_project do |project|
      project.card_types.first.update_attribute :name, 'foo'
      project.add_member(User.current)
    end

    with_new_project do |no_same_card_type|
      no_same_card_type.card_types.first.update_attribute :name, 'bar'
      card = create_card! :name => 'uno'
      assert card.copiable_projects.empty?
    end

    with_new_project do |same_card_type|
      same_card_type.card_types.first.update_attribute :name, 'foo'
      target_project.remove_member(User.current)
      card = create_card! :name => 'dos'
      assert card.copiable_projects.empty?
    end
  end

  def test_copiable_projects_excludes_hidden_projects_and_templates
    failed_project = Project.create! :hidden =>  true, :name => 'hidden', :identifier => 'hidden'
    failed_project.card_types.create! :name => 'foobar'
    failed_project.add_member User.current

    template = Project.create! :template => true, :name => 'template', :identifier => 'template'
    template.card_types.create! :name => 'foobar'
    template.add_member User.current

    source_project = with_new_project do |project|
      project.card_types.first.update_attribute :name, 'foobar'
      card = create_card! :name => 'uno'
      assert card.copiable_projects.map(&:identifier).empty?
    end
  end

  def test_copiable_projects_includes_projects_with_same_card_type_name
    expected_project_identifier = 'the_other'
    with_new_project(:identifier => expected_project_identifier) do |project|
      project.card_types.first.update_attribute :name, 'new'
      project.add_member User.current
    end

    with_new_project do |project|
      project.card_types.first.update_attribute :name, 'NeW'
      card = create_card! :name => 'one'
      assert_equal [expected_project_identifier], card.copiable_projects.map(&:identifier)
    end
  end

  def test_copiable_projects_returns_in_smart_sorted_order
    card = create_card! :name => 'uno'
    assert_equal User.current.projects.not_hidden.not_template.all.smart_sort_by(&:name).map(&:name), card.copiable_projects.map(&:name)
  end

  def test_copiable_projects_should_not_include_projects_where_user_is_only_a_read_only_member
    bob = User.find_by_login 'bob'
    with_new_project(:identifier => 'bob_is_readonly') do |project|
      project.card_types.first.update_attribute :name, 'foo'
      project.add_member(bob, :readonly_member)
    end

    login_as_bob
    with_new_project do |project|
      project.card_types.first.update_attribute :name, 'foo'
      card = create_card! :name => 'one'
      assert card.copiable_projects.empty?, "card.copiable_projects should be empty, but includes #{card.copiable_projects.map(&:identifier).to_sentence}"
    end
  end

  def test_copiable_projects_should_include_projects_for_which_currently_logged_in_mingle_admins_are_not_explicitly_member_of
    with_new_project(:identifier => 'admin_is_not_user') do |target|
      target.card_types.first.update_attribute :name, 'foo'
    end
    login_as_admin
    with_new_project do |project|
      project.card_types.first.update_attribute :name, 'foo'
      card = create_card! :name => 'one'
      assert card.copiable_projects.map(&:identifier).include? 'admin_is_not_user'
    end
  end

  def test_copiable_projects_should_include_projects_for_which_currently_logged_in_readonly_team_members_are_full_members_for
    bob = User.find_by_login 'bob'
    with_new_project(:identifier => 'bob_is_member') do |target|
      target.card_types.first.update_attribute :name, 'foo'
      target.add_member bob
    end
    source_project = with_new_project do |source|
      source.card_types.first.update_attribute :name, 'foo'
      create_card! :name => 'copy'
      source.add_member(bob, :readonly_member)
    end
    login_as_bob
    source_project.with_active_project do |source|
      card = source.cards.find_by_name('copy')
      assert_equal ['bob_is_member'], card.copiable_projects.map(&:identifier)
    end
  end

  # Bug 7223
  def test_transitions_should_be_smart_sorted
    card = @project.cards.find_by_number(1)

    transition = create_transition(@project, 'close', :set_properties => { :status => 'closed' })
    transition = create_transition(@project, 'Fix',   :set_properties => { :status => 'fixed' })
    transition = create_transition(@project, 'new',   :set_properties => { :status => 'new' })
    transition = create_transition(@project, 'Open',  :set_properties => { :status => 'open' })

    assert_equal %w{close Fix new Open}, card.transitions.map(&:name)
  end

  def test_chart_executing_option_should_return_card_id_and_not_version_id
    card = @project.cards.create!(:name => 'first name', :project => @project, :card_type => @project.card_types.first)
    assert_equal({ :controller=>"cards", :action=>"chart", :id => card.id }, card.chart_executing_option)
  end

  def test_should_dereference_murmur_from_card_when_card_is_deleted
    card = @project.cards.find_by_number(1)
    card.add_comment :content => "howdy, nice beard"
    murmur = find_murmur_from(card)
    other_card = @project.cards.find_by_number(4)
    other_card.add_comment :content => 'thanks, friendly mutton chop'
    other_murmur = find_murmur_from(other_card)

    card.destroy

    murmur.reload
    assert_nil murmur.origin_id
    assert_nil murmur.origin_type
    other_murmur.reload
    assert_equal other_card.id, other_murmur.origin_id
    assert_equal 'Card', other_murmur.origin_type
  end

  # bug 7852
  def test_adding_blank_comment_should_not_change_last_modified_at_time
    Clock.fake_now :year => 2009, :month => 10, :day => 20, :hour => 20, :min => 00, :sec => 00
    card = @project.cards.create!(:name => 'some card', :card_type_name => 'Card')
    original_updated_at = card.updated_at
    Clock.fake_now :year => 2009, :month => 10, :day => 20, :hour => 20, :min => 10, :sec => 00
    card.save
    assert_equal original_updated_at, card.reload.updated_at
  end

  #bug 8284
  def test_adding_card_to_root_dosent_change_last_modified_at_time
    with_three_level_tree_project do |project|
      Clock.fake_now :year => 2009, :month => 10, :day => 20, :hour => 20, :min => 00, :sec => 00
      card = create_card!(:name => 'release3', :card_type => 'release')
      original_updated_at = card.updated_at
      Clock.fake_now :year => 2009, :month => 10, :day => 20, :hour => 20, :min => 10, :sec => 00
      add_card_to_tree(project.tree_configurations.first, card)
      assert_equal original_updated_at, card.reload.updated_at
    end
  end

  def test_should_create_card_deletion_event_pointing_to_last_deletion_version_on_card_destroy
    card = create_card!(:name => 'first card')
    card.update_attribute(:cp_iteration, 2)
    card.destroy

    @project.events.reload

    last_event = @project.events[-1]
    assert_equal CardDeletionEvent, last_event.class
    assert_equal card.number, last_event.origin.number
    assert_equal card.name, last_event.origin.name
    assert_equal 3, last_event.origin.version
    assert_equal card.card_type, last_event.origin.card_type
    assert_equal nil, last_event.origin.cp_iteration

    second_event = @project.events[-2]

    assert_equal CardVersionEvent, second_event.class
    assert_equal card.number, second_event.origin.number
    assert_equal card.name, second_event.origin.name
    assert_equal 2, second_event.origin.version
    assert_equal card.card_type, second_event.origin.card_type
    assert_equal "2", second_event.origin.cp_iteration

    third_event = @project.events[-3]
    assert_equal CardVersionEvent, third_event.class
    assert_equal card.number, third_event.origin.number
    assert_equal card.name, third_event.origin.name
    assert_equal 1, third_event.origin.version
    assert_equal card.card_type, third_event.origin.card_type
    assert_equal nil, third_event.origin.cp_iteration
  end

  # bug 11032
  def test_should_record_card_deleted_by_user_correctly
    card = create_card!(:name => "1")
    created_event = @project.events.last
    assert_equal @member, created_event.created_by

    admin = login_as_admin
    card.destroy
    card_delete_version = Card::Version.last
    assert_equal admin, card_delete_version.created_by
    assert_equal admin, card_delete_version.modified_by
    deleted_event = @project.events.last
    assert_equal admin.id, deleted_event.created_by_user_id
  end

  def test_card_last_version_upated_time_should_be_the_time_card_get_destroyed
    Clock.fake_now :year => 2009, :month => 10, :day => 20, :hour => 20, :min => 00, :sec => 00
    card = create_card!(:name => 'first card')
    card.update_attribute(:cp_iteration, 2)
    Clock.fake_now :year => 2010, :month => 10, :day => 20, :hour => 20, :min => 00, :sec => 00
    card.destroy
    assert_not_nil card.versions.reload.last
    assert_equal Clock.now, card.versions.reload.last.updated_at
  end


  def test_find_existing_or_deleted_card_by_card
    card = create_card!(:name => 'first card', :description => 'hello')
    assert_equal card, @project.cards.find_existing_or_deleted_card(card)
    assert_equal card, @project.cards.find_existing_or_deleted_card(card.id)
  end

  def test_find_existing_or_deleted_card_raise_record_not_found_if_card_never_exists
    assert_raise(ActiveRecord::RecordNotFound) {  @project.cards.find_existing_or_deleted_card(-0.23)}
  end

  def test_find_existing_or_deleted_card_raise_record_not_found_if_card_id_is_invalid
    assert_raise(ActiveRecord::RecordNotFound) {  @project.cards.find_existing_or_deleted_card("ddd")}
  end

  def test_parse_and_sanitize_numbers_string_should_ignore_non_existent_card_numbers
    assert_equal [1], Card.parse_and_sanitize_numbers_string('1, 2000')
  end

  def test_parse_and_sanitize_numbers_string_should_return_empty_arrary_when_number_string_is_empty
    assert_equal [], Card.parse_and_sanitize_numbers_string('')
    assert_equal [], Card.parse_and_sanitize_numbers_string('     ')
    assert_equal [], Card.parse_and_sanitize_numbers_string(',,,')
  end

  def test_parse_and_sanitize_numbers_string_should_ignore_duplicate_numbers
    assert_equal [1, 4], Card.parse_and_sanitize_numbers_string('1, 4, 1, 1')
  end

  def test_parse_and_sanitize_numbers_string_should_survive_big_input
    assert_equal [1, 4], Card.parse_and_sanitize_numbers_string("1, 4," + (10000..20000).to_a.join(","))
  end

  def test_parse_and_sanitize_numbers_string_should_ignore_anything_is_not_number
    assert_equal [1, 4], Card.parse_and_sanitize_numbers_string("abc, 1, dddd, 4")
  end

  # bug 11502
  def test_should_only_have_one_error_when_create_new_property_value_which_is_too_long
    card = create_card!(:name => 'new card')
    status = @project.find_property_definition(:status)
    card.update_properties(:status => "a" * 256)
    card.save
    assert !card.errors.empty?
    assert_equal 1, card.errors.size
  end

  def test_honor_trees_for_property_params_should_revise_tree_structure_for_tree_property_values
    ##################################################################################
    #                                     Planning tree
    #                             -------------|---------
    #                            |                      |
    #                    ----- release1----           release2
    #                   |                 |             |
    #            ---iteration1----    iteration2    iteration3
    #           |                |
    #       story1            story2
    #
    ##################################################################################
    with_new_project do |project|
      setup_managed_text_definition('status', ['new', 'open'])
      create_two_release_planning_tree
      project.reload
      tree_configuration = project.tree_configurations.first
      iteration_3 = project.cards.find_by_name('iteration3')
      release_1 = project.cards.find_by_name('release1')
      release_2 = project.cards.find_by_name('release2')
      type_story = project.find_card_type('Story')

      card = project.cards.build(:card_type_name => 'story')

      result = card.honor_trees_for('Planning iteration' => iteration_3.number)
      assert_equal({'Planning iteration' => iteration_3.number.to_s, 'Planning release' => release_2.number.to_s}, result)

      result = card.honor_trees_for('Planning release' => release_1.number, 'status' => 'new')
      assert_equal({'Planning iteration' => nil, 'Planning release' => release_1.number.to_s, 'status' => 'new'}, result)
    end
  end

  def test_honor_trees_should_work_with_plv_params
    with_three_level_tree_project do |project|
      type_release, type_iteration, type_story = find_planning_tree_types
      iteration3 = create_card!(:name => 'iteration3', :card_type => type_story)
      planning_iteration = project.find_property_definition('planning iteration')
      current_iteration = create_plv!(project, :name => 'current iteration', :value => iteration3.id, :card_type => type_iteration, :data_type => ProjectVariable::CARD_DATA_TYPE, :property_definition_ids => [planning_iteration.id])
      card = project.cards.build(:card_type_name => 'story')
      result = card.honor_trees_for('Planning iteration' => "(current iteration)")
      assert_equal({'Planning iteration' => "(current iteration)"}, result)
    end
  end

  def test_honor_trees_for_properties_should_set_tree_properties_to_nil_when_card_has_no_parent_card
    with_three_level_tree_project do |project|
      card = project.cards.build(:card_type_name => 'story')
      result = card.honor_trees_for('Planning iteration' => nil)
      assert_equal({'Planning iteration' => nil, 'Planning release' => nil}, result)
    end
  end

  def test_honor_trees_for_properties_should_keep_parent_card_when_set_a_card_tree_property_to_nil
    with_three_level_tree_project do |project|
      release1 = project.cards.find_by_name('release1')
      story1 = project.cards.find_by_name('story1')
      result = story1.honor_trees_for('Planning iteration' => nil)
      assert_equal({'Planning iteration' => nil, 'Planning release' => release1.number.to_s}, result)
    end
  end

  def test_honor_trees_for_properties_when_set_2_properties_on_same_tree_with_lower_level_property_set_to_nil
    with_new_project do |project|
      create_two_release_planning_tree
      release2 = project.cards.find_by_name('release2')
      story1 = project.cards.find_by_name('story1')
      result = story1.honor_trees_for('Planning iteration' => nil, 'Planning release' => release2.number)
      assert_equal({'Planning iteration' => nil, 'Planning release' => release2.number.to_s}, result)
    end
  end

  def test_build_with_defaults_should_fully_overwrite_card_defaults_with_tree_properties_applied
    with_new_project do |project|
      create_two_release_planning_tree
      project.reload

      tree_configuration = project.tree_configurations.first
      iteration_3 = project.cards.find_by_name('iteration3')
      release_1 = project.cards.find_by_name('release1')
      type_story = project.find_card_type('Story')
      type_story.card_defaults.update_properties('Planning iteration' => iteration_3.id)

      card = project.cards.build_with_defaults({:card_type_name => 'story'}, {'Planning release' => release_1.number})

      assert_nil card.cp_planning_iteration
      assert_equal release_1, card.cp_planning_release
    end
  end

  def test_send_history_notification_should_work_when_a_user_subscribes_to_more_than_1000_cards
    with_new_project do |project|
      assert_nothing_raised { Card::Version.load_history_event(project, (1..1001).to_a) }
    end
  end

  def test_should_support_property_column_name_attribute_methods
    with_first_project do |project|
      card = project.cards.first
      card.cp_dev_user_id = @member.id
      card.save!
      assert_equal @member.id, card.reload.cp_dev_user_id
    end
  end

  def test_participants_includes_all_user_properties_value
    with_first_project do |project|
      card = project.cards.first
      card.cp_dev_user_id = @member.id
      card.save!

      assert_equal [@member], card.participants.map(&:value)
    end

  end

  def test_participants_excludes_hidden_properties
    with_first_project do |project|
      card = project.cards.first
      card.cp_dev_user_id = @member.id
      card.save!

      project.find_property_definition('dev').update_attributes(:hidden => true)

      assert_equal [], card.participants.map(&:value)
    end

  end

  def test_raised_dependencies_status
    with_first_project do |project|
      card = project.cards.first
      card2 = project.cards.last

      dep = card.raise_dependency(:name => 'test name', :desired_end_date => '2014-02-02', :resolving_project_id => project.id)
      dep.save!
      assert_equal Dependency::NEW, card.raised_dependencies_status

      dep.link_resolving_cards([card2])
      dep.reload

      assert_equal Dependency::ACCEPTED, dep.status, "dependency status should have updated after linking"
      assert_equal Dependency::ACCEPTED, card.raised_dependencies_status

      dep2 = card.raise_dependency(:name => 'another name', :desired_end_date => '2014-02-02', :resolving_project_id => project.id)
      dep2.save!
      assert_equal Dependency::NEW, card.raised_dependencies_status

      dep2.link_resolving_cards([card2])
      dep2.reload

      assert_equal Dependency::ACCEPTED, dep2.status, "dependency status should have updated after linking"
      assert_equal Dependency::ACCEPTED, card.raised_dependencies_status
    end
  end

  def test_dependencies_resolving_status
    with_first_project do |project|
      card = project.cards.first
      card2 = project.cards.last
      dep = card.raise_dependency(:name => 'test name', :desired_end_date => '2014-02-02', :resolving_project_id => project.id)
      dep.save!

      assert_nil card2.dependencies_resolving_status
      dep.save
      dep.link_resolving_cards([card2])
      card2.reload
      assert_equal Dependency::ACCEPTED, card2.dependencies_resolving_status
    end
  end

  def test_should_add_checklist_items_to_card_without_saving
    with_new_project do |project|
      card = project.cards.build(:card_type_name => 'Card')
      incomplete_checklist_items = %w(item1 item2 item3)
      completed_checklist_items = %w(completed_item)
      card.add_checklist_items({'incomplete checklist items' => incomplete_checklist_items, 'completed checklist items' => completed_checklist_items})
      assert_equal incomplete_checklist_items, card.incomplete_checklist_items.map(&:text)
      assert_equal completed_checklist_items, card.completed_checklist_items.map(&:text)
      assert card.checklist_items.all? { |item| item.new_record? }
    end
  end

  def test_destroy_should_delete_raised_dependencies
    card = create_card!(:name => 'Card 1')
    dep = card.raise_dependency(:name => 'New dependency', :desired_end_date => '2016-10-02', :resolving_project_id => @project.id)
    dep.save!
    dep_id = dep.id

    assert_equal Dependency::NEW, card.raised_dependencies_status
    card.destroy

    assert_not Dependency.exists?(dep_id)
  end


  def test_destroy_should_unlink_dependencies_resolving_card
    card1 = create_card!(:name => 'Card 1')
    card2 = create_card!(:name => 'Card 2')

    dep = card1.raise_dependency(:name => 'New dependency', :desired_end_date => '2016-10-02', :resolving_project_id => @project.id)
    dep.save!
    dep.link_resolving_cards([card2])

    card2.reload
    assert_equal Dependency::ACCEPTED, card2.dependencies_resolving_status

    card1.destroy
    assert_nil card2.dependencies_resolving_status
  end


  def test_bulk_destroy_should_delete_raised_dependencies
    card = create_card!(:name => 'Card 1')
    dep = card.raise_dependency(:name => 'New dependency', :desired_end_date => '2016-10-02', :resolving_project_id => @project.id)
    dep.save!
    dep_id = dep.id
    assert_equal Dependency::NEW, card.raised_dependencies_status

    selection = CardSelection.new(@project, [card])
    assert selection.destroy
    assert selection.errors.empty?

    assert_not Dependency.exists?(dep_id)
  end


  def test_bulk_destroy_should_unlink_dependencies_resolving_card
    card1 = create_card!(:name => 'Card 1')
    card2 = create_card!(:name => 'Card 2')

    dep = card1.raise_dependency(:name => 'New dependency', :desired_end_date => '2016-10-02', :resolving_project_id => @project.id)
    dep.save!
    dep.link_resolving_cards([card2])

    card2.reload
    assert_equal Dependency::ACCEPTED, card2.dependencies_resolving_status

    selection = CardSelection.new(@project, [card1])
    assert selection.destroy
    assert selection.errors.empty?
    assert_nil card2.dependencies_resolving_status
  end

  protected

  def view_helper
    view_helper = ActionView::Base.new
    view_helper.controller = PagesController.new
    request = ActionController::AbstractRequest.new
    params = {:controller => 'pages', :action => 'show'}
    request.path_parameters = params
    request.instance_variable_set(:@env, {})
    view_helper.controller.instance_variable_set(:@url, ActionController::UrlRewriter.new(request, params))
    view_helper
  end

end
