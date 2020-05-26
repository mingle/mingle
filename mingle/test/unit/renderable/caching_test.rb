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
require File.expand_path(File.dirname(__FILE__) + '/../renderable_test_helper')

class Renderable::CachingTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit
  use_memcached_stub

  def setup
    login_as_member
    @project = renderable_test_project
    @project.activate
    Renderable.enable_caching
    CACHE.flush_all
  end

  def teardown
    Renderable.disable_caching
  end

  def test_should_return_cached_content_if_it_exists
    page = @project.pages.create!(:name => 'foo', :content => 'real content')
    Caches::RenderableCache.add(page, 'fake content in cache')
    assert_equal 'fake content in cache', page.formatted_content(view_helper)
  end

  def test_should_write_to_cache_on_rendering
    page = @project.pages.create!(:name => 'foo', :content => 'content')
    assert_equal 'content', page.formatted_content(view_helper)
    assert_equal 'content', Caches::RenderableCache.get(page)
  end

  def test_should_update_cached_content_on_change_to_page
    page = @project.pages.create!(:name => 'foo', :content => 'content')
    assert_equal 'content', page.formatted_content(view_helper)
    assert_equal 'content', Caches::RenderableCache.get(page)

    page.update_attributes(:content => 'new content')
    assert_equal 'new content', page.formatted_content(view_helper)
    assert_equal 'new content', Caches::RenderableCache.get(page.reload)
  end

  def test_should_retain_cached_content_for_old_versions_after_update
    page = @project.pages.create!(:name => 'foo', :content => 'content')
    page.reload.formatted_content(view_helper)
    page.update_attributes(:content => 'new content')
    page.reload.formatted_content(view_helper)
    page.versions.first.formatted_content(view_helper)
    assert_equal 'new content', Caches::RenderableCache.get(page.reload)
    assert_equal 'content', Caches::RenderableCache.get(page.versions.first)
  end

  def test_should_not_write_to_cache_upon_macro_processing_error
    assert_nil @project.find_property_definition_or_nil('Release123')
    bad_content = "{{ value query: SELECT SUM(Release123)}}"
    page = @project.pages.create!(:name => 'pie page', :content => bad_content)
    page.formatted_content(view_helper)
    assert_nil Caches::RenderableCache.get(page)
    assert_nil Caches::RenderableWithMacrosCache.get(page)
  end

  def test_should_not_do_caching_when_error_happens
    with_safe_macro("explode", ExplodingBodyMacro) do
      page = @project.pages.create!(:name => 'tnt', :content => %{
        {{ explode }}
      })
      page.formatted_content(self)
      assert_nil Caches::RenderableCache.get(page)
      assert_nil Caches::RenderableWithMacrosCache.get(page)
    end
  end

  def test_should_not_do_caching_when_timeout_happens
    with_safe_macro("timeout", TimeoutMacro) do
      page = @project.pages.create!(:name => 'tnt', :content => %{
        {{ timeout }}
      })
      page.formatted_content(self)
      assert_nil Caches::RenderableCache.get(page)
      assert_nil Caches::RenderableWithMacrosCache.get(page)
    end
  end

  def test_should_use_macro_key_in_path_when_renderable_contains_a_macro
    with_safe_macro("hello", HelloMacro) do
      page = @project.pages.create!(:name => 'tnt', :content => %{
        {{ hello }}
      })
      page.formatted_content(self)
      assert_equal_ignoring_spaces "hello", Caches::RenderableWithMacrosCache.get(page)
      assert_nil Caches::RenderableCache.get(page)
    end
  end

  def test_should_use_macro_key_to_retrieve_cached_renderable_content_with_macros
    with_safe_macro("hello", HelloMacro) do
      page = @project.pages.create!(:name => 'tnt', :content => %{
        {{ hello }}
      })
      Caches::RenderableWithMacrosCache.add(page, 'non-hello content - but in cache anyway')
      assert_equal 'non-hello content - but in cache anyway', page.formatted_content(self)
    end
  end

  def test_should_use_appropriate_cache_to_fetch_cached_content_for_page
    with_safe_macro("hello", HelloMacro) do
      page = @project.pages.create!(:name => 'foo', :content => 'content')
      page.update_attributes(:content => "{{ hello }}")
      page.update_attributes(:content => 'new content')

      version_without_macro, version_with_macro, later_version_without_macro = *page.reload.versions

      Caches::RenderableCache.add(version_without_macro, 'c1')
      Caches::RenderableWithMacrosCache.add(version_with_macro, 'c2')
      Caches::RenderableCache.add(later_version_without_macro, 'c3')
      Caches::RenderableCache.add(page, 'c4')

      assert_equal 'c1', version_without_macro.formatted_content(view_helper)
      assert_equal 'c2', version_with_macro.formatted_content(view_helper)
      assert_equal 'c3', later_version_without_macro.formatted_content(view_helper)
      assert_equal 'c4', page.formatted_content(view_helper)
    end
  end

  def test_should_using_different_cache_for_embed_chart_option
    with_safe_macro("hello", HelloMacro) do
      page = @project.pages.create!(:name => 'tnt', :content => %{
        {{ hello }}
      })
      Caches::RenderableWithMacrosCache.add(page, 'hello cached content with embed chart false', {:embed_chart => false})
      Caches::RenderableWithMacrosCache.add(page, 'hello cached content with embed chart true', {:embed_chart => true})
      assert_equal 'hello cached content with embed chart false', page.formatted_content(self, {:embed_chart => false})
      assert_equal 'hello cached content with embed chart true', page.formatted_content(self, {:embed_chart => true})
    end
  end

  def test_should_not_cache_cross_project_macros_ever
    login_as_admin
    first_project = @project
    second_project = create_project(:name => "second_project")
    first_project.with_active_project do |project|
      page = project.pages.create! :name => "foo", :content => "{{ project project: second_project}}"
      page.formatted_content(self)
      assert_nil Caches::RenderableWithMacrosCache.get(page)
      logout_as_nil

      login_as_admin
      page.formatted_content(self)
      assert_nil Caches::RenderableWithMacrosCache.get(page)
    end
  end
end
