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
class ImportExportPluginsTest < ActiveSupport::TestCase
  include ProjectImportExportTestHelper
  
  def test_should_raise_error_when_no_plugin_need_exists_while_importing_project
    rails_plugins = Engines.plugins.dup
    @user = login_as_member
    @project = create_project
    @export_file = create_project_exporter!(@project, @user, :template => false).export
    
    assert Engines.plugins['subversion']
    
    Engines.plugins.delete(Engines.plugins['subversion'])

    @project_importer = create_project_importer!(User.current, @export_file)
    project = @project_importer.process!
    asynch_request = AsynchRequest.find_by_deliverable_identifier(project.identifier)
    assert_equal 1, asynch_request.error_count
    assert asynch_request.message[:errors].first =~ /Couldn't find plugin/
  ensure
    Engines.plugins = rails_plugins
  end
  
  def test_should_raise_error_when_current_plugin_version_is_less_then_needed_while_importing_project
    @user = login_as_member
    @project = create_project
    svn_plugin = ::PluginSchemaInfo.find_by_plugin_name('subversion')
    svn_plugin_version = svn_plugin.version_number
    
    assert Engines.plugins['subversion']
    
    @export_file = create_project_exporter!(@project, User.current).export
    svn_plugin.update_version(svn_plugin_version - 1)

    @project_importer = create_project_importer!(User.current, @export_file)
    project = @project_importer.process!
    asynch_request = AsynchRequest.find_by_deliverable_identifier(project.identifier)
    assert_equal 1, asynch_request.error_count
    assert asynch_request.message[:errors].first =~ /This upgrade includes a later version of Mingle plugin/
  ensure
    svn_plugin.update_version(svn_plugin_version)
  end

  def test_should_import_project_with_multiple_migrations_of_a_plugin
    requires_jruby do
      @user = login_as_member
      @project = create_project
    
      @config = TfsscmConfiguration.create!({:project => @project, :server_url => "a-non-empty-url", :collection => 'a-non-empty-collection', :tfs_project  => 'a-non-empty-project', :domain => 'a-non-empty-domain', :username => 'a-non-empty-username', :password => 'a-non-empty-password' })
    
      assert Engines.plugins['mingle_tfs_scm_plugin']
    
      @export_file = create_project_exporter!(@project, User.current).export
    
      @project_importer = create_project_importer!(User.current, @export_file)
      imported_project = @project_importer.process!

      imported_project.with_active_project do |imported_project|
        assert imported_project.repository_configuration
      
        assert_equal 'a-non-empty-url', imported_project.repository_configuration.plugin.server_url
      end
    end
  end

  def test_should_ignore_plugin_schema_when_importing_a_template
    @user = login_as_member
    @project = create_project
    svn_plugin = ::PluginSchemaInfo.find_by_plugin_name('subversion')
    svn_plugin_version = svn_plugin.version_number

    @export_file = create_project_exporter!(@project, User.current, :template => true).export
    svn_plugin.update_version(svn_plugin_version - 1)

    @project_importer = create_project_importer!(User.current, @export_file)
    @project_importer.process!
  ensure
    svn_plugin.update_version(svn_plugin_version)
  end

  def test_export_import_subversion_plugin_data
    @user = login_as_member
    @project = create_project
    SubversionConfiguration.create!({:project_id => @project.id, :username =>"test", :password => "password", :repository_path =>"/a_repos"})
    @export_file = create_project_exporter!(@project, @user).export
  
    @project_importer = create_project_importer!(User.current, @export_file)
    imported_project = @project_importer.process!
    imported_project.with_active_project do |imported_project|
      assert imported_project.repository_configuration
      assert_equal '/a_repos', imported_project.repository_configuration.repository_path
    end
  end
  
  def test_any_plugin_needs_migration
    project_import = DeliverableImportExport::ProjectImporter.new
    assert_false project_import.any_plugin_needs_migration?([{"plugin_name"=>"mingle_tfs_scm_plugin", "version"=>"1"}, {"plugin_name"=>"mingle_tfs_scm_plugin", "version"=>"2"}, {"plugin_name"=>"mingle_tfs_scm_plugin", "version"=>"3"}])
    
    assert project_import.any_plugin_needs_migration?([{"plugin_name"=>"subversion", "version"=>"1"}])
  end
  
  def test_max_plugin_versions
    project_import = DeliverableImportExport::ProjectImporter.new
    assert_equal([{"plugin_name"=>"mingle_tfs_scm_plugin", "version"=>"3"}], project_import.plugins_with_max_version([{"plugin_name"=>"mingle_tfs_scm_plugin", "version"=>"1"}, {"plugin_name"=>"mingle_tfs_scm_plugin", "version"=>"2"}, {"plugin_name"=>"mingle_tfs_scm_plugin", "version"=>"3"}]))
  end
  
    
end
