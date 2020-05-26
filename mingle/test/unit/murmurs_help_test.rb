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

require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class MurmursHelpTest < ActiveSupport::TestCase
  include MurmursHelper, ApplicationHelper, ActionView::Helpers::UrlHelper, ActionView::Helpers::TextHelper
  def setup
    login_as_member
    @project = first_project
    @project.activate
  end

  def test_card_keyword_should_be_formatted_as_card_link_in_murmurs_content
    card = create_card!(:name => "I am card")
    expected_content = %{This is <a href="" class="card-tool-tip card-link-#{card.number}" data-card-name-url="">##{card.number}</a>}
    assert_equal expected_content, truncated_murmurs_content(Murmur.new(:murmur => "This is ##{card.number}"))
  end

  def test_card_keyword_with_project_should_be_format_as_corss_project_card_link_in_murmurs_content
    card = create_card!(:name => "I am card")
    assert_equal "This is <a href=\"\" class=\"card-link-#{card.number}\">#{@project.identifier}/##{card.number}</a>", truncated_murmurs_content(Murmur.new(:murmur => "This is #{@project.identifier}/##{card.number}"))
  end

  def test_page_keyword_should_be_format_as_page_link_in_murmurs_content
    assert_equal "<a href=\"\" class=\"non-existent-wiki-page-link\">I am page</a>", truncated_murmurs_content(Murmur.new(:murmur => "[[I am page]]"))
    page = @project.pages.create(:name => "I am another page")
    assert_equal "<a href=\"\">I am another page</a>", truncated_murmurs_content(Murmur.new(:murmur => "[[I am another page]]"))
  end

  def test_page_keyword_should_not_be_formatted_as_page_link_when_rendering_as_comment
    assert_equal "<a href=\"\" class=\"non-existent-wiki-page-link\">I am page</a>", truncated_murmurs_content(Murmur.new(:murmur => "[[I am page]]"))
  end

  def test_should_original_auto_link_when_truncated_murmurs_content
    assert_equal "<a href=\"http://www.google.com\" target=\"_blank\">http://www.google.com</a>", truncated_murmurs_content(Murmur.new(:murmur => "http://www.google.com"))
    assert_equal "<a href=\"https://www.google.com\" target=\"_blank\">https://www.google.com</a>", truncated_murmurs_content(Murmur.new(:murmur => "https://www.google.com"))
    assert_equal "<a href=\"http://www.google.com\" target=\"_blank\">www.google.com</a>", truncated_murmurs_content(Murmur.new(:murmur => "www.google.com"))
    assert_equal "<a href=\"mailto:qiananchuan@gmail.com\">qiananchuan@gmail.com</a>", truncated_murmurs_content(Murmur.new(:murmur => "qiananchuan@gmail.com"))
  end

  def test_should_format_link_correctly_when_there_is_special_characters_before_it
    assert_equal "wpc: <a href=\"http://www.google.com\" target=\"_blank\">http://www.google.com</a>", truncated_murmurs_content(Murmur.new(:murmur => "wpc: http://www.google.com"))
  end

  def test_format_link_with_special_encoded_ampersand_character
    assert_equal "<a href=\"http://foo.com/blah?a=a&b=b\" target=\"_blank\">http://foo.com/blah?a=a&amp;b=b</a>", truncated_murmurs_content(Murmur.new(:murmur => "http://foo.com/blah?a=a&b=b"))
  end

  def test_attachment_should_auto_link_in_murmurs_content
    card = create_card!(:name => "I am a new card")
    card.attach_files(sample_attachment("1.gif"))
    card.save!
    expected_attachment = "##{card.number}/1.gif"
    content = truncated_murmurs_content(Murmur.new(:murmur => "[[#{expected_attachment}]]"))
    assert_equal "<a href=\"\" target=\"blank\">#{expected_attachment}</a>", content
  end

  def test_attachment_should_be_auto_linked_in_comments
    card = create_card!(:name => "I am a new card")
    card.attach_files(sample_attachment("1.gif"))
    card.save!
    assert_equal "<a href=\"\" target=\"blank\">##{card.number}/1.gif</a>", truncated_murmurs_content(Murmur.new(:murmur => "[[##{card.number}/1.gif]]"))
  end

  def test_should_truncate_large_murmurs_at_1000_chars
    large_murmur = "a" * 1001
    truncated_content = truncated_murmurs_content(Murmur.new(:murmur => large_murmur, :id => 17))
    assert truncated_content.include?("a"*997 + "...")
  end

  def test_formatted_content_should_not_truncate
    large_murmur = "a" * 1001
    full_content = formatted_murmurs_content(Murmur.new(:murmur => large_murmur))
    assert_equal large_murmur, full_content
  end

  def test_formatted_content_should_not_be_formatted_as_page_link_when_rendering_as_comment
    assert_equal "<a href=\"\" class=\"non-existent-wiki-page-link\">I am page</a>", formatted_murmurs_content(Murmur.new(:murmur => "[[I am page]]"))
  end

  def test_should_escape_html_tag_in_murmur
    result = formatted_murmurs_content(Murmur.new(:murmur => '<style>'))
    assert_equal '&lt;style&gt;', result
  end

  # Bug 8247
  def test_truncated_murmurs_content_should_replace_new_lines_with_html_breaks
    card = create_card!(:name => "I am card")
    assert_equal "I<br/>am<br/>murmur", truncated_murmurs_content(Murmur.new(:murmur => "I\nam\nmurmur"))
  end

  # Bug 8247
  def test_formatted_murmurs_content_should_replace_new_lines_with_html_breaks
    card = create_card!(:name => "I am card")
    assert_equal "I<br/>am<br/>murmur", formatted_murmurs_content(Murmur.new(:murmur => "I\nam\nmurmur"))
  end

  # Mock method for prepend_protocol_with_host_and_port
  def prepend_protocol_with_host_and_port(url=nil)
    ""
  end

  def project_attachment_path(options)
    "/projects/#{options[:project_id]}/attachments/#{options[:id]}"
  end

  private
  # Mock method for link_to
  def url_for(options={})
    ""
  end

end
