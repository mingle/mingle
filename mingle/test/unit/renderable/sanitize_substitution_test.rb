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

class SanitizeSubstitutionTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit

  DEFAULT_ALLOWED_TAGS = ActionView::Base.sanitized_allowed_tags.dup
  DEFAULT_ALLOWED_ATTRIBUTES = ActionView::Base.sanitized_allowed_attributes.dup

  def setup
    @project = first_project
    @project.activate
    @substitution = Renderable::SanitizeSubstitution.new(:project => @project, :content_provider => nil, :view_helper => view_helper)
  end

  def test_should_allow_table_tags
    table = %{<table><th><td>head</td></th><tr><td>cell</td></tr></table>}
    assert_dom_equal table, @substitution.apply(table)
  end
  def test_allowed_html_tags
    html = %{<strong><div><h1>totle</h1></div></strong>}
    assert_equal html, @substitution.apply(html)
  end
  def test_allow_style_attribute
    html = %{<div style="color: red;"></div>}
    assert_equal html, @substitution.apply(html)
  end
  def test_allowed_attributes
    html = %{<div height="1" width="2"></div>}
    assert_dom_equal html, @substitution.apply(html)
  end
  def test_should_not_change_default_sanitized_allowed_tags
    html = %{<div height="1" width="2"></div>}
    @substitution.apply(html)
    assert_equal DEFAULT_ALLOWED_TAGS, ActionView::Base.sanitized_allowed_tags
    assert_equal DEFAULT_ALLOWED_ATTRIBUTES, ActionView::Base.sanitized_allowed_attributes
  end

  def test_should_sanitize_style_properties
    html = %{<div style="color: red; background-image: expression(alert('xss'))"></div>}
    assert_equal %{<div style=""></div>}, @substitution.apply(html)
  end

  def test_should_allow_attributes_that_red_cloth_outputs
    ['colspan', 'class', 'rowspan', 'lang', 'id', 'target'].each do |attr_name|
      html = %{<div #{attr_name}="abc"></div>}
      assert_equal html, @substitution.apply(html)
    end
  end

  def test_should_allow_accesskey_for_url
    html = %{<a accesskey="D"></a>}
    assert_equal html, @substitution.apply(html)
  end

  def test_allow_cross_site_link
    html = %{<a href="www.mingle.com">mingle</a>}
    assert_equal html, @substitution.apply(html)
  end

  def test_allow_cross_site_image
    html = %{<img src="www.mingle.com/img" />}
    assert_equal html, @substitution.apply(html)
  end

end
