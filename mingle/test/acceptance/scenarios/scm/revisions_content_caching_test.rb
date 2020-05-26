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

require File.expand_path(File.dirname(__FILE__) + '/../../../unit_test_helper')
require File.join(Rails.root, 'app/jobs/revisions_content_caching')

class RevisionsContentCachingTest < ActiveSupport::TestCase
  does_not_work_without_subversion_bindings

  def setup
    ActionController::Base.perform_caching = true

    login_as_admin

    @project1 = with_new_project do |project|
      FileUtils.rm_rf File.join(SwapDir::RevisionCache.pathname, project.id.to_s)
      @driver1 = with_cached_repository_driver(name + '_setup_1') do |driver|
        driver.create
        driver.import("#{Rails.root}/test/data/test_repository")
        driver.checkout
        driver.edit_file('a.txt', %{line1})
        driver.commit 'modified a.txt'
        driver.edit_file('a.txt', %{line1\n})
        driver.commit 'modified a.txt'
      end
      configure_subversion_for(project, {:repository_path => @driver1.repos_dir})
      project.save!
      project.cache_revisions
    end

    @project2 = with_new_project do |project|
      FileUtils.rm_rf File.join(SwapDir::RevisionCache.pathname, project.id.to_s)
      @driver2 = with_cached_repository_driver(name + '_setup_2') do |driver|
        driver.create
        driver.import("#{Rails.root}/test/data/test_repository")
        driver.checkout
        driver.edit_file('b.txt', %{line1})
        driver.commit 'modified a.txt'
      end
      configure_subversion_for(project, {:repository_path => @driver2.repos_dir})
      project.save!
      project.cache_revisions
    end
  end

  def teardown
    cleanup_repository_drivers_on_failure
    ActionController::Base.perform_caching = false
  end

  def test_run_once
    RevisionsContentCaching.run_once(2, true)  # test with per-project limit of 2

    view_cache = RevisionsViewCache.new(@project1)
    assert view_cache.fragment_exist?(3)
    assert view_cache.fragment_exist?(2)
    assert !view_cache.fragment_exist?(1)

    view_cache = RevisionsViewCache.new(@project2)
    assert view_cache.fragment_exist?(1)

    RevisionsContentCaching.run_once(2, true)  # test with per-project limit of 2
    view_cache = RevisionsViewCache.new(@project1)
    [1,2,3].each{|rev| assert view_cache.fragment_exist?(rev)}
  end

end
