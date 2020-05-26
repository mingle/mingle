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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../messaging/messaging_test_helper')

module DeliverableImportExport
  class ProjectExporterTest < ActiveSupport::TestCase
    include Zipper
    include MessagingTestHelper

    def setup
      @user = login_as_member
    end

    def teardown
      logout_as_nil
      Clock.reset_fake
    end

    def test_export_project_with_groups
      export_file = create_export_file do |project|
        project.user_defined_groups.create!(:name => 'Group')
      end
      imported_project = create_project_importer!(@user, export_file).process!.reload

      assert_equal 'Group', imported_project.user_defined_groups.first.name
    end

    def test_export_project_with_group_memberships
      new_admin = create_user!(:login => 'new_admin')
      export_file = create_export_file do |project|
        group = project.user_defined_groups.create!(:name => 'Group')
        project.add_member(new_admin, :project_admin)
        group.add_member(new_admin)
      end
      new_admin.destroy

      login_as_admin
      imported_project = create_project_importer!(User.current, export_file).process!.reload
      imported_admin = imported_project.users.detect {|u| u.login == new_admin.login}
      assert_equal 1, imported_project.groups_for_member(imported_admin).size
    end

    def test_export_import_project_should_not_include_memberships
      admin = login_as_admin
      export_file = create_export_file(true) do |project|
        group = project.user_defined_groups.create!(:name => 'Group')
        project.add_member(admin, :project_admin)
        group.add_member(admin)
      end
      imported_project = create_project_importer!(admin, export_file).process!.reload
      assert_equal 0, imported_project.user_defined_groups.first.user_memberships.size
    end

    def test_export_project_with_correction_changes
      export_file = create_export_file do |project|
        project.update_attribute(:card_keywords, 'hello')
      end

      imported_project = create_project_importer!(@user, export_file).process!.reload
      correction_event = imported_project.events.first
      assert_equal 'CorrectionEvent', correction_event.type
      assert_equal 'card-keywords-change', correction_event.changes.first.change_type
    end

    def test_should_mark_queued_after_created_project_export
      with_first_project do |project|
        assert_equal "queued", create_project_exporter!(project, User.current).status
      end
    end

    def test_export_project_missing_attachments
      with_new_project do |project|
        attachment = Attachment.create!(:file => sample_attachment, :project => project)
        card = create_card! :name => 'card with attachment', :number => 1
        card.attach_files(sample_attachment)
        assert File.delete("#{File.expand_path(Rails.root)}/public/#{attachment.path}/#{attachment.id}/sample_attachment.txt")
        project.reload
        export = create_project_exporter!(project, @user)
        export.export
        assert_equal true, export.completed?
        assert_equal false, export.failed?
      end
    end

    def test_export_project_should_export_secret_key
      original_secret_key = nil
      export_file = create_export_file do |project|
        original_secret_key = project.secret_key
        assert !original_secret_key.nil?
      end
      imported_project = create_project_importer!(@user, export_file).process!.reload
      assert !imported_project.secret_key.nil?
      assert original_secret_key == imported_project.secret_key
    end

    # bug 3286
    def test_export_project_should_export_attachments_belonging_to_versions
      login_as_member
      export_file = create_export_file do |project|
        attachment = Attachment.create!(:file => sample_attachment, :project => project)

        card = create_card! :name => 'card with attachment', :number => 1
        card.attach_files(sample_attachment("firstversion.txt"))
        card.save!
        assert_equal ["firstversion.txt"], card.reload.versions.last.attachments.collect(&:file_name)

        card.remove_attachment("firstversion.txt")
        card.attach_files(sample_attachment("secondversion.txt"))
        card.save!
        assert_equal ["secondversion.txt"], card.reload.versions.last.attachments.collect(&:file_name)
      end

      assert_file_exists_in_exported_file(export_file, 'firstversion.txt', 'secondversion.txt')

      imported_project = create_project_importer!(@user, export_file).process!.reload

      assert imported_project.attachments.collect(&:file_name).include?("secondversion.txt")
      assert imported_project.attachments.collect(&:file_name).include?("firstversion.txt")
    end

    def test_export_project_should_include_user_icons
      user = create_user!(:icon => sample_attachment('user_icon.png'))
      project = create_project(:users => [user])
      export = create_project_exporter!(project, user)
      export_file = export.export

      with_unziped_mingle_export(export_file) do |dir|
        assert_relative_file_path_in_directory "user/icon/#{user.id}/user_icon.png", dir
      end
    end

    def test_zip_basedir_zips_file_to_swap_dir
      with_new_project do |project|
        Clock.fake_now(:year => 2005, :month => 10, :day => 9, :hour => 8, :min => 7, :sec => 6)
        create_project_exporter!(project, @user).export

        expected_pathname = File.join(SWAP_DIR, Mingle::Revision::SWAP_SUBDIR, 'exports', Clock.now.to_i.to_s, project.identifier + '.mingle')
        assert File.exist?(expected_pathname), "Expected file '#{expected_pathname}' to exist but not so much."
      end
    end

    def test_newly_created_export_has_correct_status
      with_first_project do |project|
        export = create_project_exporter!(project, @user)
        assert_equal false, export.completed?
        assert_equal false, export.failed?
      end
    end

    def test_successful_export_has_correct_status
      with_first_project do |project|
        export = create_project_exporter!(project, @user)
        export.export
        assert_equal true, export.completed?
        assert_equal false, export.failed?
      end
    end

    def test_failed_export_has_correct_status
      with_first_project do |project|
        export = create_project_exporter!(project, @user)
        def export.export_models(models, sql_method, &block)
          raise "Forcing failure!"
        end
        export.export
        # export.reload
        assert_equal true, export.completed?
        assert_equal true, export.failed?
        assert_equal ["Forcing failure!"], export.error_details
      end
    end

    def test_should_init_total_after_created
      with_first_project do |project|
        models_and_attachments_and_zipping = ImportExport::ALL_MODELS().size + 1 + 1
        export = create_project_exporter!(project, @user)
        assert_equal models_and_attachments_and_zipping, export.total
      end
    end

    def test_export_with_error_raised
      with_first_project do |project|
        assert DeliverableImportExport::ProjectExporter.export_with_error_raised(:project => project, :template => false)

        def project.identifier
          raise "error from project identifier"
        end

        assert_raise RuntimeError do
          DeliverableImportExport::ProjectExporter.export_with_error_raised(:project => project, :template => false)
        end
      end
    end

    def test_export_includes_any_configured_source_plugins
      export_file = create_export_file do |project|
        SubversionConfiguration.create!(:project => project, :repository_path => '/some/sort/of/path')
      end
      imported_project = create_project_importer!(@user, export_file).process!.reload
      assert imported_project.has_source_repository?
      assert_equal '/some/sort/of/path', imported_project.source_repository_path
    end

    def test_export_murmurs_and_not_card_murmur_links_for_projects
      export_file = create_export_file do |project|
        murmur = create_murmur :murmur => 'One'
        card   = create_card! :name => 'Uno'
        project.card_murmur_links.create! :murmur_id => murmur.id, :card_id => card.id
      end

      imported_project = create_project_importer!(@user, export_file).process!.reload

      imported_project.with_active_project do |project|
        assert_equal 1, project.murmurs.count
        assert_equal 0, project.card_murmur_links.count
      end
    end

    def test_create_murmur_card_and_project_links_after_import
      export_file = create_export_file do |project|
        card   = create_card! :name => 'Uno'
        murmur = create_murmur :murmur => "linking to ##{card.number}"
        project.card_murmur_links.create! :murmur_id => murmur.id, :card_id => card.id
      end
      all_messages_from_queue(CardMurmurLinkProcessor::ProjectCardMurmurLinksProcessor::QUEUE)

      imported_project = create_project_importer!(@user, export_file).process!.reload
      assert_equal 1, all_messages_from_queue(CardMurmurLinkProcessor::ProjectCardMurmurLinksProcessor::QUEUE).size
    end

    def test_create_murmur_card_and_project_links_after_import_when_murmurer_is_no_longer_team_member
      user = create_user! :name => "bob"
      export_file = create_export_file do |project|
        card   = create_card! :name => 'Uno'
        project.add_member(user)
        murmur = create_murmur :murmur => "linking to ##{card.number}", :author => user
        project.card_murmur_links.create! :murmur_id => murmur.id, :card_id => card.id
        project.remove_member(user)
      end

      imported_project = create_project_importer!(@user, export_file).process!.reload
      imported_project.with_active_project do |project|
        assert_equal 1, project.reload.murmurs.count
        assert_equal user.id, project.murmurs.first.author_id
      end
    end

    def test_should_import_non_team_members_who_have_authored_murmurs
      non_team_member = create_user! :login => "non_member"
      export_file = create_export_file do |project|
        murmur = create_murmur :murmur => "hello", :author => non_team_member
      end

      non_team_member.destroy

      imported_project = create_project_importer!(@user, export_file).process!.reload
      imported_project.with_active_project do |project|
        assert_equal 1, project.reload.murmurs.count
        imported_user = User.find_by_login("non_member")
        assert_not_nil imported_user
        assert_equal imported_user.id, project.murmurs.first.author_id
      end
    end

    def import_does_not_fail_when_source_plugin_is_unavailable
      export_file = create_export_file do |project|
        SubversionConfiguration.create!(:project => project, :repository_path => '/some/sort/of/path')
      end

      MinglePlugins::Source.available_plugins=([])
      project_import = create_project_importer!(@user, export_file)
      imported_project = project_import.process!.reload
      assert_equal 0, SubversionConfiguration.find_all_by_project_id(imported_project.id).size
      assert !imported_project.has_source_repository?
      assert project_import.completed
      assert !imported_project.hidden
    ensure
      MinglePlugins::Source.available_plugins=(nil)
    end

    def test_from_message_always_sets_current_project_to_one_specified_in_message
      with_new_project do |project|
        request = User.current.asynch_requests.create_project_export_asynch_request(project.identifier)
        export = DeliverableImportExport::ProjectExporter.fromActiveMQMessage(:project_id => project.id, :user_id => User.first.id, :request_id => request.id)
        assert_equal project, export.project
      end
    end

    def test_from_message_always_sets_current_user_to_one_specified_in_message
      user = User.first
      with_new_project do |project|
        request = User.current.asynch_requests.create_project_export_asynch_request(project.identifier)
        export = DeliverableImportExport::ProjectExporter.fromActiveMQMessage(:project_id => project.id, :user_id => user.id, :request_id => request.id)
        assert_equal user, export.user
      end
    end

    def test_from_message_always_sets_progress_to_one_specified_in_message
      user = User.first
      with_new_project do |project|
        request = ProjectExportAsynchRequest.create!(:user_id => user.id, :deliverable_identifier => project.identifier)
        export = DeliverableImportExport::ProjectExporter.fromActiveMQMessage :request_id => request.id, :user_id => user.id, :project_id => project.id
        assert_equal request.id, export.progress.id
      end
    end

    def test_process_should_update_progress_message_when_export_raises_error
      with_first_project do |project|
        request = User.current.asynch_requests.create_project_export_asynch_request(project.identifier)
        project_exporter = DeliverableImportExport::ProjectExporter.fromActiveMQMessage(:project_id => project.id, :user_id => User.first.id, :request_id => request.id)

        def project_exporter.export
          raise 'Oops!!!!'
        end

        assert_nothing_raised { project_exporter.process! }
        assert_equal 'Error while processing export, please contact your Mingle administrator.', project_exporter.progress.progress_message
      end
    end

    def test_export_project_should_export_personal_card_list_view_and_page_favorites
      with_new_project(:users => [@user]) do |project|
        team_view     = project.card_list_views.create_or_update(:view => {:name => 'Team'}, :style => 'list', :user_id => nil)
        personal_view = project.card_list_views.create_or_update(:view => {:name => 'Personal'}, :style => 'list', :user_id => @user.id)

        not_fav_page = project.pages.create(:name => 'team')
        fav_page     = project.pages.create(:name => 'personal')
        project.favorites.of_pages.create(:favorited => not_fav_page)
        project.favorites.of_pages.personal(@user).create(:favorited => fav_page)

        export_file = create_project_exporter!(project, @user).export

        with_unziped_mingle_export(export_file) do |dir|
          exported_card_list_views = YAML.load_file(File.join(dir, 'card_list_views_0.yml'))
          assert_equal 2, exported_card_list_views.size
          assert_equal ['Personal', 'Team'], exported_card_list_views.map(&OpenStruct.method(:new)).map(&:name).sort

          exported_favorites = YAML.load_file(File.join(dir, 'favorites_0.yml'))
          assert_equal 2, exported_card_list_views.size
          page_favorites = exported_favorites.map(&OpenStruct.method(:new)).find_all { |favorite| favorite.favorited_type == 'Page' }
          assert_equal [not_fav_page.id, fav_page.id].map(&:to_s).sort, page_favorites.map(&:favorited_id).map(&:to_s).sort
        end
      end
    end

    def test_export_project_should_not_export_dependency_events
      with_new_project(:users => [@user]) do |project|
        card = create_card!(:name => 'a card')
        dep = card.raise_dependency(
          :name => "First Dependency",
          :resolving_project_id => project.id,
          :desired_end_date => "2016-01-31"
        )
        dep.save!

        export_file = create_project_exporter!(project, @user, :template => false).export
        with_unziped_mingle_export(export_file) do |dir|
          exported_events = YAML.load_file(File.join(dir, 'events_0.yml'))
          assert_not_include 'Dependency::Version', exported_events.collect{ |e| e['origin_type'] }
        end
      end
    end

    def test_exporting_should_set_last_export_date
      with_new_project(:users => [@user]) do |project|
        export_file = create_project_exporter!(project, @user, :template => false).process!
        assert_not_nil project.reload.last_export_date
      end
    end

    def test_export_project_should_export_card_and_page_events_but_not_revision_event
      with_new_project(:users => [@user]) do |project|
        create_card!(:name => 'a card')
        project.pages.create!(:name => 'ss')
        project.revisions.create!(:number => 1, :identifier => 'abc',
          :commit_message => 'commit 1', :commit_time => Time.now, :commit_user => 'user')

        export_file = create_project_exporter!(project, @user, :template => false).export
        with_unziped_mingle_export(export_file) do |dir|
          exported_events = YAML.load_file(File.join(dir, 'events_0.yml'))
          assert_equal 2, exported_events.size
          assert_equal ['Card::Version', 'Page::Version'], exported_events.collect{ |e| e['origin_type'] }
        end
      end
    end

    def test_export_project_should_export_checklist_items
      with_new_project(:users => [@user]) do |project|
        completed_checklist_items = ['Buy groceries', 'Visit dentist']
        incomplete_checklist_items = ['Thirsty thursday']
        create_card!(:name => 'a card', :incomplete_checklist_items => incomplete_checklist_items, :completed_checklist_items => completed_checklist_items)

        export_file = create_project_exporter!(project, @user, :template => false).export
        with_unziped_mingle_export(export_file) do |dir|
          exported_checklist_items = YAML.load_file(File.join(dir, 'checklist_items_0.yml'))
          assert_equal 3, exported_checklist_items.size
          exported_completed_items = exported_checklist_items.select {|c| c["completed"] == "t" || c["completed"] == "1" }.sort_by {|c| c["position"]}
          exported_incomplete_items = exported_checklist_items.select {|c| c["completed"] == "f" || c["completed"] == "0"}.sort_by{|c| c["position"]}
          assert_equal completed_checklist_items, exported_completed_items.map {|c| c["text"]}
          assert_equal incomplete_checklist_items, exported_incomplete_items.map {|c| c["text"]}
        end
      end
    end

    def test_should_not_include_depenedency_attachments
      project1 = create_project(:name => "Project1", :identifier => "project_1")
      project2 = create_project(:name => "Project2", :identifier => "project_2")
      project1.with_active_project do |p1|
        raising_card = p1.cards.create!(:name => 'p1 card', :card_type_name => 'card')
        dep = raising_card.raise_dependency(
          :name => "First Dependency",
          :resolving_project_id => project2.id,
          :desired_end_date => "2016-01-31"
        )
        dep.save!
        attachment1 = sample_attachment("dependency_attachment.txt")
        dep.attach_files(attachment1)
        dep.save!
        export_file = create_project_exporter!(p1, @user, :template => false).export
        with_unziped_mingle_export(export_file) do |dir|
          exported_attachings = YAML.load_file(File.join(dir, 'attachings_0.yml'))
          assert_equal 0, exported_attachings.size
        end
      end
    end
  end
end
