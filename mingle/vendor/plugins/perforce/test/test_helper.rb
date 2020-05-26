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

require File.expand_path(File.dirname(__FILE__) + '/../../../../test/unit_test_helper')
$LOAD_PATH.unshift(File.expand_path(File.dirname(__FILE__) + '/../rscm-0.2.1/lib'))
require "rscm"
require File.expand_path(File.dirname(__FILE__) + "/repositoryp4_driver")


class ActiveSupport::TestCase
  
  def init_p4_driver_and_repos(test_repos_name="#{RAILS_ROOT}/test/data/test_repository")
    ENV['P4PORT'] = nil
    ENV['P4USER'] = nil
    ENV['P4CLIENT'] = nil
    ENV['P4PASSWORD'] = nil
    ENV['P4ROOT'] = nil
    @driver = Repositoryp4Driver.new(unique_name('p4_test'))
    @driver.create
    sleep(1)
    @driver.import(test_repos_name)
    @driver.checkout
    @repos = create_repository(@driver.wc_dir)
  end
  
  def create_repository(path, version_control_users={})
    PerforceRepository.new(version_control_users, 'ice_user', nil, @driver.depot_name)
  end

end
