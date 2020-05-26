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
  class ProjectTemplateExporterTest < ActiveSupport::TestCase
    include Zipper
    include MessagingTestHelper

    def setup
      @user = login_as_member
    end

    def teardown
      logout_as_nil
      Clock.reset_fake
    end

    def test_init_total_for_template_export
      models_and_attachments_and_zipping = ImportExport::TEMPLATE_MODELS().size + 1 + 1
      with_first_project do |project|
        export = create_project_exporter!(project, @user, :template => true)
        assert_equal models_and_attachments_and_zipping, export.total
      end
    end

    def test_failed_template_export_has_correct_status
      with_first_project do |project|
        export = create_project_exporter!(project, @user, :template => true)
        def export.export_models(models, sql_method, &block)
          raise "Forcing failure!"
        end
        export.export
        assert_equal true, export.completed?
        assert_equal true, export.failed?
        assert_equal ["Forcing failure!"], export.error_details
      end
    end

    def test_successful_template_export_has_correct_status
      with_first_project do |project|
        export = create_project_exporter!(project, @user, :template => true)
        export.export
        assert_equal true, export.completed?
        assert_equal false, export.failed?
      end
    end

    def test_export_with_error_raised
      with_first_project do |project|
        assert DeliverableImportExport::ProjectExporter.export_with_error_raised(:project => project, :template => true)

        def project.identifier
          raise "error from project identifier"
        end

        assert_raise RuntimeError do
          DeliverableImportExport::ProjectExporter.export_with_error_raised(:project => project, :template => true)
        end
      end
    end

    def test_export_project_template_should_include_groups
      export_file = create_export_file(true) do |project|
        project.user_defined_groups.create!(:name => 'Group')
      end
      imported_template = create_project_importer!(@user, export_file).process!.reload

      assert_equal ['Group', 'Team'], imported_template.groups.map(&:name).sort
    end

    def test_export_as_template_does_not_include_configured_source_plugins
      Clock.fake_now(:year => 2005, :month => 10, :day => 9, :hour => 8, :min => 7, :sec => 6)
      export_file = create_export_file(true) do |project|
        SubversionConfiguration.create!(:project => project, :repository_path => '/some/sort/of/path')
      end
      project_import = create_project_importer!(@user, export_file)
      imported_project = project_import.process!.reload
      assert_equal 0, SubversionConfiguration.find_all_by_project_id(imported_project.id).size
      assert !imported_project.has_source_repository?
    end


      def test_export_no_murmurs_or_card_murmur_links_for_templates
        export_file = create_export_file(true) do |project|
          murmur = create_murmur :murmur => 'One'
          card   = create_card! :name => 'Uno'
          project.card_murmur_links.create! :murmur_id => murmur.id, :card_id => card.id
        end

        imported_template = create_project_importer!(@user, export_file).process!.reload

        imported_template.with_active_project do |template|
          assert_equal 0, template.murmurs.count
          assert_equal 0, template.card_murmur_links.count
        end
      end


      def test_export_template_should_not_export_secret_key
        login_as_member
        original_secret_key = nil
        export_file = create_export_file(true) do |project|
          original_secret_key = project.secret_key
          assert !original_secret_key.nil?
        end
        imported_project = create_project_importer!(@user, export_file).process!.reload
        assert !imported_project.secret_key.nil?
        assert original_secret_key != imported_project.secret_key #template gets a new secret
      end

      def test_export_template_should_not_export_personal_page_favorites
        with_new_project(:users => [@user]) do |project|
          team_page = project.pages.create(:name => 'team')
          project.favorites.of_pages.create(:favorited => team_page)
          project.favorites.of_pages.personal(@user).create(:favorited => project.pages.create(:name => 'personal'))
          export_file = create_project_exporter!(project, @user, :template => true).export
          with_unziped_mingle_export(export_file) do |dir|
            exported_favorites = YAML.load_file(File.join(dir, 'favorites_0.yml'))
            assert_equal 1, exported_favorites.size
            assert_equal team_page.id.to_s, exported_favorites.first['favorited_id'].to_s
          end
        end
      end

      def test_export_template_should_not_export_personal_card_list_view_favorites
        with_new_project(:users => [@user]) do |project|
          team_favorite = project.card_list_views.create_or_update(:view => {:name => 'Team'}, :style => 'list', :user_id => nil)
          personal_favorite = project.card_list_views.create_or_update(:view => {:name => 'Personal'}, :style => 'list', :user_id => @user.id)
          export_file = create_project_exporter!(project, @user, :template => true).export

          with_unziped_mingle_export(export_file) do |dir|
            exported_card_list_views = YAML.load_file(File.join(dir, 'card_list_views_0.yml'))
            assert_equal 1, exported_card_list_views.size
            assert_equal 'Team', exported_card_list_views.first['name']
          end
        end
      end


      def test_export_template_for_use_in_new_project_should_correctly_handle_project_icon
        requires_jruby do
          template = create_project(:identifier => 'simple_bear', :icon => uploaded_file(icon_file_path("icon.png")))

          exporter = create_project_exporter!(template, @user, :template => true)

          export_file = exporter.export
          with_unziped_mingle_export(export_file) do |dir|
            assert_relative_file_path_in_directory File.join('project', 'icon', template.id.to_s, 'icon.png'), dir
          end
        end
      end

  end
end
