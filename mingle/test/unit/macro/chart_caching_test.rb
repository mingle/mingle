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

class ChartCachingTest < ActiveSupport::TestCase
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
    logout_as_nil
    Renderable.disable_caching
  end
  
  def test_should_write_to_cache_when_charting
    with_safe_macro("hello-chart", HelloChart) do
      template = "{{ hello-chart }}"
      page = @project.pages.create!(:name => 'heyo', :content => template)
      chart_type = 'hello'
      chart_position = 1
      chart = Chart.extract_and_generate(template, chart_type, chart_position, :content_provider => page)
      assert_equal 'hello chart image goes here', chart
      assert_equal 'hello chart image goes here', Caches::ChartCache.get(page, chart_type, chart_position)
    end
  end
  
  def test_should_not_write_to_chart_cache_if_renderable_cache_is_disabled
    Renderable.disable_caching
    with_safe_macro("hello-chart", HelloChart) do
      template = "{{ hello-chart }}"
      page = @project.pages.create!(:name => 'heyo', :content => template)
      chart_type = 'hello'
      chart_position = 1
      chart = Chart.extract_and_generate(template, chart_type, chart_position, :content_provider => page)
      assert_equal 'hello chart image goes here', chart
      assert_nil Caches::ChartCache.get(page, chart_type, chart_position)
    end
  end

  def test_should_clear_chart_cache_when_renderable_with_macros_cache_is_cleared
    with_safe_macro("hello", HelloMacro) do
      with_safe_macro("hello-chart", HelloChart) do
        page_one = @project.pages.create!(:name => 'tnt', :content => "{{ hello }}")
        page_one.formatted_content(self)
        assert_equal "hello", Caches::RenderableWithMacrosCache.get(page_one)

        page_two = @project.pages.create!(:name => 'dynamite', :content => "{{ hello-chart }}")
        chart_type = 'hello'
        chart_position = 1
        chart = Chart.extract_and_generate("{{ hello-chart }}", chart_type, chart_position, :content_provider => page_two)
        assert_equal 'hello chart image goes here', Caches::ChartCache.get(page_two, chart_type, chart_position)

        @project.cards.create!(:name => 'just to clear the renderable with macros cache', :card_type_name => 'Card')

        assert_nil Caches::RenderableWithMacrosCache.get(page_one)
        assert_nil Caches::ChartCache.get(page_two, chart_type, chart_position)
      end
    end
  end

  def test_should_clear_chart_cache_when_renderable_cache_is_cleared
    with_safe_macro("hello-chart", HelloChart) do
      page_one = @project.pages.create!(:name => 'tnt', :content => "no chart or macros")
      page_one.formatted_content(self)
      assert_equal "no chart or macros", Caches::RenderableCache.get(page_one)
      
      page_two = @project.pages.create!(:name => 'dynamite', :content => "{{ hello }}")
      chart_type = 'hello'
      chart_position = 1
      chart = Chart.extract_and_generate("{{ hello-chart }}", chart_type, chart_position, :content_provider => page_two)
      assert_equal 'hello chart image goes here', Caches::ChartCache.get(page_two, chart_type, chart_position)
      
      @project.pages.create!(:name => 'just to clear the renderables cache')
      
      assert_nil Caches::RenderableCache.get(page_one)
      assert_nil Caches::ChartCache.get(page_two, chart_type, chart_position)
    end
  end
  
  def test_two_charts_with_same_type_and_position_should_be_cached_separately_if_they_are_on_two_different_renderables
    card = @project.cards.first
    page = @project.pages.create!(:name => 'some page')
    
    chart_type = 'hello'
    position = 1
    Caches::ChartCache.add(page, chart_type, position, 'page chart')
    Caches::ChartCache.add(card, chart_type, position, 'card chart')
    
    page_chart = Chart.extract_and_generate("does not matter", chart_type, position, :content_provider => page)
    card_chart = Chart.extract_and_generate("does not matter", chart_type, position, :content_provider => card)
    
    assert_equal "page chart", page_chart
    assert_equal "card chart", card_chart
  end
  
  def test_should_not_cache_cross_project_charts
    with_safe_macro("hello-chart", HelloChart) do
      page_one = @project.pages.create!(:name => 'uses a different project', :content => %{
        {{
          hello-chart
            project: first_project
        }}
      })
      
      chart = Chart.extract_and_generate(page_one.content, 'hello', 1, :content_provider => page_one)
      assert_equal "hello chart image goes here", chart
      assert_nil Caches::ChartCache.get(page_one, 'hello', 1)
    end
  end
  
end
