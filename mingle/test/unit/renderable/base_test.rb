# -*- coding: utf-8 -*-

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

class Renderable::BaseTest < ActiveSupport::TestCase
  include RenderableTestHelper::Unit

  def setup
    login_as_member
    @project = renderable_test_project
    @project.activate
  end

  def test_property_name_including_xml_tag_works_when_quoted
    with_new_project do |project|
      setup_date_property_definition('<start_at>')
      content = %Q[{{value query: SELECT "<start_at>" }}]
      card = create_card!(:number => 10, :name => 'link0', :description => content)
      card.update_attribute(:cp_1, '05 Mar 2013')
      assert_equal '05 Mar 2013', card.formatted_content(self)
    end
  end

  def test_render_multi_macros
    template = %Q{
      <div id="table1">
      {{value query: SELECT COUNT(*)}}
      </div>

      <div id="table2">
      {{value query: SELECT COUNT(*)}}
      </div>
    }
    rendered_template = render(template, @project)
    expected_template = %Q{
    <div id="table1">
    2
    </div>

    <div id="table2">
    2
    </div>}

    assert_equal_ignoring_spaces expected_template, rendered_template
  end

  def test_should_strip_script_tags_within_pre_or_code_tags
    card = @project.cards.first
    card.update_attribute :description, '<pre><script></script></pre>'
    assert_equal '<pre></pre>', card.formatted_content(self)

    card.update_attribute :description, '<code><script></script></code>'
    assert_equal '<code></code>', card.formatted_content(self)

    card.update_attribute :description, '<pre>here is some code: <code><script></script></code></pre>'
    assert_equal '<pre>here is some code: <code></code></pre>', card.formatted_content(self)
  end

  def test_should_escape_tags_located_in_pre_or_code_tags_inside_emails
    card = @project.cards.first
    card.update_attribute(:description, '<pre><script>heyo</script></pre>')
    assert_dom_equal '<pre></pre>', card.formatted_email_content(self)
  end

  def test_should_remove_script_tag_regardless_of_casing
    login_as_member
    with_first_project do |project|
      card = create_card!(:number => 10, :name => 'link0', :description => '<script>javascript content</script><scRipt>javascript content</scRipt><SCRIPT>javascript content</SCRIPT>')
      assert_equal "", card.formatted_content(self)
    end
  end

  def test_should_remove_style_tag_regardless_of_casing
    login_as_member
    with_first_project do |project|
      card = create_card!(:number => 10, :name => 'link0', :description => '<style>javascript content</style><stylE>javascript content</stylE><STYLE>javascript content</STYLE>')
      assert_equal "", card.formatted_content(self)
    end
  end

  def test_should_not_escape_greater_than_and_less_than_chars_in_macro
    login_as_member
    with_first_project do |project|
      card = create_card!(:number => 10, :name => 'link0', :description => '{{ value query: select number where number > 0 and number < 2}}')
      assert_equal_ignoring_spaces "1", card.formatted_content(self)
    end
  end

  def test_should_escape_error_messages_in_macro
    login_as_member
    with_first_project do |project|
      macro = '{{ value query: select "<h1>hello</h1>"}}'
      card = create_card!(:number => 10, :name => 'link0', :description => macro)

      expected = %Q{<div contenteditable="false" class="error macro" raw_text="#{URI.escape macro}">Error in value macro using Project One project: Card property '#{'&lt;h1&gt;hello&lt;/h1&gt;'.bold}' does not exist!</div>}
      assert_dom_equal expected, card.formatted_content(self)
    end
  end

  def test_render_card_number
    rendered_link = "<a href=\"http://example.com/projects/#{@project.identifier}/cards/10\" class=\"card-tool-tip card-link-10\" data-card-name-url=\"http://example.com/projects/#{@project.identifier}/cards/card_name/10\">#10</a>"
    card = create_card!(:number => 10, :name => 'link', :description => '#10')
    assert_dom_equal rendered_link, card.formatted_email_content(self)
    card = create_card!(:number => 11, :name => 'link1', :description => 'card: #10')
    assert_dom_equal "card: #{rendered_link}", card.formatted_email_content(self)

    card = create_card!(:number => 12, :name => 'link2', :description => '<a href="/xxx/xx#2;">aaa</a> <b #2>2</b>')
    assert_dom_equal "<a href=\"/xxx/xx#2;\">aaa</a> <b #2>2", card.formatted_email_content(self)
  end

  def test_escape_card_number_rendering
    card = create_card!(:number => 10, :name => 'link', :description => '<escape>#10</escape>')
    assert_equal "#10", card.formatted_email_content(self)
  end

  def test_render_cross_project_card_link
    card = create_card!(:name => 'link', :description => 'first_project/#1')
    assert_dom_equal '<a href="http://example.com/projects/first_project/cards/1" class="card-link-1">first_project/#1</a>', card.formatted_email_content(self)

    card = create_card!(:name => 'link', :description => 'notexist /#1')
    assert_dom_equal "notexist /<a href=\"http://example.com/projects/renderable_test_project/cards/1\" class=\"card-tool-tip card-link-1\" data-card-name-url=\"http://example.com/projects/renderable_test_project/cards/card_name/1\">#1</a>", card.formatted_email_content(self)

    card = create_card!(:name => 'link', :description => 'first_project/blah 1')
    assert_dom_equal 'first_project/blah 1', card.formatted_email_content(self)
  end

  #bug 1777
  def test_render_link
    card = create_card!(:number => 10, :name => 'link', :description => 'http://foo.com/blah?a=a&b=b')
    assert_equal "<a href=\"http://foo.com/blah?a=a&amp;b=b\" target=\"_blank\">http://foo.com/blah?a=a&amp;b=b</a>", card.formatted_content(self)
    card = create_card!(:number => 11, :name => 'link2', :description => 'http://foo.com/blah?a=a&b=&#38;')
    assert_equal "<a href=\"http://foo.com/blah?a=a&amp;b=%26\" target=\"_blank\">http://foo.com/blah?a=a&amp;b=%26</a>", card.formatted_content(self)
    card = create_card!(:number => 12, :name => 'link3', :description => 'http://foo.com/blah?a=a&b=%26&lt;&gt;&amp;')
    assert_equal "<a href=\"http://foo.com/blah?a=a&amp;b=%26&lt;&gt;&amp;\" target=\"_blank\">http://foo.com/blah?a=a&amp;b=%26&lt;&gt;&amp;</a>", card.formatted_content(self)
  end

  #bug 1790
  def test_render_link_2
    card = create_card!(:number => 10, :name => 'link0', :description => 'http://www.thoughtworks-studios.com/mingle/help/help.htm#StartTopic=mingle_pages/wiki_page.htm')
    assert_equal "<a href=\"http://www.thoughtworks-studios.com/mingle/help/help.htm#StartTopic=mingle_pages/wiki_page.htm\" target=\"_blank\">http://www.thoughtworks-studios.com/mingle/help/help.htm#StartTopic=mingle_pages/wiki_page.htm</a>", card.formatted_content(self)

    card = create_card!(:number => 11, :name => 'link1', :description => 'http://www.thoughtworks-studios.com/mingle/help/help.htm#StartTopic=mingle_pages/wiki_page.htm not link')
    assert_equal "<a href=\"http://www.thoughtworks-studios.com/mingle/help/help.htm#StartTopic=mingle_pages/wiki_page.htm\" target=\"_blank\">http://www.thoughtworks-studios.com/mingle/help/help.htm#StartTopic=mingle_pages/wiki_page.htm</a> not link", card.formatted_content(self)

    card = create_card!(:number => 12, :name => 'link2', :description => "http://www.thoughtworks-studios.com/mingle/help/help.htm#StartTopic=mingle_pages/wiki_page.htm\nnot link")
    assert_equal "<a href=\"http://www.thoughtworks-studios.com/mingle/help/help.htm#StartTopic=mingle_pages/wiki_page.htm\" target=\"_blank\">http://www.thoughtworks-studios.com/mingle/help/help.htm#StartTopic=mingle_pages/wiki_page.htm</a>\nnot link", card.formatted_content(self)
  end

  #1792
  def test_render_link_3
    card = create_card!(:number => 10, :name => 'link0', :description => 'http://server/project/cards/list?columns=Assigned+To%2CIteration&filter_properties[Assigned%20To]=ajensen&filter_properties[Iteration]=1')
    assert_equal "<a href=\"http://server/project/cards/list?columns=Assigned+To%2CIteration&amp;filter_properties[Assigned%20To]=ajensen&amp;filter_properties[Iteration]=1\" target=\"_blank\">http://server/project/cards/list?columns=Assigned+To%2CIteration&amp;filter_properties[Assigned%20To]=ajensen&amp;filter_properties[Iteration]=1</a>", card.formatted_content(self)
  end

  # bug 8467
  def test_should_render_entire_link
    card = @project.cards.create!(:name => 'link', :card_type_name => 'Card', :description => "http://10.2.12.30:8153/cruise/tab/build/detail/sf02/97/build/1/rails")
    assert_dom_equal %{<a href="http://10.2.12.30:8153/cruise/tab/build/detail/sf02/97/build/1/rails" target="_blank">http://10.2.12.30:8153/cruise/tab/build/detail/sf02/97/build/1/rails</a>}, card.formatted_content(self)
  end

  #2617
  def test_should_not_render_link_when_the_text_is_linked_aleady
    card = create_card!(:number => 20, :name  => 'link20', :description => "<a href='#'>should not link #20</a>")
    assert_dom_equal "<a href=\"#\">should not link #20</a>", card.formatted_content(self)
  end

  # test for #906
  def test_table_formatting_with_trailing_space
    # please note the trailing space on the first line of the table
    assert_dom_equal %{
      <table>
        <tbody>
          <tr><td>Name</td><td>iteration</td><td>size</td></tr>
          <tr><td>add address</td><td>10</td><td>7</td></tr>
          <tr><td>email stuff</td><td>22</td><td>17</td></tr>
        </tbody>
      </table>
    }, content_after_conversion(%{
        |Name|    iteration|    size|
        |add address|    10|    7|
        |email stuff|    22|    17|
    })

    assert_dom_equal %{
      <table>
        <tbody>
          <tr><td>wiki</td><td>bad</td></tr>
          <tr><td>whoa</td><td>just</td></tr>
        </tbody>
      </table>
    }, content_after_conversion("|wiki|bad| \r\n\|whoa|just| \r\n")
  end

  def test_pipes_can_be_used
    @project.pages.create(:name => 'User testing')
    @project.pages.create(:name => 'Summary of this output')

    assert_dom_equal %{
      <a href="http://example.com/projects/#{@project.identifier}/wiki/User_testing">User testing</a>
      |
      <a href="http://example.com/projects/#{@project.identifier}/wiki/Summary_of_this_output">Summary of this output</a>
    }, render(%{
        [[ User testing ]] | [[ Summary of this output ]]
    }, @project, {:view_helper => self})
  end

  # fix for bug #651
  def test_two_dashes_in_wiki_link_works
    @project.pages.create(:name => 'User testing - Round three - Output')
    assert_dom_equal %{
      <a href="http://example.com/projects/#{@project.identifier}/wiki/User_testing_-_Round_three_-_Output">
        User testing - Round three - Output
      </a>
    }, render(%{
        [[ User testing - Round three - Output ]]
    }, @project, {:view_helper => self})
  end

  # fix for bug 218
  def test_link_to_non_existent_wiki_page_should_be_different
    assert_dom_equal %{
      <a href="http://example.com/projects/#{@project.identifier}/wiki/wiki_page_no_existent" class="non-existent-wiki-page-link">wiki page no existent</a>
    }, render(%{
        [[ wiki page no existent ]]
    }, @project, {:view_helper => self})
  end

  # fix for bug 1372
  # todo clean up the data setup -- WPC 2008-03-31
  def test_pivot_table_should_make_sure_fit_with_table_formatting_of_redcloth
    with_new_project do |project|
      project.add_member(User.find_by_login('member'))
      UnitTestDataLoader.setup_property_definitions(:iteration => ['one', 'two'], :old_type => ['story'],
        :release => ['one'], :size => [5,7], :status => ['done', 'open'])
      UnitTestDataLoader.setup_numeric_property_definition('estimate', ['1', '2', '4', '8'])
      card1 = project.cards.create!(:number => 1, :name => 'card1', :card_type => project.card_types.first)
      card1.update_attributes(:cp_old_type => 'story', :cp_release => 'one', :cp_iteration => 'one',
        :cp_size => '5', :cp_status => 'done')
      card2 = project.cards.create!(:number => 2, :name => 'card2', :card_type => project.card_types.first)
      card2.update_attributes(:cp_old_type => 'story', :cp_release => 'one', :cp_iteration => 'two',
        :cp_size => '7', :cp_status => 'open')

      setup_property_definitions :old_type => ['story'], :size => [5,7], :status => ['done', 'fixed', 'open', 'new', 'closed', 'in progress']

      expect = %{
        the pivot table below does not show defects without priority on igor

        <table>
          <tbody>
          <tr>
            <th>&nbsp; </th>
            <th> done </th>
            <th>fixed</th>
            <th>open</th>
            <th>new</th>
            <th>closed</th>
            <th>in progress</th>
            <th>(not set) </th>
          </tr>
          <tr>
            <th>5</th>
            <td> 1 </td>
            <td> &nbsp; </td>
            <td> &nbsp; </td>
            <td> &nbsp; </td>
            <td> &nbsp; </td>
            <td> &nbsp; </td>
            <td> &nbsp; </td>
          </tr>
          <tr>
            <th>7</th>
            <td> &nbsp; </td>
            <td> &nbsp; </td>
            <td> 1 </td>
            <td> &nbsp; </td>
            <td> &nbsp; </td>
            <td> &nbsp; </td>
            <td> &nbsp; </td>
          </tr>
          <tr>
            <th>(not set) </th>
            <td> &nbsp; </td>
            <td> &nbsp; </td>
            <td> &nbsp; </td>
            <td> &nbsp; </td>
            <td> &nbsp; </td>
            <td> &nbsp; </td>
            <td> &nbsp; </td>
          </tr>
          </tbody>
        </table>
      }

      result = render(%{
        the pivot table below does not show defects without priority on igor

           {{
           pivot-table
           conditions: old_type = story
           rows: size
           columns: status
           }}
      }, project, {:view_helper => self}).gsub(/<\/?a[^>]*>/, '')

      expect = Nokogiri::HTML::DocumentFragment.parse(expect).text
      result = Nokogiri::HTML::DocumentFragment.parse(result).text

      assert_equal_ignoring_spaces expect, result
    end
  end


  def test_table_formatting_of_redcloth
    content = "a string\n   \n\n|_.  |_. done |\n|_. 5 |  |\n|_. 7 |  |\n\n"
    expect =  "<p>a string</p>\n\n\n\t<table>\n\t\t<tr>\n\t\t\t<th>done </th>\n\t\t</tr>\n\t\t<tr>\n\t\t\t<th>5 </th>\n\t\t</tr>\n\t\t<tr>\n\t\t\t<th>7 </th>\n\t\t</tr>\n\t</table>"
    assert_equal expect, RedCloth.new(content).to_html

    content = "a string\n\n   |_.  |_. done |\n|_. 5 |  |\n|_. 7 |  |"
    expect_but_not_we_want = "a string\n\t<table>\n\t\t<tr>\n\t\t\t<th>5 </th>\n\t\t</tr>\n\t\t<tr>\n\t\t\t<th>7 </th>\n\t\t</tr>\n\t</table>\n\n\n\n\n\t<table>\n\t\t<tr>\n\t\t\t<th>done </th>\n\t\t</tr>\n\t</table>"
    assert_equal expect_but_not_we_want, RedCloth.new(content).to_html
  end

  def test_autolinking_using_rails_helper
    assert_dom_equal "<a href=\"http://www.google.com\" target=\"_blank\">http://www.google.com</a>",
                 render("http://www.google.com", @project, {:view_helper => self})

    assert_dom_equal "<a href=\"http://www.google.com\" target=\"_blank\">www.google.com</a>",
                 render("www.google.com", @project, {:view_helper => self})

    assert_dom_equal "please visit <a href=\"https://www.google.com\" target=\"_blank\">https://www.google.com</a> for detail",
                 render("please visit https://www.google.com for detail", @project, {:view_helper => self})

    assert_dom_equal "please email <a href=\"mailto:thoughtworker@email.com\">thoughtworker@email.com</a> for help",
                 render("please email thoughtworker@email.com for help", @project, {:view_helper => self})
  end

  def test_formatted_pdf_content
    page = @project.pages.create!(:name => 'page has image', :content => '!img!')
    assert_equal '', page.formatted_pdf_content(view_helper)
  end

  # bug 10473
  def test_less_than_is_html_escaped_for_bulk_print
    page = @project.pages.create!(:name => 'page has image', :content => "Less Than Char Failing Print\r\n<-\r\n\r\n\r\n\r\n")
    assert_dom_equal "Less Than Char Failing Print\r\n&lt;-", page.formatted_pdf_content(view_helper)
  end

  #bug 2936
  def test_should_show_render_error_for_preview
    assert_include "Error in value macro using #{@project.name} project:", render(<<-MACRO, @project, {:view_helper => self})
     {{ value query: SELECT COUNT(*) WHERE Type = storyy }}
     MACRO
  end

  def test_still_renders_when_macro_throws_runtime_error
    with_safe_macro("explode", ExplodingMacro) do
      page = @project.pages.create!(:name => 'tnt', :content => %{
        {{ explode }}
        {{ project }}
      })
      assert page.formatted_content(view_helper).include?("renderable_test_project")
      assert_equal 1, page.macro_execution_errors.size
    end
  end

  def test_detect_macros_when_no_macros
    page = @project.pages.create!(:name => 'a page', :content => 'abc')
    page.detect_macro_content
    assert !page.has_macros
  end

  def test_detect_macros_when_nonsense_macro
    page = @project.pages.create!(:name => 'a page', :content => '{{ nonsense }}')
    page.detect_macro_content
    assert page.has_macros
  end

  def test_detect_macros_when_bad_yaml
    page = @project.pages.create!(:name => 'a page', :content => %{
      {{ ????? }}
    })
    page.detect_macro_content
    assert page.has_macros
  end

  def test_li_and_ol_should_can_be_mix_in_wiki
    assert_dom_equal "<ul>\n\t<li>ul1</li></ul>\n\t<ol>\n\t<li>ol1</li>\n\t</ol>", content_after_conversion(<<-TEXT)
 * ul1
 # ol1
TEXT

  end

  def test_should_not_render_body_macro_cross_parent_level_macro
    result = content_after_conversion(<<-TEXT)
    {% dashboard-panel %}

      {% panel-content %}

      panel content

    {% dashboard-panel %}

    {% dashboard-panel %}

      {% panel-content %}

    {% dashboard-panel %}
TEXT

    expected = <<-EXPECTED
<div class="dashboard-panel">
  <p>{% panel-content %}</p>
  <pre><code>panel content</code></pre>
</div>
<div class="dashboard-panel">
  <p>{% panel-content %}</p>
</div>
EXPECTED

    assert_equal_ignoring_spaces Nokogiri::HTML::DocumentFragment.parse(expected).to_xhtml, Nokogiri::HTML::DocumentFragment.parse(result).to_xhtml
  end

  def test_for_bug5382
    # the renderable text must same with below, don't format them
    result = render(<<-TEXT, @project, {:view_helper => self})
{% dashboard-panel %}

{% panel-heading %}Sprint Progress {% panel-heading %}

{% panel-content %}

panel content




{% dashboard-panel %}

{% panel-heading %}Information{% panel-heading %}

{% panel-content %}



Info om story, test och tid



{% panel-content %}
{% dashboard-panel %}



{% two-columns %}

{% left-column %}

{% dashboard-half-panel %}

{% panel-heading %}Story Progress{% panel-heading %}

{% panel-content %}

more panel content




{% panel-content %}

{% dashboard-half-panel %}

{% left-column %}

{% right-column %}

{% dashboard-half-panel %}

{% panel-heading %}Story Stats{% panel-heading %}

{% panel-content %}


even more panel content




{% panel-content %}

{% dashboard-half-panel %}

{% right-column %}

{% two-columns %}



{% two-columns %}

{% left-column %}

{% dashboard-half-panel %}

{% panel-heading %}Test Stats {% panel-heading %}

{% panel-content %}

panel content




{% panel-content %}

{% dashboard-half-panel %}

{% left-column %}

{% right-column %}

{% dashboard-half-panel %}

{% panel-heading %}Lista alla testfall för releasen{% panel-heading %}

{% panel-content %}

panel content



{% panel-content %}

{% dashboard-half-panel %}

{% right-column %}

{% two-columns %}



{% two-columns %}

{% left-column %}

{% dashboard-half-panel %}

{% panel-heading %}Kvar att göra{% panel-heading %}

{% panel-content %}

panel content

{% panel-content %}

{% dashboard-half-panel %}

{% left-column %}

{% right-column %}

{% dashboard-half-panel %}

{% panel-heading %}Tid{% panel-heading %}

{% panel-content %}

panel content



{% panel-content %}

{% dashboard-half-panel %}

{% right-column %}

{% two-columns %}
TEXT

    assert_equal result.scan('</div>').size, result.scan('<div ').size
  end


  def test_can_be_cached_delegates_to_macros
    first_project.with_active_project do |project|
      can_be_cached = project.pages.create!(:name => 'Can be cached', :content => '{{ value query: SELECT SUM(Release) }}')
      can_be_cached.formatted_content(view_helper)
      cant_be_cached = project.pages.create!(
        :name => 'Cant be cached',
        :content => '{{ value query: SELECT SUM(Release) WHERE Dev IS CURRENT USER }}')
      cant_be_cached.formatted_content(view_helper)

      assert can_be_cached.can_be_cached?
      assert !cant_be_cached.can_be_cached?
    end
  end

  def test_formatted_content_should_not_have_unclosed_tag
    content = render("<div> content <div> </div>", @project)
    assert_dom_equal "<div> content <div> </div></div>", content
  end

  #bug 6056
  def test_render_list_correct_within_panel_content_macro
    result = content_after_conversion(<<-CONTENT)
{% dashboard-panel %}
 {% panel-content %}

* first
* second

 {% panel-content %}
{% dashboard-panel %}
CONTENT
    assert_dom_equal "<div class=\"dashboard-panel\">\n\n<div class=\"dashboard-content\">\n\n\t<ul>\n\t<li>first</li>\n\t\t<li>second</li>\n\t</ul>\n\n\n</div>\n\n</div>", result
  end

  #bug 6056
  def test_render_list_correct_within_dashboard_panel_macro
    result = content_after_conversion(<<-CONTENT)
{% dashboard-panel %}

* first
* second

{% dashboard-panel %}
CONTENT
    assert_dom_equal "<div class=\"dashboard-panel\">\n\n\t<ul>\n\t<li>first</li>\n\t\t<li>second</li>\n\t</ul>\n\n\n</div>", result
  end

  #bug 6056
  def test_render_list_correct_within_dashboard_half_panel_macro
    result = content_after_conversion(<<-CONTENT)
{% dashboard-half-panel %}

* first
* second

{% dashboard-half-panel %}
CONTENT
    assert_dom_equal "<div class=\"dashboard-half-panel\">\n\n\t<ul>\n\t<li>first</li>\n\t\t<li>second</li>\n\t</ul>\n\n\n</div>", result
  end

  #bug 6056
  def test_render_list_correct_within_left_column_macro
    result = content_after_conversion(<<-CONTENT)
{% left-column %}

* first
* second

{% left-column %}
CONTENT
    assert_dom_equal "<div class=\"yui-u first\">\n\n\t<ul>\n\t<li>first</li>\n\t\t<li>second</li>\n\t</ul>\n\n\n</div>", result
  end

  #bug 6056
  def test_render_list_correct_within_panel_heading_macro
    result = content_after_conversion(<<-CONTENT)
{% panel-heading %}

* first
* second

{% panel-heading %}
CONTENT
    assert_dom_equal "<h2>\n\n\t<ul>\n\t<li>first</li>\n\t\t<li>second</li>\n\t</ul>\n\n\n</h2>", result
  end

  #bug 6056
  def test_render_list_correct_within_right_column_macro
    result = content_after_conversion(<<-CONTENT)
{% right-column %}

* first
* second

{% right-column %}
CONTENT
    assert_dom_equal "<div class=\"yui-u\">\n\n\t<ul>\n\t<li>first</li>\n\t\t<li>second</li>\n\t</ul>\n\n\n</div>", result
  end

  #bug 6056
  def test_render_list_correct_within_two_columns_macro
    result = content_after_conversion(<<-CONTENT)
{% two-columns %}

* first
* second

{% two-columns %}
CONTENT
    assert_dom_equal "<div class=\"yui-g\">\n\n\t<ul>\n\t<li>first</li>\n\t\t<li>second</li>\n\t</ul>\n\n\n</div>\n\n<div class=\"clear-both clear_float\"></div>", result
  end

  # bug 5699
  def test_should_render_errors_to_let_user_know_they_need_to_parameters_of_macro_markup_has_to_be_valid_yaml_syntax
    with_new_project do |project|
      setup_property_definitions "Defect Status" => ['Fix : in PROGRESS', 'done']
      macro = %{{{ table query: SELECT name WHERE type = Card AND 'Defect Status' = "Fix \\: in PROGRESS" }}}
      result = render(macro, project)
      expected = "Error in table macro: Please check the syntax of this macro. The macro markup has to be valid YAML syntax."
      assert_dom_content expected, result
    end
  end

  def test_should_not_break_multi_bytes_string
    page = @project.pages.create!(:name => 'em zed', :content => '한국어는 멋진 언어')
    assert_equal '한국어는 멋진 언어', page.formatted_content(self)
  end

  def test_indexable_content
    p = Page.new(:name => 'just italics', :content => '_Russian_')
    assert_equal 'Russian', p.indexable_content
  end

  def test_indexable_content_strips_italic_markers_from_multi_word_sections
    p = Page.new(:name => 'just italics', :content => '_this is italisized_till here_ not here_')
    assert_equal 'this is italisized_till here not here_', p.indexable_content
  end

  def test_indexable_content_for_a_line
    p = Page.new(:name => 'just italics', :content => 'Some line with _italicized_ word')
    assert_equal 'Some line with italicized word', p.indexable_content
  end

  def test_indexable_content_for_non_italic_words_with_underscores
    p = Page.new(:name => 'just italics', :content => 'Some line with not_italicized_word')
    assert_equal 'Some line with not_italicized_word', p.indexable_content
  end

  def test_indexable_content_with_multiple_lines
    p = Page.new(:name => 'just italics', :content => %{Some line with not_italicized_word
with some _italicized_ word line
})
    assert_equal %{Some line with not_italicized_word
with some italicized word line
}, p.indexable_content
  end

  def test_wysiwyg_image_is_rendered
    with_new_project do |project|
      card = create_card!(:number => 10, :name => 'link0', :description => %Q{!1.gif!})
      file = sample_attachment('1.gif')
      card.attach_files(file)
      card.save!
      formatted_content = card.formatted_wysiwyg_content(self)
      assert_match /<img.*?class=\"mingle-image\".*/, formatted_content
      assert_match /<img.*?alt=\"!1.gif!\".*/, formatted_content
      assert_match /<img.*?src=\"http:\/\/example.com\/projects\/#{project.identifier}\/attachments\/#{card.attachments.first.id}\".*/, formatted_content
    end
  end

  def test_should_cleanup_empty_divs_with_clear_both_in_edit_view
    with_new_project do |project|
      card = create_card! :number => 10, :name => 'link0', :description => <<-HTML
      <div class="yui-g">
        <div class="yui-u first">
          <div class="dashboard-half-panel">
            <h2>
              Work In Progress for the Iteration
            </h2>
            <div class="dashboard-content">
              <h3>
                Cumulative Flow for the Iteration – Story Points
              </h3>
              <div class="error">
                You messed up
              </div>
            </div>
          </div>
        </div>
        <div class="clear-both clear_float"></div>
        <div class="yui-u">
          <div class="dashboard-half-panel">
            <h2>
              Work In Progress for the Iteration
            </h2>
            <div class="dashboard-content">
              <h3>
                Cumulative Flow for the Iteration – # of Stories
              </h3>
              <div class="error">
                You are dumb
              </div>
            </div>
          </div>
        </div>
      </div>
      <div class="clear-both clear_float"></div>
HTML
      formatted_content = Nokogiri::HTML::DocumentFragment.parse(card.formatted_wysiwyg_content(self))
      (formatted_content.css("div")).each do |elem|
        assert_false elem.attributes['class'].include?('clear-both')
        assert_false elem.attributes['class'].include?('clear_float')
      end
    end
  end

  def test_wysiwyg_edit_doesnt_remove_iframe_macros
    page = Page.new(:name => 'just italics', :content => %{
      {{
        google-calendar
          src: "http://www.google.com/calendar/embed?src=en.usa%23holiday%40group.v.calendar.google.com&ctz=America/Los_Angeles"
          width: 900
          height: 700
      }}
      })
    formatted_content = page.formatted_wysiwyg_content(self)
    assert_match /<iframe/, formatted_content
  end

  def test_lts_in_pre_code_are_not_double_escaped
    page = @project.pages.create! :name => 'just italics', :content => <<-CONTENT
      <pre class="p1">
    {
       node_type: PIPELINE,
       parents:..
       ..
       instances: [{
                        label: &lt;pipeline_label&gt;,
                        counter: &lt;pipeline_counter&gt;,
                        locator: "pipelines/dependency_graph/&lt;pipeline_name&gt;/&lt;pipeine_counter&gt;"
                        </pre>

      <pre style="color: rgb(85, 85, 85); line-height: 19.09090805053711px;">
    stages:[{name: &lt;stage_name&gt;,
         status: &lt;failed/passed/building/cancelled,
         locator: "pipelines/&lt;pipeline_name&gt;/&lt;pipeline_counter&gt;/&lt;stage&gt;/&lt;stage_counter"}
    …]</pre>
CONTENT
    formatted_content = page.formatted_content(self)
    assert_no_match /&amp;lt;/, formatted_content
    assert_match /&lt;pipeline/, formatted_content
  end

  def test_escapes_macro_like_syntax_in_hrefs
    page = @project.pages.create! :name => 'just italics', :content => <<-CONTENT
      <p><a href="http://localhost:3000/projects/{{project}}/cards">all cards</a></p>

      <p></p>

      {{
        dummy

      }}
    CONTENT

    with_safe_macro("dummy", DummyMacro) do
      formatted_content = page.formatted_content(self)
      expected = %Q{
        <p><a href="http://localhost:3000/projects/%7B%7Bproject%7D%7D/cards">all cards</a></p>

        <p></p>

        DUMMY dummy
      }
      assert_equal_ignoring_spaces expected, formatted_content
    end
  end

  def test_wysiwyg_does_not_escape_less_than_in_mql
    page = @project.pages.create! :name => 'just italics', :content => "{{ table query: SELECT number, name WHERE number < 100 }}"
    formatted_content = page.formatted_wysiwyg_content(self)
    assert_no_match(/lt;/, formatted_content)
  end

  def test_content_summary_should_truncate_if_too_long
    card = create_card!(:name =>"trunc", :description => "A"*161)
    assert_equal "<div>" + "A"*157 + "...</div>", card.formatted_content_summary(self, 160)
  end

  def test_content_summary_should_return_nil_if_description_is_blank
    card = create_card!(:name =>"trunc", :description => "")
    assert_nil card.formatted_content_summary(self)
  end

  def test_content_summary_picks_up_first_image_and_renders_before_the_text
    card = create_card!(:name => "trunc", :description => "hello this is a test. <img src='http://images.google.com/foo'></img> and so it goes")
    assert_equal "<img src=\"http://images.google.com/foo\" /><div>hello this is a test.  and so it goes</div>", card.formatted_content_summary(self)
  end

  def test_content_summary_strips_tags_from_remainder_html
    card = create_card!(:name => "trunc", :description => "hello this is <h1>a</h1> test")
    assert_equal "<div>hello this is a test</div>", card.formatted_content_summary(self)
  end

  def test_should_not_subsitute_image_tag_output_from_macro
    MinglePlugins::Macros.register(MingleZyBug816, 'minglezy_bug_816')
    card = create_card!(:name => "trunc", :description => "{{minglezy_bug_816}}")
    assert_equal "<div>text()!=''?jQuery('\"+memberInfo['teammember']+\"').text()\njavaScriptArray.chop!</div>", card.formatted_content_summary(self)
  end

  class MingleZyBug816
    def initialize(*args)
    end

    def execute
      <<-X
text()!=''?jQuery('"+memberInfo['teammember']+"').text()
javaScriptArray.chop!
X
    end
  end

  def content_after_conversion(redcloth_content)
    page = @project.pages.build(:name => 'abc'.uniquify, :content => redcloth_content, :redcloth => true)
    page.save(false) # skips forcing redcloth flag to false in before_validation hook
    page.convert_redcloth_to_html!
    page.content
  end

  def controller
    OpenStruct.new(:request =>
                   OpenStruct.new(:protocol => "http://",
                                  :host_with_port => "test.host"))
  end

end
