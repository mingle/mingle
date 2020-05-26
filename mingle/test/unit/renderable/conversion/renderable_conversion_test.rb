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

class RenderableConversionTest < ActiveSupport::TestCase
  include ::RenderableTestHelper

  def setup
    @project = first_project
    @project.activate
    login_as_member
    view_helper.default_url_options = {:project_id => @project.identifier}
  end

  def teardown
    logout_as_nil
    super
  end

  def test_should_not_apply_red_cloth_substitution_to_project_variable_macro
    text_that_red_cloth_should_not_substitute = 'no__italics__'
    setup_project_variable(@project, :name => 'some variable', :data_type => ProjectVariable::STRING_DATA_TYPE, :value => text_that_red_cloth_should_not_substitute)
    page = @project.pages.create!(:name => 'foo')
    page.content = "{{ project-variable name: some variable }}"
    page.redcloth = true
    page.send(:update_without_callbacks)
    assert page.formatted_content(view_helper).include?(text_that_red_cloth_should_not_substitute)
  end

  def test_should_not_apply_red_cloth_substitution_to_project_macro
    text_that_red_cloth_should_not_substitute = 'no__italics__'
    project = create_project(:prefix => text_that_red_cloth_should_not_substitute)
    page = project.pages.create!(:name => 'foo')
    page.content = "{{ project }}"
    page.redcloth = true
    page.send(:update_without_callbacks)

    assert page.formatted_content(view_helper).include?(text_that_red_cloth_should_not_substitute)
  end

  def test_still_renders_when_body_macro_throws_runtime_error
    with_safe_macro("explode", ExplodingBodyMacro) do
      page = @project.pages.create!(:name => 'tnt')
      page.content = %{
        {% explode %}
        foobar
        {% explode %}
        {{ project }}
      }
      page.redcloth = true
      page.send(:update_without_callbacks)

      assert page.formatted_content(view_helper).include?(@project.identifier)
      assert_equal 1, page.macro_execution_errors.size
    end
  end

  # bug 903
  def test_attachments_on_page_with_name_resembling_card_number_works
    p = @project.pages.create(:name => 'whatever')
    p.redcloth = true
    p.content = "!#2Card/cake.gif!"
    p.send(:update_without_callbacks)

    content = p.formatted_content(view_helper)

    assert_match /img .*src=\"#2Card\/cake.gif\"/, content
    assert_match /img .*alt=\"!#2Card\/cake.gif!\"/, content
  end

  def test_convert_redcloth_to_html_should_leave_macros_alone
    page = @project.pages.create!(:name => 'redcloth with macro')
    page.update_attributes(:content => '{{ project }}', :redcloth => true)
    assert page.redcloth

    page.reload.convert_redcloth_to_html!
    assert_equal '{{ project }}', page.content
  end

  def test_convert_redcloth_to_html_should_leave_content_as_html
    page = @project.pages.create!(:name => 'not redcloth')
    page.update_attributes(:content => 'h1. redcloth', :redcloth => true)
    assert page.redcloth

    page.convert_redcloth_to_html!
    assert_equal '<h1>redcloth</h1>', page.content
    assert_false page.redcloth
  end

  def test_convert_redcloth_to_html_should_convert_body_macros
    macro = <<-REDCLOTH
    {% dashboard-panel %}
      here *I* am
    {% dashboard-panel %}
    REDCLOTH

    page = @project.pages.create!(:name => 'not redcloth', :content => macro)
    page.convert_redcloth_to_html!
    assert_dom_equal '<div class="dashboard-panel">here <strong>I</strong> am</div>', page.content
  end

  def test_convert_redcloth_to_html_should_preserve_wiki_links
    content = "<br />\r\n[[Reporting Sandbox]] -- use this to experiment with new reporting ideas"
    page = @project.pages.create!(:name => 'with wiki links', :content => content)
    page.convert_redcloth_to_html!
    expected_page_content = Nokogiri::HTML.parse("<p><br />\n[[Reporting Sandbox]]—use this to experiment with new reporting ideas</p>").text
    assert_equal expected_page_content, Nokogiri::HTML.parse(page.content).text
  end

  def test_convert_redcloth_to_html_should_leave_relative_images_alone
    content = "!some_image.png!"
    page = @project.pages.create!(:name => 'with inline images', :content => content)
    page.convert_redcloth_to_html!
    assert_equal content, page.content
  end

  def test_convert_redcloth_to_html_should_convert_url_images_to_img_tags
    content = "!http://ian.carvell.com/fancy_duck.jpg!"
    page = @project.pages.create!(:name => 'with external image', :content => content)
    page.convert_redcloth_to_html!
    assert_dom_equal "<img alt=\"!http://ian.carvell.com/fancy_duck.jpg!\" src=\"http://ian.carvell.com/fancy_duck.jpg\" />", page.content
  end

  def test_convert_redcloth_to_html_should_leave_card_links_alone
    content = "#1"
    page = @project.pages.create!(:name => 'with card link', :content => content)
    page.convert_redcloth_to_html!
    assert_equal "<p>#{content}</p>", page.content
  end

  # test for bug #791
  def test_attachments_with_card_number_in_name_are_not_expanded_to_card_links_in_pages_that_have_not_been_converted_from_redcloth
    p = @project.pages.create(:name => '1', :content => "card790")
    assert_dom_equal %{<a href="/projects/first_project/cards/790" class="card-tool-tip card-link-790" data-card-name-url="/projects/first_project/cards/card_name/790">card790</a>}, p.formatted_content(view_helper)

    p = @project.pages.create(:name => '2')
    p.update_attributes(:content => "!card790.jpg!", :redcloth => true)

    assert_dom_equal '<img src="card790.jpg" alt="!card790.jpg!" />', p.formatted_content(view_helper)
  end

  def test_should_escape_tags_located_in_pre_or_code_tags
    card = @project.cards.first
    card.redcloth=true
    card.send(:update_without_callbacks)

    card.update_attribute :description, '<pre><script></script></pre>'
    assert_equal '<pre>&lt;script&gt;&lt;/script&gt;</pre>', card.formatted_content(view_helper)

    card.update_attribute :description, '<code><script></script></code>'
    assert_equal '<code>&lt;script&gt;&lt;/script&gt;</code>', card.formatted_content(view_helper)

    card.update_attribute :description, '<pre>here is some code: <code><script></script></code></pre>'
    assert_equal '<pre>here is some code: &lt;code&gt;&lt;script&gt;&lt;/script&gt;&lt;/code&gt;</pre>', card.formatted_content(view_helper)

    card.update_attribute :description, %Q{<CODE>
      <something>works</something>
      <something>works too</something>
    </code>}
    assert_dom_equal "<code>\n      &lt;something&gt;works&lt;/something&gt;\n      &lt;something&gt;works too&lt;/something&gt;\n    </code>", card.formatted_content(view_helper)
  end

  def test_should_show_error_when_body_macro_timeout
    with_safe_macro("timeout_body", TimeoutBodyMacro) do
      page = @project.pages.create!(:name => "redcloth")
      page.update_attributes(:redcloth => true, :content => %{
        {% timeout_body %}
        foo bar
        {% timeout_body %}
      })

      assert page.redcloth
      assert_equal "Timeout rendering: redcloth", page.formatted_content(view_helper)
    end
  end

  class DummyScriptMacro < Macro
    def execute
      "<script>alert('1')</SCRIPT>"
    end
  end

  def test_for_bug6169
    with_built_in_macro_registered('dummy', DummyScriptMacro) do
      card = @project.cards.first
      card.redcloth = true
      card.description = <<-MACRO
  {% left-column %}
  {{ dummy }}
  {% left-column %}

  {% right-column %}
  {{ dummy }}
  {% right-column %}
MACRO
      card.send(:update_without_callbacks)
      formated_result = "<div class=\"yui-u first\">\n<script>alert('1')</script>\n\n\n</div>\n<div class=\"yui-u\">\n\n<script>alert('1')</script>\n\n\n</div>"
      assert_dom_equal formated_result, card.formatted_content(view_helper)
    end
  end

  def test_should_escape_error_messages_in_body_macro
    macro = '{% <h1>hello</h1> %} something {% <h1>hello</h1> %}'
    card = card_with_redcloth_content(macro)
    assert_dom_equal %[<div contenteditable="false" raw_text="#{URI.escape macro}" class="error macro">No such macro: #{'&lt;h1&gt;hello&lt;/h1&gt;'.bold}</div>], card.formatted_content(view_helper)
  end

  def test_notextile_should_work
    card = card_with_redcloth_content("<notextile>h1. show</notextile>")
    assert_equal "h1. show", card.formatted_content(view_helper)
  end

  class TestProjectMacro < Macro
    def execute
      'project'
    end
  end

  def test_url_with_embedded_macro_should_be_converted_to_url_having_macro_value
    card = card_with_redcloth_content("h3. Feature ranker - https://minglehosting.thoughtworks.com/asurint/projects/asurint_sdlc_project/cards/grid?rank_is_on=true&tab=All&color_by=status&filters%5B%5D=%5BType%5D%5Bis%5D%5BStory%5D&filters%5B%5D=%5BFeature%5D%5Bis%5D%5B{{ project }}%5D&filters%5B%5D=%5BStatus%5D%5Bis+less+than%5D%5BIn+Development%5D")
    with_built_in_macro_registered('project', TestProjectMacro) do
      card.convert_redcloth_to_html!


      expected_regex = /Feature%5D%5Bis%5D%5Bproject/

      assert_match expected_regex, card.content.trim
    end
  end

end
