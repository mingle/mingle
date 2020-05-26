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

class IframeMacroTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit
  def setup
    login_as_member
    @project = first_project
  end

  def test_render
    template = %{{{iframe:
      src: http://getmingle.io
      width: 100
      height: 100
    }}}
    expected = Nokogiri::HTML::DocumentFragment.parse("<iframe src=\"http://getmingle.io\" width=\"100\" height=\"100\"></iframe>").to_xhtml
    assert_equal_ignoring_spaces expected, render(template, @project)
  end

  def test_should_escape_params
    template = %{{{iframe:
      src: http://getmingle.io"
      width: 10"0
      height: 10"0
    }}}
    expected = Nokogiri::HTML::DocumentFragment.parse("<iframe src=\"http://getmingle.io&quot;\" width=\"10&quot;0\" height=\"10&quot;0\"></iframe>").to_xhtml
    assert_equal_ignoring_spaces expected, render(template, @project)
  end

  def test_should_render_macro_placeholder_for_edit_and_preview_mode
    template = %{{{iframe:
      src: http://getmingle.io
      width: 100
      height: 100
    }}}

    assert_equal "<div class=\"macro-placeholder macro\" raw_text=\"%7B%7Biframe:%0A%20%20%20%20%20%20src:%20http://getmingle.io%0A%20%20%20%20%20%20width:%20100%0A%20%20%20%20%20%20height:%20100%0A%20%20%20%20%7D%7D\">Your iframe: will display upon saving</div>", render(template, @project, {}, :formatted_content_editor)
    assert_equal "<div class=\"macro-placeholder\">Your iframe: will display upon saving</div>", render(template, @project, {}, :formatted_content_preview)
  end

  def test_should_render_error_when_site_url_is_https_but_iframe_src_is_not
    template = %{{{iframe:
      src: http://getmingle.io
      width: 100
      height: 100
    }}}

    MingleConfiguration.with_site_u_r_l_overridden_to("https://mingle.tw.com") do
      assert_equal "Cannot render insecure content from 'http://getmingle.io' when Mingle site page is loaded over HTTPS.", render(template, @project)
    end
  end

end
