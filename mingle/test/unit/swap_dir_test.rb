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

class SwapDirTest < ActiveSupport::TestCase
  include FileUtils

  def setup
    @project = Project.new :identifier => 'tmp_dir_test'
    @card_import = CardImporter.new.tap do |importer|
      importer.progress = new_progress(123, @project.identifier)
    end
    @card_importing_preview = CardImportingPreview.new.tap do |preview|
      preview.progress = new_progress(456, @project.identifier)
    end
  end

  def new_progress(id, project_identifier)
    Struct.new(:id, :deliverable_identifier).new(id, project_identifier)
  end

  def test_card_import_proxy_pathname_is_correct
    folders = [SWAP_DIR, Mingle::Revision::SWAP_SUBDIR, 'card_imports', @project.identifier, '123-data.txt']
    assert_equal File.join(*folders), SwapDir::CardImport.file(@card_import).pathname
  end

  def test_card_importing_preview_proxy_pathname_is_correct
    folders = [SWAP_DIR, Mingle::Revision::SWAP_SUBDIR, 'card_importing_preview', @project.identifier, '.*-data.txt']
    assert_match /#{File.join(*folders)}/, SwapDir::CardImportingPreview.file(@project).pathname
  end

  def test_progress_bar_pathname_returns_correctly_assembled_error_file_path
    expecteds = [SWAP_DIR, Mingle::Revision::SWAP_SUBDIR, 'card_importer', @project.identifier, '123-error.txt']
    assert_equal File.join(*expecteds), SwapDir::ProgressBar.error_file(@card_import).pathname
  end

  def test_progress_bar_pathname_returns_correctly_assembled_warning_file_path
    expecteds = [SWAP_DIR, Mingle::Revision::SWAP_SUBDIR, 'card_importer', 'tmp_dir_test', '123-warning.txt']
    assert_equal File.join(*expecteds), SwapDir::ProgressBar.warning_file(@card_import).pathname
  end

  def test_project_import_should_tell_relative_path_to_swap_dir
    absolute_folders = [SWAP_DIR, Mingle::Revision::SWAP_SUBDIR, 'imports', '85881236653806']
    relative_folders = ['imports', '85881236653806']
    assert_equal File.join(*relative_folders), SwapDir.relativize(File.join(*absolute_folders))
  end

  def test_project_import_should_tell_absolute_path_to_swap_dir
    absolute_folders = [SWAP_DIR, Mingle::Revision::SWAP_SUBDIR, 'imports', '85881236653806']
    relative_folders = ['imports', '85881236653806']
    assert_equal File.join(*absolute_folders), SwapDir.absolutize(File.join(*relative_folders))
  end

  def test_progress_bar_write_appends_to_end_of_correct_error_file
    file_path = File.join(SWAP_DIR, Mingle::Revision::SWAP_SUBDIR, 'card_importer', @project.identifier, '123-error.txt')

    delete_folder_if_exist(file_path)
    SwapDir::ProgressBar.error_file(@card_import).write('ABC')
    SwapDir::ProgressBar.error_file(@card_import).write('DEF')
    assert_equal 'ABCDEF', File.read(file_path)
  end

  def test_progress_bar_write_appends_to_end_of_correct_warning_file
    full_path = File.join(SWAP_DIR, Mingle::Revision::SWAP_SUBDIR, 'card_importer', @project.identifier, '123-warning.txt')

    delete_folder_if_exist(full_path)
    SwapDir::ProgressBar.warning_file(@card_import).write('ABC')
    SwapDir::ProgressBar.warning_file(@card_import).write('DEF')
    assert_equal 'ABCDEF', File.read(full_path)
  end

  def test_project_export_returns_correctly_assembled_file
    folders = [SWAP_DIR, Mingle::Revision::SWAP_SUBDIR, 'exports']
    assert_equal File.join(*folders), File.dirname(SwapDir::ProjectExport.file(@project).dirname)
    assert_equal "#{@project.identifier}.mingle", SwapDir::ProjectExport.file(@project).basename
  end

  def test_program_export_returns_correctly_assembled_file
    Clock.fake_now(:year => 2013, :month => 01, :day => 01)
    program = program('simple_program')
    folders = [SWAP_DIR, Mingle::Revision::SWAP_SUBDIR, 'program_exports', Clock.now.to_i.to_s]
    export_file = SwapDir::ProgramExport.file(program)
    assert_equal File.join(*folders), export_file.dirname
    assert_equal "#{program.identifier}.program", export_file.basename
  end

  def test_project_import_returns_correct_directory
    assert_match(/#{SWAP_DIR}\/#{Mingle::Revision::SWAP_SUBDIR}\/imports\/\d+$/, SwapDir::ProjectImport.directory)
  end

  def test_progress_bar_pathname_uses_progress_id_if_model_responds_to_progress_method
    def @card_import.progress
      Struct.new(:id, :deliverable_identifier).new(456, 'tmp_dir_test')
    end
    expecteds = [SWAP_DIR, Mingle::Revision::SWAP_SUBDIR, 'card_importer', @project.identifier, '456-error.txt']
    assert_equal File.join(*expecteds), SwapDir::ProgressBar.error_file(@card_import).pathname
  end

  def test_revision_cache_pathname_is_correct
    folders = [SWAP_DIR, 'cache', 'revision']
    assert_equal File.join(*folders), SwapDir::RevisionCache.pathname
  end

  def test_revision_cache_error_file_pathname_is_correct
    folders = [SWAP_DIR, 'cache', 'revision', project_with_fake_repository_config.id.to_s, project_with_fake_repository_config.repository_configuration.plugin_db_id, '890846d.error']
    assert_equal File.join(*folders), SwapDir::RevisionCache.error_file(project_with_fake_repository_config, '890846d').pathname
  end

  def test_revision_cache_file_pathname_is_correct
    folders = [SWAP_DIR, 'cache', 'revision', project_with_fake_repository_config.id.to_s, project_with_fake_repository_config.repository_configuration.plugin_db_id, '890846d.cache']
    assert_equal File.join(*folders), SwapDir::RevisionCache.cache_file(project_with_fake_repository_config, '890846d').pathname
  end

  def test_cache_dir_for_project_can_be_recursively_deleted
    project_cache_dir = File.join(SwapDir::RevisionCache.pathname, project_with_fake_repository_config.id.to_s, project_with_fake_repository_config.repository_configuration.plugin_db_id.to_s)
    subfolder = File.join(project_cache_dir, 'subfolder')
    mkdir_p(project_cache_dir)
    touch(File.join(project_cache_dir, "file"))
    mkdir_p(subfolder)
    touch(File.join(subfolder, 'subfile'))
    SwapDir::RevisionCache.project_cache_dir(project_with_fake_repository_config).delete
    assert_false File.exists?(project_cache_dir)
  end

  def test_export_project_dir_should_invoke_export_dir_name_method
    project = create_project(name: 'project name')
    project.stubs(:export_dir_name).returns('proj_name').once
    export = Export.create
    expected_path = File.join(SWAP_DIR, 'mingle_data_exports', export.id.to_s, export.dirname, 'Projects', 'proj_name' )
    assert_equal expected_path, SwapDir::Export.project_directory(export.id, project)
  end

  def test_export_program_dir_should_invoke_export_dir_name_method
    login_as_admin
    program = create_program('program_name')
    program.stubs(:export_dir_name).returns('prog_name').once
    export = Export.create
    expected_path = File.join(SWAP_DIR, 'mingle_data_exports', export.id.to_s, export.dirname, 'Programs', 'prog_name' )
    assert_equal expected_path, SwapDir::Export.program_directory(export.id, program)
  end

  protected

  def project_with_fake_repository_config
    @project_with_fake_repository_config ||= @project.tap do |project|
      project.id = 1
      def project.repository_configuration
        OpenStruct.new(:plugin_db_id => 'some_number', :project => project)
      end
    end
  end

  def delete_folder_if_exist(file_path)
    rm_rf File.dirname(file_path)
  end


end
