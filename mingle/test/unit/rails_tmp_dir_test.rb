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

class RailsTmpDirTest < ActiveSupport::TestCase  
  include FileUtils
  
  def setup
    @project = Project.new :identifier => 'tmp_dir_test'
    @card_import = CardImporter.new do |import|
      import.id      = 123
      import.project = @project
    end
    @card_importing_preview = CardImportingPreview.new do |preview|
      preview.id      = 456
      preview.project = @project
    end
  end
  
  def test_file_name_returns_mingle_tmp_dir_prefixed_file_name
    folders = [RAILS_TMP_DIR, 'card_imports', @project.identifier, "ID-data.txt"]
    assert_equal File.join(*folders), RailsTmpDir.file_name('card_imports', 'tmp_dir_test', 'ID-data.txt')
  end
  
  def test_file_path_returns_mingle_tmp_dir_prefixed_file_path
    folders = [RAILS_TMP_DIR, 'foo', 'bar']
    assert_equal File.join(*folders), RailsTmpDir.file_path('foo', 'bar')
  end

  def test_database_dump_has_correct_file_name
    folders = [RAILS_TMP_DIR, 'test_db_dump.sql']
    assert_equal File.join(*folders), RailsTmpDir::Database.file.pathname
  end
  
  def test_repository_driver_repos_pathname_is_correct
    name = 'my_repos'
    folders = [RAILS_TMP_DIR, 'test', 'cached_svn', name.md5, 'repos']
    assert_equal File.join(*folders),  RailsTmpDir::RepositoryDriver.repos(name).pathname
  end
  
  def test_repository_driver_wc_pathname_is_correct
    name = 'my_repos'
    folders = [RAILS_TMP_DIR, 'test', 'cached_svn', name.md5, 'wc']
    assert_equal File.join(*folders),  RailsTmpDir::RepositoryDriver.wc(name).pathname
  end
  
  def test_broker_repository_returns_correct_file_pathname
    folders = [RAILS_TMP_DIR, 'brokers', 'test', 'messaging_broker.pstore']
    assert_equal File.join(*folders),  RailsTmpDir::BrokerRepository.file.pathname
  end

  def test_pdf_export_returns_correctly_pathed_random_file
    folders = [RAILS_TMP_DIR, 'pdf_export']
    assert_equal File.join(*folders), RailsTmpDir::PdfExport.file.dirname
    assert_match(/.*pdf_\w+\.html$/, RailsTmpDir::PdfExport.file.pathname)
  end

  def test_project_export_new_temporary_directory_returns_correctly_assembled_directory
    Clock.now_is(:year => 2009, :month => 1, :day => 1) do |now|
      folders = [RAILS_TMP_DIR, 'exports', @project.identifier, now.to_i.to_s]
      FileUtils.rm_rf File.join(*folders)
      assert_equal File.join(*folders), RailsTmpDir::ProjectExport.new_temporary_directory(@project).dirname
    end
  end
  
  def test_project_export_new_temporary_directory_returns_only_new_unique_directory
    path_one = RailsTmpDir::ProjectExport.new_temporary_directory(@project).dirname
    path_two = RailsTmpDir::ProjectExport.new_temporary_directory(@project).dirname
    assert_not_equal path_one, path_two
  ensure
    FileUtils.rm_rf path_one if path_one && File.exist?(path_one)
    FileUtils.rm_rf path_two if path_two && File.exist?(path_two)
  end

  def test_dir_proxy_dirname_returns_correctly_pathed_path
    folders = [ RAILS_TMP_DIR, 'tmp_dir_test', 'foo' ]
    assert_equal File.join(*folders), RailsTmpDir::RailsTmpDirProxy.new(['tmp_dir_test', 'foo']).dirname
  end
  
  def test_dir_proxy_create_will_mkdir_the_specified_directory_path
    folders = [ RAILS_TMP_DIR, 'tmp_dir_test', 'foo' ]
    FileUtils.rm_rf File.join(*folders) if File.exist?(File.join(*folders))
    RailsTmpDir::RailsTmpDirProxy.new(['tmp_dir_test', 'foo']).create
    assert File.exist?(File.join(*folders))
  ensure
    FileUtils.rm_rf File.join(*folders) if File.exist?(File.join(*folders))
  end
  
  def test_dir_proxy_exist_returns_true_if_specified_path_actually_exists
    folders = [ RAILS_TMP_DIR, 'tmp_dir_test', 'foo' ]
    FileUtils.mkdir_p File.join(*folders)
    assert RailsTmpDir::RailsTmpDirProxy.new(['tmp_dir_test', 'foo']).exist?
  ensure
    FileUtils.rm_rf File.join(*folders) if File.exist?(File.join(*folders))
  end

  def test_dir_proxy_exist_returns_false_if_specified_path_does_not_exist
    folders = [ RAILS_TMP_DIR, 'tmp_dir_test', 'foo' ]
    FileUtils.rm_rf File.join(*folders)
    assert_false RailsTmpDir::RailsTmpDirProxy.new(['tmp_dir_test', 'foo']).exist?
  end

  def test_dir_proxy_zip_to_raise_exception_if_directory_to_zip_does_not_yet_exist
    assert_raise RuntimeError do
      RailsTmpDir::RailsTmpDirProxy.new(['tmp_dir_test', 'foo']).zip
    end
  end
  
  def test_dir_proxy_zip_will_zip_all_folder_contents_and_returns_filename
    folders = [ RAILS_TMP_DIR, 'tmp_dir_test', 'foo' ]
    target_zip_pathname = File.join(folders) + '.zip'
    FileUtils.mkdir_p File.join(folders)
    FileUtils.touch File.join(folders, 'any.txt')
    FileUtils.rm_rf target_zip_pathname
    assert_equal target_zip_pathname, RailsTmpDir::RailsTmpDirProxy.new(['tmp_dir_test', 'foo']).zip
    assert File.exist?(target_zip_pathname)
  ensure
    FileUtils.rm_rf File.join(folders)
    FileUtils.rm_rf target_zip_pathname
  end
  
  def test_dir_proxy_zip_will_remove_zipped_directory_once_zip_file_is_generated
    folders = [ RAILS_TMP_DIR, 'tmp_dir_test', 'foo' ]
    FileUtils.mkdir_p File.join(folders)
    FileUtils.touch File.join(folders, 'any.txt')
    RailsTmpDir::RailsTmpDirProxy.new(['tmp_dir_test', 'foo']).zip
    assert_false File.exist?(File.join(*folders))
  end
  
  def test_file_proxy_read_reads_content_of_correct_warning_file
    file_name = "#{Time.now.to_i}.txt"
    path = File.join(RAILS_TMP_DIR, 'tmp_dir_test')
    mkdir_p path
    full_path = File.join(path, file_name)
    File.open(full_path, 'w') { |f| f.write("abc") }    
    assert_equal "abc", RailsTmpDir::RailsTmpFileProxy.new(['tmp_dir_test', file_name]).read
  ensure
    rm_rf File.dirname(path)
  end
  
  def test_file_proxy_write_truncates_then_write_to_correct_file
    file_name = "#{Time.now.to_i}.txt"
    RailsTmpDir::RailsTmpFileProxy.new(file_name).write('ABC')
    RailsTmpDir::RailsTmpFileProxy.new(file_name).write('ABC')
    assert_equal 'ABC', File.read(File.join(RAILS_TMP_DIR, file_name))
  ensure
    rm File.join(RAILS_TMP_DIR, file_name)
  end
  
  def test_file_proxy_delete_destroys_existing_file
    full_path = File.join(RAILS_TMP_DIR, 'test_file_proxy_delete_destroys_existing_file.txt')
    touch full_path
    proxy = RailsTmpDir::RailsTmpFileProxy.new %w(test_file_proxy_delete_destroys_existing_file.txt)
    proxy.delete
    assert !File.exist?(full_path)
  end
  
  def test_file_proxy_delete_does_not_bomb_if_file_does_not_exist
    file_name = "#{Time.now.to_i}.txt"
    proxy = RailsTmpDir::RailsTmpFileProxy.new file_name
    assert_nothing_raised { proxy.delete }
  end
  
  def test_file_proxy_readlines_returns_array_of_file_content
    full_path = File.join(@project.identifier, 'test_file_proxy_readlines_returns_array_of_file_content.txt')
    proxy = RailsTmpDir::RailsTmpFileProxy.new full_path
    proxy.write("ABC\nDEF")
    lines = proxy.readlines
    assert_equal "ABC\n", lines[0]
    assert_equal 'DEF', lines[1]
  end
  
  def test_file_proxy_dirname_returns_just_the_directories_of_given_file
    parts = ['card_importing_preview', @project.identifier, '456-data.txt']
    assert_equal File.join(RAILS_TMP_DIR, 'card_importing_preview', @project.identifier), RailsTmpDir::RailsTmpFileProxy.new(parts).dirname
  end
  
  def test_file_proxy_basename_returns_just_the_basename_of_given_file
    basename = '456-data.txt'
    parts = ['card_importing_preview', @project.identifier, basename]
    assert_equal basename, RailsTmpDir::RailsTmpFileProxy.new(parts).basename
  end
  
end
