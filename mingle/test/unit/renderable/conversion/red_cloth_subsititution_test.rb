#encoding: UTF-8

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

class RedClothSubstitutionTest < ActiveSupport::TestCase
  include ::RenderableTestHelper

  def setup
    login_as_member
    @project = first_project
    @project.activate

    @substitution = Renderable::RedClothSubstitution.new(:project => @project, :content_provider => card_with_redcloth_content("redcloth"), :view_helper => view_helper)
  end

  # bug 8796
  def test_redcloth_should_not_blow_up_with_tab_characters_in_stack_traces_in_card_content
    s = <<-EOS
        13:         <%= render bulk_edit_card_type_property_editor(@card_selection) -%>
        14:       </div>
        15:      
        16:       <% @card_selection.property_definitions.each do |prop_def| -%>
        17:         <%= render bulk_edit_property_editor(prop_def, @card_selection) -%>
        18:       <% end -%>
        19:     </div>
    EOS
    assert_nothing_raised do
      @substitution.apply(s)
    end
  end

  # bug 7143, 6940
  def test_should_allow_renderable_content_to_render_mingle_special_square_bracket_syntax_in_favorite_filter_url
    expected = '<p>Please look at this <a href="https://mingle09.thoughtworks.com/projects/mingle/cards/list?filters[]=[Type][is][story]&page=1&style=list&tab=All">link</a></p>'
    assert_equal expected,
      @substitution.apply('Please look at this <a href="https://mingle09.thoughtworks.com/projects/mingle/cards/list?filters[]=[Type][is][story]&page=1&style=list&tab=All">link</a>')
  end

  # bug 7143, 6940
  def test_should_not_break_existing_double_connecting_square_bracket_reference_link_redcloth_syntax
    assert_equal '<ul><li>The link is<a href="Bar">here</a></li></ul>'.strip_all, @substitution.apply('* The link is [here][Bar]').strip_all
  end

  def test_should_not_change_anything_inside_macro_markup
    content = "{{ dummy: __something__ }}"
    assert_equal content, @substitution.apply(content.dup)
  end

  def test_multi_macros
    content = %q{
      {{
        dummy:
        __something__
      }}

      {{
        dummy:
        __something__
      }}
    }
    assert_equal content.strip_all, @substitution.apply(content).strip_all
  end

  def test_project_macros
    content = "{{ project }}"
    assert_equal content, @substitution.apply(content.dup)

    content = "       {{ project }}    "
    assert_equal content.strip, @substitution.apply(content.dup)
  end

  def test_macro_inside_html_tag
    content = %Q{
      <a href="\/projects\/{{ project }}\/cards\/new?properties[Type]=Card" accesskey="D"> +Card</a>
    }
    assert_equal "<p>#{content}</p>".strip_all, @substitution.apply(content).strip_all
  end

  def test_multi_macros_and_project_macros_inside_html
    content = %Q{
      {{ dummy: __something__ }}
      <a href="\/projects\/{{ project }}\/cards\/new?properties[Type]=Card" accesskey="D"> +Card</a>
      <a href="\/projects\/{{ project }}\/cards\/new?properties[Type]=Story" accesskey="D"> +Story</a>
      {{ dummy: __something__ }}
    }
    assert_equal content.strip_all, @substitution.apply(content).strip_all
  end

  # bug 13479
  def test_apply_should_correctly_recognize_html_tags
    not_embedded_in_tag = %Q{
      Some text here <- just testing {{ dummy: some kind of operation }}
    }
    expected = %Q{
      <p>Some text here &lt;- just testing {{ dummy: some kind of operation }}</p>
    }
    assert_equal expected.strip, @substitution.apply(not_embedded_in_tag)

    embedded_in_tag = %Q{
      <a href="{{ dummy: some kind of operation }}">foo</a>
    }
    expected = %Q{
      <p><a href="{{ dummy: some kind of operation }}">foo</a></p>
    }
    assert_equal expected.strip, @substitution.apply(embedded_in_tag)
  end

  def test_rip_macro_should_rip_macros_correctly
    assert_equal "{{ some macro }}", @substitution.apply("{{ some macro }}")
    assert_equal "{{ a &gt; b }}", @substitution.apply("{{ a > b }}")
    assert_equal "{{ a &gt; b }} {{ a &lt; b }}", @substitution.apply("{{ a > b }} {{ a < b }}")
    assert_equal "{{ a &gt; &#39;b&#39; }} {{ conditions: a &gt; &#39;b&#39;}}", @substitution.apply("{{ a > 'b' }} {{ conditions: a > 'b'\}}")
    assert_equal "{{ a &gt; &#39;b&#39; - blah: foo }} {{ conditions: a &gt; b\n - blah: foo }}", @substitution.apply("{{ a > 'b' - blah: foo }} {{ conditions: a > b\n - blah: foo }}")
    assert_equal "<p>a &lt; b\n {{ a = &#39;b&#39; }}</p>", @substitution.apply("a < b\n {{ a = 'b' }}")
    assert_equal "<p>a&lt;b\n {{ table\n a: b }}\n {{ table\n a: &#39;x&#39; = &#39;b&#39; }}</p>", @substitution.apply("a<b\n {{ table\n a: b }}\n {{ table\n a: 'x' = 'b' }}")

    assert_equal "x&lt;y\n{{ q : &#39;b&#39; }} {{ q : &#39;y&#39; }}", @substitution.apply("x<y\n{{ q : 'b' }} {{ q : 'y' }}")
    assert_equal "<div id=\"{{ q : &#39;b&#39; }} {{ q : &#39;y&#39; }}\"/>", @substitution.apply("<div id=\"{{ q : 'b' }} {{ q : 'y' }}\"/>")
  end
end
