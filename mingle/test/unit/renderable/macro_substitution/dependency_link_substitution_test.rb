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

require File.expand_path(File.dirname(__FILE__) + '/../../../unit_test_helper')
require File.expand_path(File.dirname(__FILE__) + '/../../renderable_test_helper')

class DependencyLinkSubstitutionTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    @project.activate
    @substitution = Renderable::DependencySubstitution.new(:project => @project, :content_provider => nil, :view_helper => view_helper)
  end

  def test_should_replace_dependency_prefix_and_number_with_link_to_dependency
    assert_equal %{<a class="dependencies card-tool-tip card-link-267" data-card-name-url=\"/projects/first_project/dependencies/dependency_name?number=267\" data-dependency-number="267" data-dependency-popup-url="/projects/#{@project.identifier}/dependencies/popup_show" href="javascript:void(0)" onclick="$j(this).showDependencyPopup(); return false;">#D267</a>}, @substitution.apply("#D267")
  end

  def test_should_be_case_sensitive
    assert "#D123" =~ @substitution.pattern
    assert_equal "#D", $1
    assert_equal "123", $2

    assert !("#d123" =~ @substitution.pattern)
    assert_equal "#d123", @substitution.apply("#d123")
  end

  def test_should_allow_punctuation_following_dependency_number
    [".", ",", "!", ":", ";", "|"].each do |punctuation|
      assert ("#D267" + punctuation) =~ @substitution.pattern
      assert_equal "#D", $1
      assert_equal "267", $2
      assert_equal punctuation, $3
    end
    assert_equal %{<a class="dependencies card-tool-tip card-link-267" data-card-name-url=\"/projects/first_project/dependencies/dependency_name?number=267\" data-dependency-number="267" data-dependency-popup-url="/projects/#{@project.identifier}/dependencies/popup_show" href="javascript:void(0)" onclick="$j(this).showDependencyPopup(); return false;">#D267</a>.}, @substitution.apply("#D267.")
  end

  def test_should_replace_dependency_prefix_and_number_with_link_to_dependency_in_html
    assert_equal %{<b><a class="dependencies card-tool-tip card-link-267" data-card-name-url=\"/projects/first_project/dependencies/dependency_name?number=267\" data-dependency-number="267" data-dependency-popup-url="/projects/#{@project.identifier}/dependencies/popup_show" href="javascript:void(0)" onclick="$j(this).showDependencyPopup(); return false;">#D267</a></b>}, @substitution.apply("<b>#D267</b>")
  end

  def test_should_not_substitute_number_wrap_in_notextile
    assert_equal "<escape>#D711, Market Street</escape>", @substitution.apply("<escape>#D711, Market Street</escape>")
  end

  def test_should_not_replace_hash_and_number_with_link_to_card_when_it_is_html_code
    assert_equal "&#D211;", @substitution.apply("&#D211;")
  end

  def test_should_not_replace_hash_and_number_with_link_to_card_when_it_is_a_wiki_color_code
    assert_equal "<p><span style=\"color: #D333333;\">I like cookie</span></p>", @substitution.apply("<p><span style=\"color: #D333333;\">I like cookie</span></p>")
  end

  def test_should_not_break_off_url_fragments_that_look_like_dependency_number
    assert_equal "http://www.google.com/so#D201", @substitution.apply("http://www.google.com/so#D201")
    assert_equal "Checkout this link --> http://www.google.com/so#D201", @substitution.apply("Checkout this link --> http://www.google.com/so#D201")
    assert_equal "http://www.google.com/so#D201", @substitution.apply("http://www.google.com/so#D201")
    assert_equal "https://www.google.com/so#D201", @substitution.apply("https://www.google.com/so#D201")
    assert_equal "https://www.google.com/so <a class=\"dependencies card-tool-tip card-link-267\" data-card-name-url=\"/projects/first_project/dependencies/dependency_name?number=267\" data-dependency-number=\"267\" data-dependency-popup-url=\"/projects/#{@project.identifier}/dependencies/popup_show\" href=\"javascript:void(0)\" onclick=\"$j(this).showDependencyPopup(); return false;\">#D267</a>", @substitution.apply("https://www.google.com/so #D267")
    assert_equal "https://www.goo gle.com/so<a class=\"dependencies card-tool-tip card-link-267\" data-card-name-url=\"/projects/first_project/dependencies/dependency_name?number=267\" data-dependency-number=\"267\" data-dependency-popup-url=\"/projects/#{@project.identifier}/dependencies/popup_show\" href=\"javascript:void(0)\" onclick=\"$j(this).showDependencyPopup(); return false;\">#D267</a>", @substitution.apply("https://www.goo gle.com/so#D267")
  end
end
