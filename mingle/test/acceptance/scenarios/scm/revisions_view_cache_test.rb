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

class RevisionsViewCacheTest < ActionController::TestCase

  does_not_work_without_subversion_bindings

  def setup
    ActionController::Base.perform_caching = true

    login_as_admin
    @project = create_project
    FileUtils.rm_rf File.join(SwapDir::RevisionCache.pathname, @project.identifier)

    @driver = with_cached_repository_driver(name + '_setup') do |driver|
      driver.create
      driver.import("#{Rails.root}/test/data/test_repository")
      driver.checkout
      driver.edit_file('a.txt', %{line1})
      driver.commit 'modified a.txt'
      driver.edit_file('a.txt', %{line1\n})
      driver.commit 'modified a.txt'
    end

    configure_subversion_for(@project, {:repository_path => @driver.repos_dir})
    @project.save!
    @project.cache_revisions
    @cache = RevisionsViewCache.new(@project)
  end

  def teardown
    cleanup_repository_drivers_on_failure
    ActionController::Base.perform_caching = false
  end

  def test_cache_should_not_effect_current_fragment_store
    originial_store = ActionController::Base.cache_store
    svn_configuration = MinglePlugins::Source.find_for(@project)
    @cache.cache_content_for(1)
    assert_equal originial_store, ActionController::Base.cache_store
  end

  def test_cache_content_for
    svn_configuration = MinglePlugins::Source.find_for(@project)
    @cache.cache_content_for(1)
    assert File.exist?("#{SwapDir::RevisionCache.pathname}/#{@project.id.to_s}/#{svn_configuration.id}/1.cache")
  end

  class OutputBuffer
    attr_reader :output
    def safe_concat(value)
      @output ||= ""
      @output << value
    end
  end

  def test_can_read_cached_data
    view_helper = OpenStruct.new(:output_buffer => OutputBuffer.new)
    svn_configuration = MinglePlugins::Source.find_for(@project)
    @cache.cache_content_for(1)
    @cache.cache(view_helper, 1)
    assert_match(/Changes/, view_helper.output_buffer.output)
  end

  def test_show_fragment_cached
    @cache.cache_content_for(1)
    assert @cache.fragment_exist?(1)
    assert !@cache.fragment_exist?(2)
  end

  def test_error_file_is_written_when_caching_fails_before_rendering
    def @project.repository_revision(revision_number)
      raise "forcing a failure"
    end
    begin
      @cache.cache_content_for(1)
    rescue RuntimeError => e
      assert_equal "forcing a failure", e.message
      assert @cache.error_caching_fragment?(1)
      return
    end
    fail 'should have failed'
  end

  def test_error_file_is_written_when_caching_fails_during_rendering
    repos_revision = @project.repository_revision(1)
    def repos_revision.changed_paths
      raise "this error should cause an error file created for caching failed"
    end
    @project.instance_variable_set(:@failing_repos_revision, repos_revision)
    def @project.repository_revision(revision_number)
      return @failing_repos_revision
    end
    @cache.cache_content_for(1)
    assert @cache.error_caching_fragment?(1)
  end

  def test_successful_caching_removes_error_file
    svn_configuration = MinglePlugins::Source.find_for(@project)
    error_file = "#{SwapDir::RevisionCache.pathname}/#{@project.id.to_s}/#{svn_configuration.id}/1.error"
    FileUtils.mkdir_p(File.dirname(error_file))
    FileUtils.touch(error_file)
    assert @cache.error_caching_fragment?(1)
    @cache.cache_content_for(1)
    assert !@cache.error_caching_fragment?(1)
  end

  def test_remove_error_file
    svn_configuration = MinglePlugins::Source.find_for(@project)
    error_file = "#{SwapDir::RevisionCache.pathname}/#{@project.id.to_s}/#{svn_configuration.id}/1.error"
    FileUtils.mkdir_p(File.dirname(error_file))
    FileUtils.touch(error_file)
    @cache.remove_error_file(1)
    assert !File.exist?(error_file)
  end

  def test_size_should_return_count_of_all_cache_and_error_files
    @cache.cache_content_for(1)
    assert_equal 1, @cache.size

    def @project.repository_revision(revision_number)
      raise "forcing a failure"
    end
    @cache.cache_content_for(2) rescue nil
    assert_equal 2, @cache.size
  end

end
