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
require File.expand_path(File.dirname(__FILE__) + '/../../lib/mingle_upgrade_compatibility/scm_data_migration_helper')

class SCMDataMigrationHelperTest < ActiveSupport::TestCase
  fixtures :git_configurations
  def setup
    @project_data = {:name => 'Project with SCM intergration and Secret Key',
                     :identifier => 'project_with_key',
                     :secret_key => 'diGVu8RVqKbA55MGZ7b4lKJ8F26up20R2M6lzCLCipH6qxczLN*7mwVLz3Gb*MYQb4uOUDbRQ7o'}
    @decrypted_password = 'Mingle!!'
  end

  def test_should_decrypt_string_encrypted_using_crypt_gem_on_ruby18
    create_project(@project_data) do |project|
      repo_config = GitConfiguration.find(1)
      repo_config.update_attribute(:project_id, project.id)

      SCMDataMigrationHelper.migrate(repo_config)

      assert_equal @decrypted_password, repo_config.reload.password
    end
  end

  def test_should_skip_password_migartion_when_password_empty
    create_project(@project_data) do |project|
      repo_config = GitConfiguration.find(2)
      repo_config.update_attribute(:project_id, project.id)

      SCMDataMigrationHelper.migrate(repo_config)

      assert_nil repo_config.reload.password
    end
  end
end
