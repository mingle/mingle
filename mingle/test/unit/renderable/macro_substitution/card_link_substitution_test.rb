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

# Tags: #671
class CardLinkSubstitutionTest < ActiveSupport::TestCase
  def setup
    @project = first_project
    @project.activate
    @substitution = Renderable::CardSubstitution.new(:project => @project, :content_provider => nil, :view_helper => view_helper)
    @project.card_keywords = 'story,bug,defect,card,#'
  end

  def test_should_not_break_off_url_fragments_that_look_like_new_card_keywords
    @project.card_keywords="#card"
    assert_equal "http://www.google.com/so#card201", @substitution.apply("http://www.google.com/so#card201")
  end

  def test_should_not_break_off_url_fragments_that_look_like_card_numbers
    assert_equal "Checkout this link --> http://www.google.com/so#201", @substitution.apply("Checkout this link --> http://www.google.com/so#201")
    assert_equal "http://www.google.com/so#201", @substitution.apply("http://www.google.com/so#201")
    assert_equal "https://www.google.com/so#201", @substitution.apply("https://www.google.com/so#201")
    assert_equal "https://www.google.com/so <a href=\"/projects/first_project/cards/201\" class=\"card-tool-tip card-link-201\" data-card-name-url=\"/projects/first_project/cards/card_name/201\">#201</a>", @substitution.apply("https://www.google.com/so #201")
    assert_equal "http://www.goo gle.com/so<a href=\"/projects/first_project/cards/201\" class=\"card-tool-tip card-link-201\" data-card-name-url=\"/projects/first_project/cards/card_name/201\">#201</a>", @substitution.apply("http://www.goo gle.com/so#201")
  end

  def test_should_match_hash_and_some_digits
    assert_matches_card_name_and_number("#267", "267", "#267")
    assert_matches_card_name_and_number("# 267", "267", "# 267")
    assert_matches_card_name_and_number("story2", "2", "story2")
    assert_matches_card_name_and_number("story 2", "2", "story 2")
    assert_matches_card_name_and_number("bug2", "2", "bug2")
    assert_matches_card_name_and_number("bug 2", "2", "bug 2")
    assert_matches_card_name_and_number("defect2", "2", "defect2")
    assert_matches_card_name_and_number("defect 2", "2", "defect 2")
    assert_matches_card_name_and_number("card2", "2", "card2")
    assert_matches_card_name_and_number("card 2", "2", "card 2")
    assert_matches_card_name_and_number("#267", "267", "<b> #267</b>")
    assert_matches_card_name_and_number("#267", "267", "<b>#267 </b>")
    assert_matches_card_name_and_number("#267", "267", "<b>#267</b>")
    assert_matches_card_name_and_number("card790", "790", "<p>card790</p>")
    assert !(@substitution.pattern =~ "#267a")
  end

  # Bug #4669
  def test_should_be_case_insensitive
    assert_matches_card_name_and_number("Card 2", "2", "Card 2")
    assert_matches_card_name_and_number("CARD 2", "2", "CARD 2")
  end

  def test_should_allow_punctuation_following_card_name_pattern
    [".", ",", "!", ":", ";", "|"].each do |punctuation|
      assert_matches_card_name_and_number("#267", "267", "#267" + punctuation)
    end
  end

  def test_should_replace_hash_and_number_with_link_to_card
    assert_equal %{<a href="/projects/first_project/cards/267" class="card-tool-tip card-link-267" data-card-name-url="/projects/first_project/cards/card_name/267">#267</a>}, @substitution.apply("#267")
  end

  def test_should_replace_hash_and_number_with_link_to_card_inside_html_tag
    assert_equal %{<b><a href="/projects/first_project/cards/267" class="card-tool-tip card-link-267" data-card-name-url="/projects/first_project/cards/card_name/267">#267</a></b>}, @substitution.apply("<b>#267</b>")
  end

  def test_should_not_substitute_number_wrap_in_notextile
    assert_equal "<escape>#711, Market Street</escape>", @substitution.apply("<escape>#711, Market Street</escape>")
  end

  def test_should_not_replace_hash_and_number_with_link_to_card_when_it_is_html_code
    assert_equal "&#8211;", @substitution.apply("&#8211;")
  end


  def test_should_not_replace_hash_and_number_with_link_to_card_when_it_is_a_wiki_color_code
    assert_equal "<p><span style=\"color: #881122;\">I like cookie</span></p>", @substitution.apply("<p><span style=\"color: #881122;\">I like cookie</span></p>")
  end

  def test_should_replace_hash_and_number_with_link_to_card_when_it_is_after_a_wiki_color_code
    assert_equal %{<p><span style="color: #881122;">I like cookie <a href="/projects/first_project/cards/881122" class="card-tool-tip card-link-881122" data-card-name-url="/projects/first_project/cards/card_name/881122">#881122</a></span></p>}, @substitution.apply("<p><span style=\"color: #881122;\">I like cookie #881122</span></p>")
  end

  def test_replacement_of_hash_and_number_should_include_url_of_card_name
    assert_equal %{<a href="/projects/first_project/cards/267" class="card-tool-tip card-link-267" data-card-name-url="/projects/first_project/cards/card_name/267">#267</a>}, @substitution.apply("#267")
  end

  def test_content_without_anything_to_match_should_render_properly
    assert_equal "nothing here", @substitution.apply("nothing here")
    assert_equal "#273a", @substitution.apply("#273a")
  end

  # bug 7268
  def test_should_render_card_as_link_when_sandwiched_between_two_attachment_references
    expected = <<-TEXT
Attachment is here: !banana.jpg!

* <a href="/projects/first_project/cards/7265" class="card-tool-tip card-link-7265" data-card-name-url="/projects/first_project/cards/card_name/7265">#7265</a> Foo

Attachment is here: !banana.jpg!
    TEXT

    assert_equal expected, @substitution.apply(<<-TEXT)
Attachment is here: !banana.jpg!

* #7265 Foo

Attachment is here: !banana.jpg!
    TEXT
  end

  def assert_matches_card_name_and_number(name, number, content)
    assert content =~ @substitution.pattern
    assert_equal(name, $1 + $2 + $3)
    assert_equal(number, $3)
  end

  def test_foreign_caharacters_should_not_kill_substitutions
    chinese_characters = [31616, 20307, 23383].pack('UUU')
    assert_equal chinese_characters, @substitution.apply(chinese_characters.mb_chars)
  end
end
