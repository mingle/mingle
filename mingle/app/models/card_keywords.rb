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

class CardKeywords
  include API::XMLSerializer

  DEFAULT_CARD_KEYWORDS= ['card', '#']
  DEFAULT_INVALID_MESSAGE = "are limited to words and the '#' symbol"
  KEYWORDS_SURFIX_REGEXP = "(\\W|$)"

  SINGLE_KEYWORD_REGEX = "(\\#|[a-z]+)"
  CROSS_PROJECT_BASE = "(#{Project::IDENTIFIER_REGEX})([\\t ]*)\/([\\t ]*)#{SINGLE_KEYWORD_REGEX}([\\t ]*)(\\d+)#{KEYWORDS_SURFIX_REGEXP}"
  CROSS_PROJECT_REGEXP = /\b#{CROSS_PROJECT_BASE}/i
  CROSS_PROJECT_ANTIPATTERN = /\/#{CROSS_PROJECT_BASE}/i

  def initialize(project, keywords_str = nil)
    @project = project
    @keywords_str = if keywords_str.nil? or keywords_str.blank?
      DEFAULT_CARD_KEYWORDS.join(', ')
    else
      keywords_str
    end

    @keywords = @keywords_str.split(',').collect(&:strip)
  end

  def valid?
    @keywords_str =~ /^[^,]*(,[^,]+)*$/ and keywords.all?{|s| s.downcase =~ /^#{SINGLE_KEYWORD_REGEX}$/}
  end

  def included_in?(message, card_number)
    keywords_regexp(card_number) =~ message
  end

  def value_for_save
    return @keywords_str unless valid?
    (keywords == DEFAULT_CARD_KEYWORDS) ? nil : to_s
  end

  def to_s
    @keywords_str
  end

  def include?(keyword)
    @keywords.any?{ |e| e.downcase == keyword.downcase }
  end

  def to_xml(options = {})
    builder = (options[:builder] ||= xml_builder(options))
    keywords.each do |keyword|
      serialize_keyword keyword, options[:version], builder
    end
    builder
  end

  def card_prefixes_regexp
    keywords.collect{|prefix| (prefix.strip =~ /\W/) ? prefix.strip : '(?:\b*)' + prefix.strip}.join('|')
  end

  def invalid_message
     "Card keywords #{DEFAULT_INVALID_MESSAGE}"
  end

  def keywords_regexp(number='\d+')
    /(#{card_prefixes_regexp})([\t ]*)(#{number})#{KEYWORDS_SURFIX_REGEXP}/i
  end

  def keywords_regexp_string
    "(#{card_prefixes_regexp})([\\t ]*)(\\d+)"
  end

  def card_numbers_in(text)
    numbers = []
    text.scan(CROSS_PROJECT_REGEXP).each do |match|
      if match[0].downcase == @project.identifier && include?(match[3])
        numbers << match[5]
      end
    end

    text.scan(keywords_regexp).each do |match|
      numbers << match[2]
    end
    numbers.uniq
  end

  private

  def xml_builder(options)
    Builder::XmlMarkup.new({ :root => 'keywords', :indent => 2 }.merge(options))
  end

  def serialize_keyword(keyword, version, builder)
    if version == 'v1'
      builder.keyword { |key| key.value keyword }
    else
      builder.keyword keyword
    end
  end

  def keywords
    @keywords_str.split(',').collect(&:strip)
  end
end
