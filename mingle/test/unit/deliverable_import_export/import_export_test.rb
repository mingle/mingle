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
class ImportExportTest < ActiveSupport::TestCase
  include ProjectImportExportTestHelper

  def test_should_cleanup_tmp_files_after_import_finished
    MingleConfiguration.no_cleanup = false
    @user = login_as_member
    @project, _ = setup_round_trip_test_project
    @export_file = create_project_exporter!(@project, @user).export
    @project_importer = create_project_importer!(User.current, @export_file)
    @project_importer.process!
    assert_false File.exists?(@project_importer.directory)
    assert_false File.exists?(@project_importer.export_file)
  ensure
    MingleConfiguration.no_cleanup = true
  end

  def test_feeds_cache_is_reset_after_import
    @user = login_as_member
    @project, @card, @tag = setup_round_trip_test_project

    @export_file = create_project_exporter!(@project, @user).export

    @project_importer = create_project_importer!(User.current, @export_file)


    imported_project = @project_importer.process!
    assert imported_project

    cache_key = CacheKey.find_by_deliverable_id(imported_project.id)
    assert_not_nil cache_key.feed_key
  end

  def test_export_import_round_trip_1
    @user = login_as_member
    @project, @card, @tag = setup_round_trip_test_project

    @export_file = create_project_exporter!(@project, @user).export

    @project_importer = create_project_importer!(User.current, @export_file)
    @project_importer.process!

    assert_equal Project.connection.select_values("SELECT version FROM #{ActiveRecord::Base.table_name_prefix}schema_migrations").map(&:to_i).max, @project_importer.schema_version

    project_records = @project_importer.table('deliverables').to_a
    assert_equal 1, project_records.size
    assert_equal @project.name, project_records.first["name"]
    assert_equal @project.identifier, project_records.first["identifier"]

    tag_records = @project_importer.table('tags').to_a.sort_by{|t| t["name"]}
    assert_equal 2, tag_records.size
    assert_equal 'Another Tag', tag_records.first["name"]

    tagging_records = @project_importer.table('taggings').to_a.sort_by{|t| t["tag_id"]}
    assert_equal 4, tagging_records.size
    assert_equal ['id', 'position', 'taggable_id', 'taggable_type', 'tag_id'].sort, tagging_records.first.keys.sort
    assert_equal @card.id.to_s, tagging_records.first["taggable_id"].to_s

    assert tagging_records.any?{|record| record["tag_id"].to_s == @tag.id.to_s}

    user_records = @project_importer.table('users').to_a
    assert_equal @project.users.size, user_records.size
  end

  def test_export_import_round_trip_2
    @user = login_as_member
    @project, @card, @tag = setup_round_trip_test_project

    export = create_project_exporter!(@project, @user)
    @export_file = export.export

    @project_importer = create_project_importer!(User.current, @export_file)
    assert_equal 0, @project_importer.progress_percent
    imported_project = @project_importer.process!

    @project_importer.reload
    assert @project_importer.total > 10
    assert_equal @project_importer.total, @project_importer.completed
    assert_equal 1, @project_importer.progress_percent
    assert !@project_importer.project.hidden?
    assert_equal 'Project import complete', @project_importer.progress_message

    assert_equal "This is a sample attachment.\n", File.read(imported_project.icon)

    assert_equal 2, imported_project.tags.count
    assert_equal ['Another Tag', 'Exported Tag'], imported_project.tags.collect(&:name).sort

    imported_card = imported_project.cards.first
    assert_equal 'Another Tag Exported Tag', imported_card.tag_list
    assert_equal 1, imported_card.attachments.size
    assert_equal 1, imported_card.versions.last.attachments.size
    assert_equal 'sample_attachment.txt', imported_card.attachments.first.file_name
    assert_equal "This is a sample attachment.\n", File.read(imported_card.attachments.first.file)
    assert_not_nil imported_card.created_by
    assert_equal 'member@email.com', imported_card.created_by.email
    assert_equal 'member@email.com', imported_card.modified_by.email
    assert_equal User.find_by_login("member"), imported_card.modified_by
    assert_not_nil imported_card.versions.first.created_by
    assert_equal 'member@email.com', imported_card.versions.first.created_by.email
    assert_equal 'member@email.com', imported_card.versions.first.modified_by.email
    assert_equal User.find_by_login("member"), imported_card.versions.first.modified_by

    imported_page = imported_project.pages.first
    assert_equal 1, imported_page.attachments.size
    assert_equal 1, imported_page.versions.last.attachments.size
    assert_equal 'sample_attachment.txt', imported_page.attachments.first.file_name
    assert_equal 'sample_attachment.txt', imported_page.versions.last.attachments.first.file_name
  end

  def test_import_rejects_invalid_file_format
    @user = login_as_member
    @project = create_project

    # try to import this file, it is invalid as an import
    importer = create_project_importer!(User.current, __FILE__)
    importer.process!

    assert_equal 1, importer.error_count
    assert_equal "Invalid export file", importer.progress.message[:errors].first
  end

  def test_round_tripping_exporting_a_project_export_import_retains_property_definitions_and_card_table_schema
    @user = login_as_member
    @project = create_project(:identifier => 'id'.uniquify[0..8])
    setup_property_definitions :release => [1]
    create_card!(:name => 'test card', :release => '1')
    @export_file = create_project_exporter!(@project, User.current, :template => false).export

    @project.deactivate #because - really - they will never happen with the same project being active

    imported_project = create_project_importer!(User.current, @export_file).process!
    assert_equal @project.identifier + "1", imported_project.identifier
    assert_equal "#{@project.identifier}1_cards", Card.table_name
    assert Card.content_columns.collect(&:name).include?('cp_release')
    assert_equal '1', imported_project.cards.detect { |card| card.name == 'test card'}.cp_release
  end


  def test_import_with_a_different_name
    @user = login_as_member
    @project = create_project

    @export_file = create_project_exporter!(@project, User.current, :template => false).export
    new_name = unique_name('pr')
    new_identifier = unique_name('pr')
    @project_importer = create_project_importer!(User.current, @export_file, new_name, new_identifier)
    imported_project = @project_importer.process!
    assert_equal(new_name, imported_project.reload.name)
    assert_equal(new_identifier, imported_project.identifier)
  end

  # for bug 1502
  def test_import_with_a_long_name_and_identifier
    @user = login_as_member
    @project = create_project

    @export_file = create_project_exporter!(@project, User.current, :template => false).export
    long_str = '1234567890_1234567890_1234567890'
    new_name = unique_name('p') << long_str
    new_identifier = unique_name('p') << long_str

    @project_importer = create_project_importer!(User.current, @export_file, new_name, new_identifier)
    imported_project = @project_importer.process!
    assert_equal(new_name, imported_project.reload.name)
    assert new_identifier.length > Identifiable::IDENTIFIER_MAX_LEN
    assert_equal(new_identifier.slice(0, Identifiable::IDENTIFIER_MAX_LEN), imported_project.identifier)
  end

  # for bug 1245
  def test_import_with_different_name_should_strip_name_and_identifier
    @user = login_as_member
    @project = create_project

    @export_file = create_project_exporter!(@project, User.current, :template => false).export
    new_name = unique_name('pr')
    new_identifier = unique_name('pr')

    @project_importer = create_project_importer!(User.current, @export_file, new_name, new_identifier)
    imported_project = @project_importer.process!
    assert_equal(new_name, imported_project.reload.name)
    assert_equal(new_identifier, imported_project.identifier)
  end

  def test_should_handle_duplicate_identifier_during_importing
    @user = login_as_member
    @project = create_project

    @export_file = create_project_exporter!(@project, User.current, :template => false).export
    new_name = @project.name
    new_identifier = @project.identifier
    @project_importer = create_project_importer!(User.current, @export_file, new_name, new_identifier)
    imported_project = @project_importer.process!
    assert_equal("#{new_name}1", imported_project.reload.name)
    assert_equal("#{new_identifier}1", imported_project.identifier)
  end

  def test_should_handle_empty_identifier_during_importing
    @user = login_as_member
    @project = create_project

    @export_file = create_project_exporter!(@project, User.current, :template => false).export
    @project_importer = create_project_importer!(User.current, @export_file, '', '')
    imported_project = @project_importer.process!
    assert_equal("#{@project.name}1", imported_project.reload.name)
    assert_equal("#{@project.identifier}1", imported_project.identifier)
  end

  def test_export_of_property_definitions_and_enumeration_values
    @user = login_as_member
    @project = create_project

    setup_property_definitions :status => ['new', 'open', 'fixed'], :iteration => [1,2], :release => [1]
    card = create_card!(:name => 'Exported Card')

    @export_file = create_project_exporter!(@project, @user).export
    @project_importer = create_project_importer!(User.current, @export_file, 'new name2', 'new_name2')
    @project_importer.process!.with_active_project do  |imported_project|
      assert_equal ['new', 'open', 'fixed'], imported_project.find_property_definition('status').enumeration_values.collect(&:value)
      assert_equal [1, 2, 3], imported_project.find_property_definition('status').enumeration_values.collect(&:position)
      assert_equal imported_project.find_property_definition('status'), imported_project.find_property_definition('status').enumeration_values.collect(&:property_definition).uniq.first
      assert_equal ['1', '2'], imported_project.find_property_definition('iteration').enumeration_values.collect(&:value)
    end
  end

  def test_all_columns_except
    @user = login_as_member
    with_new_project do |project|
      assert_equal [], project.class.all_columns_except(*project.class.columns.collect(&:name))
    end
  end

  def test_updates_card_number_sequence_upon_completion
    @user = login_as_member
    with_new_project do |project|
      create_card!(:number => 1, :name => 'card 1')
      create_card!(:number => 4, :name => 'card 4')
      export = create_project_exporter!(project, User.current, :template => false).export
      imported_project = create_project_importer!(User.current, export).process!
      assert_equal 5, imported_project.cards.create(:name => 'first post import card', :card_type => imported_project.card_types.first).number
    end
  end

  def test_project_import_supports_old_school_file_names
    @user = login_as_member
    @project = create_project
    card = create_card!(:name => 'Exported Card')

    # simulate old school export ...
    @export_file = create_project_exporter!(@project, User.current, :template => false).export
    dir = File.join(File.dirname(@export_file), File.basename(@export_file, '.mingle'))
    FileUtils.mkdir_p(dir)
    unzip(@export_file, dir)
    Dir.foreach(dir) do |entry|
      if entry =~ /(.*)(_0\.yml)/
        FileUtils.mv(File.join(dir, entry), File.join(dir, "#{$1}.yml"))
      end
    end
    FileUtils.rm(@export_file)
    zip(dir)
    FileUtils.rm_rf(dir)
    old_school_export_file = "#{dir}_old_school.mingle"
    FileUtils.mv("#{dir}.zip", old_school_export_file)

    # ... now see if we can import it
    imported_project = create_project_importer!(User.current, old_school_export_file).process!
    assert_equal 'Exported Card', imported_project.cards[0].name
  end

  def test_should_reset_values_for_card_relationship_property_definitions_after_import_to_be_the_new_ids_for_cards
    @user = login_as_member
    @project = create_project(:users => [@user])

    @project.with_active_project do |project|
      setup_card_relationship_property_definition('analysis complete iteration')
      story1 = @project.cards.create!(:name => 'Story 1', :card_type => @project.card_types.first)
      story2 = @project.cards.create!(:name => 'Story 2', :card_type => @project.card_types.first)
      iteration1 = @project.cards.create!(:name => 'Iteration 1', :card_type => @project.card_types.first)
      iteration2 = @project.cards.create!(:name => 'Iteration 2', :card_type => @project.card_types.first)

      story1.update_attributes(:cp_analysis_complete_iteration => iteration2)
      story2.update_attributes(:cp_analysis_complete_iteration => iteration1)
    end

    export_and_reimport(@project).with_active_project do |imported_project|
      imported_story1 = imported_project.cards.find_by_name('Story 1')
      imported_story2 = imported_project.cards.find_by_name('Story 2')
      imported_iteration1 = imported_project.cards.find_by_name('Iteration 1')
      imported_iteration2 = imported_project.cards.find_by_name('Iteration 2')

      assert_equal imported_iteration2, imported_story1.cp_analysis_complete_iteration
      assert_equal imported_iteration1, imported_story2.cp_analysis_complete_iteration
    end
  end

  def test_should_use_share_folder_to_store_uploaded_import_file_content
    @user = login_as_member
    @project = create_project(:users => [@user])
    @export_file = create_project_exporter!(@project, User.current, :template => true).export
    @project_importer = create_project_importer!(User.current, @export_file)
    @project_importer.process!

    assert_inside_swap_dir(@project_importer.directory)
  end

  def test_should_import_page_content_when_importing_projects
    requires_jruby do
      @user = login_as_member
      @project = create_project(:users => [@user])
      @project.pages.create!(:name => 'Overview Page', :content => 'a' * 4001)
      @export_file = create_project_exporter!(@project, User.current).export
      imported_project = create_project_importer!(User.current, @export_file).process!
      assert_equal 'a' * 4001, imported_project.overview_page.content
    end
  end

  def test_import_on_fatal_error_drop_tables_created_and_deletes_data_of_failed_importing_project
    ProjectImportAsynchRequest.destroy_all
    @user = login_as_member
    assert_no_difference 'Project.count(:conditions => { :hidden => true })' do
      # This project has its attachings.yml pointing at non-existent attachables. Inspired by ZenDesk #1034
      project_import = create_project_importer!(User.current, "#{Rails.root}/test/data/attachings_attachable_borked.mingle", 'project_borked', 'project_borked')
      def project_import.import_attachments(*args)
        raise 'Exception!'
      end
      project_import.process!

      assert_equal false, ActiveRecord::Base.connection.table_exists?(Card.table_name)

      # need to add error so that we redirect to the correct place and display an error message on screen
      assert_equal 1, ProjectImportAsynchRequest.find(:first, :conditions => ["type = 'ProjectImportAsynchRequest'"]).error_count
    end
  end

  def test_create_project_without_cards_should_ignore_the_attachment_in_these_cards
    @user = login_as_member
    @project = create_project(:users => [@user])

    export_file = create_project_exporter!(@project, User.current, :template => true).export
    imported_project = create_project_importer!(User.current, export_file).process!(:include_cards => false)
    assert_equal [], Attachment.find_all_by_project_id(imported_project.id).collect(&:attachings).flatten.select { |attaching| attaching.attachable_type == "Card" }
  end

  def test_should_import_versions_for_deleted_card
    @user = login_as_member
    card_number = nil;
    project = with_new_project do |project|
      card = create_card!(:name => 'will be deleted before export')
      card.update_attribute(:name, 'will definitely be deleted before export')
      card_number = card.number
      card.destroy
      project.reload
    end

    export_file = create_project_exporter!(project, User.current).export

    imported_project = create_project_importer!(User.current, export_file).process!
    imported_versions = Card::Version.find_all_by_number(card_number)
    assert_equal 3, imported_versions.size
    assert !imported_versions.any? { |v| v.card_id.nil? }
    assert_equal imported_versions.first.card_id, imported_versions.second.card_id
    assert_equal imported_versions.second.card_id, imported_versions.third.card_id
    assert !imported_project.cards.exists?(imported_versions.first.card_id)
    assert_equal 'will definitely be deleted before export', imported_project.cards.find_existing_or_deleted_card(imported_versions.first.card_id).name
  end

  #bug 10310
  def test_should_import_data_in_same_order_with_exporting_data
    page_size = 2
    default_page_size = ImportExport::TableWithModel::DEFAULT_PAGE_SIZE
    silence_warnings { ImportExport::TableWithModel.const_set "DEFAULT_PAGE_SIZE", page_size }

    @user = login_as_member

    @project = with_new_project do |project|
      (page_size * 15).times do |index|
        create_murmur(:murmur => "murmur index #{index}")
      end
      project
    end

    export_file = create_project_exporter!(@project, User.current).export
    imported_project = create_project_importer!(User.current, export_file).process!

    assert_equal @project.murmurs.query(:page => 1).collect(&:murmur), imported_project.murmurs.query(:page => 1).collect(&:murmur)
  ensure
    silence_warnings { ImportExport::TableWithModel.const_set "DEFAULT_PAGE_SIZE", default_page_size }
  end

  def test_export_should_handle_cards_table_not_shortened_but_card_versions_table_shortened
    login_as_admin
    project = with_new_project(:name => 'rail_lines__ui_team') do
      create_card! :name => 'One'
    end
    export_file = create_project_exporter!(project, User.current).export
    dir = File.join(File.dirname(export_file), "unzipped")
    unzip(export_file, dir)
    deliverable = YAML.load_file(File.join(dir, "deliverables_0.yml")).first
    assert_include deliverable['card_versions_table'] + '_0.yml', Dir.entries(dir), "Oracle exported yaml filenames must be shortened filenames.yml."

    imported_project = create_project_importer!(User.current, export_file).process!
    assert_equal 1, imported_project.cards.find_by_number(1).versions.count
  ensure
    FileUtils.rm_rf(dir)
  end

  def test_should_import_and_export_dependency_views_that_belong_to_team_members
    @user = login_as_member
    non_team_member = User.find_by_login('admin')

    export_file = create_export_file do |project|
      project.add_member(User.current)

      # make user part of more than one group to ensure only 1 record is exported per user
      group = project.groups.create!(:name => "another group")
      group.add_member(User.current)

      view = project.dependency_views.current
      view.update_params(:filter => 'raising')

      view = project.dependency_views.create!(:user => non_team_member)
      view.update_params(:sort => 'name')
    end

    imported_project = create_project_importer!(@user, export_file).process!.reload
    assert_equal 1, imported_project.dependency_views.count
    imported_view = imported_project.dependency_views.first
    assert_equal 'raising', imported_view.filter
    assert_equal @user, imported_view.user
  end

  def test_should_import_checklist_items
    user = login_as_admin
    with_new_project(:users => [user]) do |project|
      completed_checklist_items = ['Watch latest GOT']
      incomplete_checklist_items = ['Freaky thursday', 'Fix SOIs']
      create_card!(:name => 'a card', :incomplete_checklist_items => incomplete_checklist_items, :completed_checklist_items => completed_checklist_items)

      export_file = create_project_exporter!(project, user, :template => false).export
      imported_project = create_project_importer!(user, export_file).process!.reload
      assert_equal 3, imported_project.cards.first.checklist_items.size
      assert_equal incomplete_checklist_items, imported_project.cards.first.incomplete_checklist_items.map(&:text)
      assert_equal completed_checklist_items, imported_project.cards.first.completed_checklist_items.map(&:text)
    end
  end

end
