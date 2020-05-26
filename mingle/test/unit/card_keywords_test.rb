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

class CardKeywordsTest < ActiveSupport::TestCase
  
  def setup
    @project = first_project
  end
  
  def test_default_card_keywords
    default_keywords = CardKeywords.new(@project)
    assert default_keywords.valid?
    assert default_keywords.included_in?('checkin for card 2',2)
    assert default_keywords.included_in?('checkin for #2', 2)
    assert !default_keywords.included_in?('checkin for bug 2', 2)
    assert !default_keywords.included_in?('checkin for defect 2', 2)
  end
  
  def test_blank_keywords_should_be_as_same_as_default
    assert_equal CardKeywords.new(@project).to_s, CardKeywords.new(@project, '   ').to_s
    assert_equal CardKeywords.new(@project).value_for_save, CardKeywords.new(@project, '   ').value_for_save
  end
  
  def test_to_s
    assert_equal 'bug, defect, card, #', CardKeywords.new(@project, 'bug, defect, card, #').to_s
    assert_equal CardKeywords::DEFAULT_CARD_KEYWORDS.join(', '), CardKeywords.new(@project).to_s
  end
  
  def test_value_for_save_should_nil_if_synoyms_is_the_default_one
    assert_equal 'bug, defect, card, #', CardKeywords.new(@project, 'bug, defect, card, #').value_for_save    
    assert_equal nil, CardKeywords.new(@project).value_for_save
    assert_equal nil, CardKeywords.new(@project, CardKeywords::DEFAULT_CARD_KEYWORDS.join(',')).value_for_save
  end
  
  def test_value_for_save_should_return_original_value_if_keywords_is_invalid
    assert_equal ",", CardKeywords.new(@project, ",").value_for_save
    assert_equal "##", CardKeywords.new(@project, "##").value_for_save
  end
  
  def test_matching_revision_message
    card_keywords = CardKeywords.new(@project, 'bug, defect, card, #')
    assert card_keywords.valid?
    assert card_keywords.included_in?('checkin for card 2', 2)
    assert card_keywords.included_in?('checkin for #2', 2)
    assert card_keywords.included_in?('checkin for bug 2', 2)
    assert card_keywords.included_in?('checkin for defect 2', 2)
    assert !card_keywords.included_in?('checkin for issuse 2', 2)
  end
  
  def test_keywords_should_limited_in_words_and_hash
    invalid_keywords = ['(()', ',,', ',', ', #', '-', '~', '!', '@', '##', '$', '\\', '0', '^', '%', '`', '..', '=~', '$&', '&', 'story-card']
    invalid_keywords.each do |synonym|
      assert !CardKeywords.new(@project, synonym).valid?, "#{synonym} should not be valid"
    end
  end
  
  def test_find_card_numbers_in_commit_message
    keywords = CardKeywords.new(@project, 'bug, card, #')
    
    assert_card_number_in_message(keywords, '321', 'fix #321.')
    assert_card_number_in_message(keywords, '321', 'fix bug #321 sldfjkll')
    assert_card_number_in_message(keywords, '321', 'fix bug 321')
    assert_card_number_in_message(keywords, '321', 'fix bug (#321)')
    assert_card_numbers_in_message(keywords, ['321', '33', '100'], 'fix #321 & #33 and bug 100 asdfkljkl')
    assert_no_card_number_in_message(keywords, 'fixed something!')
  end
  
  def test_card_number_should_end_by_brackets
    default_keywords = CardKeywords.new(@project)
    assert default_keywords.included_in?('( #2)', 2)
    assert default_keywords.included_in?('(#2)', 2)
  end
  
  # Bug #4669
  def test_comparison_should_be_case_insensitive
    keywords = CardKeywords.new(@project, 'bug')
    assert_card_number_in_message(keywords, '4669', 'bug 4669')
    assert_card_number_in_message(keywords, '4669', 'Bug 4669')
    assert_card_number_in_message(keywords, '4669', 'BUG 4669')
    assert_no_card_number_in_message(keywords, 'BUN 4669')
  end
  
  def test_should_tell_if_contains_keyword
    keywords = CardKeywords.new(@project, 'bug, card')
    assert keywords.include?('bug')
  end
  
  def test_extract_numbers_from_message_with_project_identifier
    assert_equal ['123'], CardKeywords.new(@project).card_numbers_in("first_project/#123")
    assert_equal ['123'], CardKeywords.new(@project).card_numbers_in("first_project / #123")
    assert_equal ['123'], CardKeywords.new(@project, 'bug').card_numbers_in("first_project/bug 123")
  end
  
  def test_extract_number_with_project_identifier_should_be_case_insensitive
    assert_equal ['123'], CardKeywords.new(@project).card_numbers_in("First_Project/#123")
  end
  
  def test_should_extract_numbers_for_non_existed_project_identifier
    assert_equal ['123'], CardKeywords.new(@project).card_numbers_in("another/#123")
    assert_equal ['123'], CardKeywords.new(@project).card_numbers_in("another / #123")
    assert_equal ['123'], CardKeywords.new(@project).card_numbers_in("another /#123")
    assert_equal ['123'], CardKeywords.new(@project, 'bug').card_numbers_in("another/bug 123")
  end
  
  def test_should_not_extract_numbers_wrong_card_keyword
    assert_equal [], CardKeywords.new(@project).card_numbers_in("first_project/blah 123")
  end
  
  def test_extract_numbers_lead_with_slash_but_none_project_identifier
    assert_equal ['123'], CardKeywords.new(@project).card_numbers_in("mm #123")
    assert_equal ['123'], CardKeywords.new(@project).card_numbers_in("/#123")
  end
  
  # Bug 7708
  def test_to_xml_v1_should_surround_keywords_with_value_element
    keywords = CardKeywords.new(@project, 'bug, card')
    test_builder = Builder::XmlMarkup.new(:indent => 2)
    xml = test_builder.tag!('test') do
      keywords.to_xml(:version => 'v1', :builder => test_builder)
    end
    assert_equal 'bug', get_element_text_by_xpath(xml, "//test/keyword/value[text()='bug']")
  end
  
  def test_to_xml_v2_should_not_have_values_element
    keywords = CardKeywords.new(@project, 'bug, card')
    test_builder = Builder::XmlMarkup.new(:indent => 2)
    xml = test_builder.tag!('test') do
      keywords.to_xml(:version => 'v2', :builder => test_builder)
    end
    assert_equal 'bug', get_element_text_by_xpath(xml, "//test/keyword[text()='bug']")
  end
  
  #bug 7678
  def test_should_parse_out_card_link_when_2_card_link_separated_by_slash
    keywords = CardKeywords.new(@project, '#')
    assert_equal ['1', '2'], keywords.card_numbers_in('#1/#2')
  end
  
  private
  
  def assert_card_number_in_message(keywords, expected_number, message)
    assert_card_numbers_in_message(keywords, [expected_number], message)
  end
  
  def assert_no_card_number_in_message(keywords, message)
    assert_equal [], keywords.card_numbers_in(message)
  end
  
  def assert_card_numbers_in_message(keywords, expected_numbers, message)
    assert_equal expected_numbers, keywords.card_numbers_in(message)
  end
  
end
