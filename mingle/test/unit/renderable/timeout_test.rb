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

class Renderable::TimeoutTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit
  use_memcached_stub

  def setup
    @project = first_project
    @project.activate
    login_as_member
    CACHE.flush_all
  end

  # changed to use real_timeout for bug 7808
  def test_should_show_error_when_macro_timeout
    old_max_formatting_time = Renderable::Timeout::MAX_FORMATTING_TIME
    Constant.set('host' => 'Renderable::Timeout', 'const' => 'MAX_FORMATTING_TIME', 'value' => 1)
    with_safe_macro("real_timeout", RealTimeoutMacro) do
      [:formatted_content, :formatted_content_preview].each do |render_method|
        content = "{{ real_timeout }}"

        page = @project.pages.create(:name => 'foo', :content => content)
        assert_equal "Timeout rendering: foo", page.send(render_method, self)
      end
    end
  ensure
    Constant.set('host' => 'Renderable::Timeout', 'const' => 'MAX_FORMATTING_TIME', 'value' => old_max_formatting_time)
  end


  def test_should_show_error_when_macro_timeout_yyi
    old_max_formatting_time = Renderable::Timeout::MAX_FORMATTING_TIME
    MingleConfiguration.overridden_to(formatting_timeout: 50) do
      Constant.set('host' => 'Renderable::Timeout', 'const' => 'MAX_FORMATTING_TIME', 'value' => 1)
      with_safe_macro("real_timeout", RealTimeoutMacro) do
        [:formatted_content, :formatted_content_preview].each do |render_method|
          content = "{{ real_timeout }}"

          page = @project.pages.create(:name => 'foo', :content => content)
          assert_equal "1..5", page.send(render_method, self)
        end
      end
    end
    ensure
      Constant.set('host' => 'Renderable::Timeout', 'const' => 'MAX_FORMATTING_TIME', 'value' => old_max_formatting_time)
  end

  def test_should_not_do_caching_when_timeout
    with_renderable_caching_enabled do
      with_safe_macro("timeout", TimeoutMacro) do
        page = @project.pages.create(:name => 'foo', :content => "{{ timeout }}")
        page.formatted_content(self)
        assert_nil Caches::RenderableCache.get(page)
        assert_nil Caches::RenderableWithMacrosCache.get(page)
      end
    end
  end
end
