# coding: utf-8

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

class String
  SPECIAL_VERBS = {'does' => 'do', 'has' => 'have', 'is' => 'are', 'contains' => 'contain', 'was' => 'were', 'aggregates' => 'aggregate'}
  SPECIAL_ADJECTIVES = {'this' => 'these'}
  WHITESPACE_REGEX_RUBY = /(?:\s|\302\240)+/ # includes non-breaking whitespace match for ruby 1.8.7

  def to_base64_url_safe
    [self].pack('m').gsub(/\s/m, '').tr('+', '*').tr('/', '-').gsub(/=*$/, '')
  end

  def from_base64_url_safe
    (self.tr('*', '+').tr('-', '/') + ('=' * self.length % 4)).unpack('m').first
  end

  def json_to_hash
    eval(self.gsub(/\"(\w+)\":/, ':\1 =>'))
  end

  def numeric?
    self =~ /^[-+]?[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$/
  end

  def is_boolean_value?
    %w(true false).include?(self)
  end

  def as_bool
    self.downcase == 'true'
  end

  def normalize_whitespace
    self.gsub(WHITESPACE_REGEX_RUBY, ' ').strip
  end

  def normalize_whitespace!
    self.gsub!(WHITESPACE_REGEX_RUBY, ' ').strip!
  end

  def strip_all!
    self.gsub!(WHITESPACE_REGEX_RUBY, '')
  end

  def strip_all
    self.gsub(WHITESPACE_REGEX_RUBY, '')
  end

  def strip_cr
    self.gsub(/\r/, '')
  end

  def remove_html_tags
    self.gsub(/<\/?[^>]*>/, '')
  end

  def trim
    self.strip.gsub(/\s{2,}/, ' ')
  end

  def underscored
    self.downcase.gsub(/\W/, '_')
  end

  def space2underscore
    self.gsub(/ /, '_')
  end

  def ignore_case_equal?(right)
    return false unless right
    java.lang.String.new(right).equalsIgnoreCase(self)
  end

  def bold
    "#{MingleFormatting::MINGLE_BOLD_MARKER_OPEN}#{self}#{MingleFormatting::MINGLE_BOLD_MARKER_CLOSE}"
  end
  alias_method :bold_without_escape, :bold

  # deprecated: please do not use me
  def html_bold
    "<b>#{self}</b>"
  end

  def as_li
    "#{MingleFormatting::MINGLE_LIST_ITEM_MARKER_OPEN}#{self}#{MingleFormatting::MINGLE_LIST_ITEM_MARKER_CLOSE}"
  end

  def italic
    "#{MingleFormatting::MINGLE_ITALIC_MARKER_OPEN}#{self}#{MingleFormatting::MINGLE_ITALIC_MARKER_CLOSE}"
  end

  def as_ul
    "#{MingleFormatting::MINGLE_UNORDERED_LIST_MARKER_OPEN}#{self}#{MingleFormatting::MINGLE_UNORDERED_LIST_MARKER_CLOSE}"
  end

  def no_textile
    "<notextile>#{self}</notextile>"
  end

  def no_textile_block
    # the tricky part of notextile in redcloth is, when the line only contains a notextile node, redcloth will ignore the content and think it's empty
    # and it turns out that no line breaks anymore for the notextile line, and no <p> tag wrap anymore,
    # so we put a span wrap to make sure redcloth still think it's a line and wrap it in a <p> tag when need
    # and I don't want to mess with original no_textile, so that we use it only when we need, e.g. when a subsitution only return a no_textiled text
    "<span>#{self.no_textile}</span>"
  end

  def as_mql
    MqlSupport.quote_mql_value_if_needed(self)
  end

  def enumerate(size)
    "#{size} #{self.plural(size)}"
  end

  def plural(size, options = { :use_special_verbs => true })
    return self.plural_verb(size) if (SPECIAL_VERBS.keys + SPECIAL_VERBS.values).include?(self) && options[:use_special_verbs]
    return self.plural_adjective(size) if (SPECIAL_ADJECTIVES.keys + SPECIAL_ADJECTIVES.values).include?(self)

    return "#{self.singularize}" if size.to_i == 1
    return self.pluralize if size.to_i > 1 || size.to_i == 0
    self
  end

  def plural_verb(size)
    plural_words(size, SPECIAL_VERBS)
  end

  def plural_adjective(size)
    plural_words(size, SPECIAL_ADJECTIVES)
  end

  #this is different from dasherize, as that only replaces underscores with dashes
  def dashed
    self.gsub(/[\/ ,]+/, '-')
  end

  def uniquify
    "#{self}_#{UUID.generate(:compact)}"
  end

  def uniquify_with_succession(maxlen, suffix='', &existing)
    str = truncate_with_suffix(maxlen, suffix)
    return str+suffix unless yield(str+suffix)

    appending_number = 1
    loop do
      str = str.truncate_with_suffix(maxlen, suffix + appending_number.to_s)
      break unless yield("#{str}#{suffix}#{appending_number}")
      appending_number += 1
    end

    "#{str}#{suffix}#{appending_number}"
  end

  def truncate_with_suffix(maxlen, suffix='')
    length + suffix.length > maxlen  ? self[0..(maxlen - suffix.length - 1)] : self
  end

  def starts_with?(target)
    self.slice(0, target.length) == target
  end

  def truncate_with_ellipses(length)
    return self if self.length <= length
    self.slice(0..length - 4) + '...'
  end

  def to_num(precision = nil)
    is_integer = (self.to_i == self.to_f)
    if is_integer
      self.to_i
    else
      return self.to_f.round_to(precision) if precision
      self.to_f
    end
  end

  def to_num_maintain_precision(precision)
    return self if self.nil? || self.blank? || !self.numeric?
    original_precision = self =~ /\.(\d*)$/ ? $1.length : 0
    result = self =~ /(\.\d{#{precision + 1},})|(\.$)/ ? self.to_num(precision).to_s : self
    final_precision = (original_precision >= precision) ? precision : original_precision
    sprintf("%.#{final_precision}f", result)
  end

  def db_value
    self.blank? ? nil : self
  end

  # if the string is a html safe string, would not escape again
  # unless you changed the implementation :)
  def escape_html
    ERB::Util.h(self)
  end

  AMPERSAND_MARKER = 'MINGLE89a2cc582f9599586fe706944d8a874c8568cccd'
  def apply_redcloth(options={})
    cloth = RedCloth.new(self.gsub(/&/, AMPERSAND_MARKER))
    if options[:no_span_caps]
      cloth.no_span_caps = true
    end
    if options[:lite_mode]
      cloth.lite_mode = true
    end
    content = options[:rules] ? cloth.to_html(options[:rules]) : cloth.to_html
    content.gsub(AMPERSAND_MARKER, '&')
  end

  def idlize
    name = (self =~ /^\((.*)\)&/) ? $1 : self
    name.downcase.underscored
  end

  def opens_and_closes_with_parentheses
    self =~ /^\((.*)\)$/
  end

  def in_parenthesis
    "(#{self})"
  end

  def unquote
    case self
      when /^'(.*)'$/ then $1
      when /^"(.*)"$/ then $1
      else self
    end
  end

  def unescape_quote
    self.gsub(/\\(['|"])/, '\1')
  end

  def shorten(max_length, digest_length=8)
    raise "max length (#{max_length}) should be larger than digest_length (#{digest_length})" if max_length < digest_length
    return self if size <= max_length
    self[0..(max_length - digest_length - 1)] + sha1[0..(digest_length - 1)]
  end

  def md5
    MD5::md5(self).to_s
  end

  def sha2
    Digest::SHA256.hexdigest(self)
  end

  def sha1
    Digest::SHA1.hexdigest(self)
  end
  
  def to_hex_string
    self.each_byte.map{|b| b.to_s(16)}.join
  end

  private
  def plural_words(size, special_words)
    return self if special_words.keys.include?(self) && size.to_i == 1
    return special_words.invert[self] if special_words.values.include?(self) && size.to_i > 1

    return special_words[self] if special_words.keys.include?(self) && size.to_i > 1
    return special_words.invert[self] if special_words.values.include?(self) && size.to_i == 1
  end
end
