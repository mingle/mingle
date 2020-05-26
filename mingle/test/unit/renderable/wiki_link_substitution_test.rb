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

class WikiLinkSubstitutionTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    @project.activate
    login_as_member
  end

  def test_should_allow_ampersand_in_link
    @project.pages.create(:name => 'Cow & Gate')
    s = Renderable::WikiLinkSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('Cow & Gate'), :view_helper => view_helper)
    assert_equal "<a href=\"/projects/first_project/wiki/Cow_&amp;_Gate\">Cow &amp; Gate</a>", s.apply('[[Cow &amp; Gate]]')
  end

  def test_should_produce_correct_link_for_valid_wiki_page_name
    @project.pages.create(:name => 'New Page')
    s = Renderable::WikiLinkSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    assert_equal "<a href=\"/projects/first_project/wiki/New_Page\">New Page</a>", s.apply('[[New Page]]')
  end

  # test for bug 431
  def test_should_produce_show_error_link_for_invalid_wiki_page_name
    s = Renderable::WikiLinkSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    assert s.apply('[[And/Or]]') =~ /contains at least one invalid character/
    # assert_equal expected_link_for_invalid_wiki_name("_has_underscores"), s.apply('[[_has_underscores]]')
    # assert_equal expected_link_for_invalid_wiki_name("ni*(*hao)"), s.apply('[[ni*(*hao)]]')
  end

  # test for bug 2094
  def test_should_produce_error_link_for_wiki_page_name_too_long
    s = Renderable::WikiLinkSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    long_title = (1..256).collect {'a'}.join
    assert s.apply("[[#{long_title}]]") =~ /The page name is too long\./
  end

  #bug 5472
  def test_should_produce_error_link_with_right_project_identifier_for_wiki_page_name_with_slash_which_is_invalid
    s = Renderable::WikiLinkSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    assert s.apply("[[<pre>new <sub> wiki <h3> page</pre>]]") =~ /projects\/#{@project.identifier}\//
    assert s.apply("[[<pre>new <sub> wiki <h3> page</pre>]]") =~ /error\_link/
  end
  
  def test_should_produce_error_link_when_project_identifier_is_not_exist
    s = Renderable::WikiLinkSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    assert s.apply("[[not_exist_project/some_page]]") =~ /projects\/#{@project.identifier}\//
    assert s.apply("[[not_exist_project/some_page]]") =~ /error\_link/
  end
  
  def test_should_produce_error_link_with_right_project_identifier_for_cross_project_wiki_page_which_contains_invalid_character
    s = Renderable::WikiLinkSubstitution.new(:project => three_level_tree_project, :content_provider => nil, :view_helper => view_helper)
    assert s.apply("[[first_project/<pre>new <sub> wiki <h3> page</pre>]]") =~ /projects\/first_project\//
    assert s.apply("[[first_project/<pre>new <sub> wiki <h3> page</pre>]]") =~ /error\_link/
  end
  
  def test_should_produce_error_link_with_right_project_identifier_for_cross_project_wiki_page_which_name_is_too_long
    s = Renderable::WikiLinkSubstitution.new(:project => three_level_tree_project, :content_provider => nil, :view_helper => view_helper)
    long_title = (1..256).collect {'a'}.join
    assert s.apply("[[first_project/#{long_title}]]") =~ /The page name is too long\./
  end
  
  def test_should_produce_error_link_with_right_project_identifier_for_cross_project_wiki_page_which_is_not_exist
    s = Renderable::WikiLinkSubstitution.new(:project => three_level_tree_project, :content_provider => nil, :view_helper => view_helper)
    assert s.apply("[[first_project/not_exist_page]]") =~ /projects\/first_project\//
    assert s.apply("[[first_project/not_exist_page]]") =~ /non-existent-wiki-page-link/
  end
  
  #bug 5472
  def test_should_allow_wiki_link_which_contain_html_tags
    s = Renderable::WikiLinkSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    assert s.apply("[[new <sub> wiki <h3> page]]") =~ /projects\/#{@project.identifier}\//
    assert s.apply("[[new <sub> wiki <h3> page]]") !=~ /error\_link/
  end
  
  #bug 5472
  def test_should_escape_html_tags_in_wiki_link
    s = Renderable::WikiLinkSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    assert s.apply("[[new <sub> wiki <h3> page]]") =~ /new &lt;sub&gt; wiki &lt;h3&gt; page/
    assert s.apply("[[first_project/new <sub> wiki <h3> page]]") =~ /new &lt;sub&gt; wiki &lt;h3&gt; page/
  end
  
  def test_should_produce_correct_link_for_valid_cross_project_wiki_page_name
    @project.pages.create(:name => 'New Page')
    s = Renderable::WikiLinkSubstitution.new(:project => @project, :content_provider => nil, :view_helper => view_helper)
    assert_equal "<a href=\"/projects/first_project/wiki/New_Page\">first_project/New Page</a>", s.apply('[[first_project/New Page]]')
    
    s = Renderable::WikiLinkSubstitution.new(:project => three_level_tree_project, :content_provider => nil, :view_helper => view_helper)
    assert_equal "<a href=\"/projects/first_project/wiki/New_Page\">first_project/New Page</a>", s.apply('[[first_project/New Page]]')
  end
  
  def test_should_produce_correct_named_links
    s = Renderable::WikiLinkSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    assert_equal "<a href=\"/projects/first_project/wiki/First_Page\">my link</a>", s.apply('[[ my link | First Page ]]')
    assert_equal "<a href=\"/projects/first_project/wiki/First_Page\">first</a>" + " | " + "<a href=\"/projects/first_project/wiki/Second_Page\">second</a>",
      s.apply('[[ first | First Page ]] | [[ second | Second Page ]]')
  end

  def test_should_produce_correct_named_links_for_cross_project_wiki
    s = Renderable::WikiLinkSubstitution.new(:project => three_level_tree_project, :content_provider => nil, :view_helper => view_helper)
    assert_equal "<a href=\"/projects/first_project/wiki/First_Page\">my link</a>", s.apply('[[ my link | first_project/First Page ]]')
    assert_equal "<a href=\"/projects/first_project/wiki/First_Page\">first</a>" + " | " + "<a href=\"/projects/first_project/wiki/Second_Page\">second</a>",
                    s.apply('[[ first | first_project/First Page]] | [[ second | first_project/Second Page ]]')
  end
  
  #bug #8066 project identifier is case sensitive in cross project linking
  def test_should_ignore_case_when_link_to_wiki_in_cross_project
    s = Renderable::WikiLinkSubstitution.new(:project => three_level_tree_project, :content_provider => nil, :view_helper => view_helper)
    assert_equal "<a href=\"/projects/first_project/wiki/First_Page\">First_project/First Page</a>", s.apply('[[First_project/First Page ]]')
  end
  
  def test_should_not_cache_content_which_has_cross_project_attachement_link
    login_as_member
    content_provider = create_card!(:name => 'new card')
    
    substitution = Renderable::WikiLinkSubstitution.new(:project => three_level_tree_project, :content_provider => content_provider, :view_helper => view_helper)
    substitution.apply('[[ first_project/First page ]]')
    assert_equal 1, content_provider.rendered_projects.size
    assert_equal first_project, content_provider.rendered_projects.first
    assert_equal false, content_provider.can_be_cached?
  end
  
  # it's related to named wiki link, it's merged to wiki link substitution
  # test for bug #671
  def test_should_not_process_normal_links_even_with_a_pipe
    s = Renderable::WikiLinkSubstitution.new(:project => @project, :content_provider => @project.pages.find_by_name('First Page'), :view_helper => view_helper)
    expected_result = "<a href=\"/projects/first_project/wiki/First\" class=\"non-existent-wiki-page-link\">First</a>" + " | " + "<a href=\"/projects/first_project/wiki/Second\" class=\"non-existent-wiki-page-link\">Second</a>"
    assert_equal expected_result, s.apply('[[First]] | [[Second]]')
  end
end
