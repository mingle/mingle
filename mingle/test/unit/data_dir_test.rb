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

class DataDirTest < ActiveSupport::TestCase

  include FileUtils

  def test_mingle_public_directory_path_is_correct
    folders = [MINGLE_DATA_DIR, 'public']
    assert_equal File.join(*folders), DataDir::Public.directory.pathname
  end

  def test_mingle_public_should_tell_attachments_tmp_path
    folders = [RAILS_TMP_DIR, 'attachments-tmp-dir']
    assert_equal File.join(*folders), DataDir::Attachments.tmp_dir.pathname
  end

  def test_mingle_attachemnts_should_tell_directory
    folders = [MINGLE_DATA_DIR, 'public', 'attachments']
    assert_equal File.join(*folders), DataDir::Attachments.directory.pathname
  end

  def test_mingle_public_should_give_random_attachments_directory_path
    assert_match /attachments[\/|\\].{32}/, DataDir::Attachments.random_directory.pathname
  end

  def test_plugin_data_dir_is_under_data_dir
    assert_equal File.join(MINGLE_DATA_DIR, 'plugin_data', 'foo', 'hello'), DataDir::PluginData.pathname('foo', 'hello')
  end

  def test_mingle_public_should_tell_path_of_attachment
      login_as_admin
      with_new_project do |project|
        attachment_file = sample_attachment('attachment.txt')
        attachment = Attachment.new(:project => project, :file => attachment_file)
        folders = [MINGLE_DATA_DIR, 'public', attachment.path.to_s, attachment.file_relative_path.to_s]
        assert_equal File.join(*folders), DataDir::Attachments.file(attachment).pathname
      end
  end

  def test_public_dir_should_be_suffixed_with_app_namespace_if_app_namespace_exists
    MingleConfiguration.with_app_namespace_overridden_to("foo") do
      folders = [MINGLE_DATA_DIR, 'foo', 'public']
      assert_equal File.join(*folders), DataDir::Public.directory.pathname
    end
  end

end
