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

class Date

  if defined?(MONTHS) # ruby 1.8.5
    MONTH_MAPPINGS = MONTHS.merge(ABBR_MONTHS)
  else # ruby 1.8.6
    MONTH_MAPPINGS = Date::Format::MONTHS.merge(Date::Format::ABBR_MONTHS)
  end

  DAY_MONTH_YEAR = "%d/%m/%Y"
  MONTH_DAY_YEAR = "%m/%d/%Y"
  YEAR_MONTH_DAY = "%Y/%m/%d"
  DAY_LONG_MONTH_YEAR = "%d %b %Y"
  LONG_MONTH_DAY_YEAR = "%b %d %Y"

  def self.date_format_parse_order
    @__date_format_parse_order ||= {
      DAY_MONTH_YEAR.dashed => [DAY_MONTH_YEAR, MONTH_DAY_YEAR, YEAR_MONTH_DAY, DAY_LONG_MONTH_YEAR, LONG_MONTH_DAY_YEAR].collect(&:dashed),
      MONTH_DAY_YEAR.dashed => [MONTH_DAY_YEAR, DAY_MONTH_YEAR, YEAR_MONTH_DAY, LONG_MONTH_DAY_YEAR, DAY_LONG_MONTH_YEAR].collect(&:dashed),
      YEAR_MONTH_DAY.dashed => [YEAR_MONTH_DAY, DAY_MONTH_YEAR, MONTH_DAY_YEAR, LONG_MONTH_DAY_YEAR, DAY_LONG_MONTH_YEAR].collect(&:dashed),
      DAY_LONG_MONTH_YEAR.dashed => [DAY_LONG_MONTH_YEAR, DAY_MONTH_YEAR, LONG_MONTH_DAY_YEAR, MONTH_DAY_YEAR, YEAR_MONTH_DAY].collect(&:dashed),
      LONG_MONTH_DAY_YEAR.dashed => [LONG_MONTH_DAY_YEAR, MONTH_DAY_YEAR, DAY_LONG_MONTH_YEAR, DAY_MONTH_YEAR, YEAR_MONTH_DAY].collect(&:dashed)
    }
  end

  def self.gsub_date!(string, preferred_format, &block)
    return [] unless string.respond_to?(:split)
    preferred_format = preferred_format.dashed
    date_format_parse_order[preferred_format].each do |format|
      string.gsub!(pattern_for_format(format, false)) do |match|
        yield(parse_with_hint(match, format)) rescue match
      end
    end
    string.gsub!(pattern_for_format('%d-%m', false)) do |match|
      yield(parse_with_hint(match, '%d-%m-%Y')) rescue match
    end
    string.gsub!(pattern_for_format('%m-%d', false)) do |match|
      yield(parse_with_hint(match, '%m-%d-%Y')) rescue match
    end
  end

  def self.parse_with_hint(string, preferred_format)
    return unless string && preferred_format
    preferred_format = preferred_format.dashed
    string = string.dashed
    string = default_to_current_year(string, preferred_format)

    preferred_formats = if date_format_parse_order[preferred_format]
      date_format_parse_order[preferred_format]
    else
      [preferred_format]
    end

    preferred_formats.each do |format|
      begin
        if (string =~ pattern_for_format(format))
          date = Date.strptime(string, format)
          # in the case that year is 07 we will get 0007 so we attempt a 2 digit year format
          if (date.year < 100 && !(string =~ /-\d{4}$/))
            date = Date.strptime(string, format.gsub(/%Y/, '%y'))
          end
          return date
        end
      rescue ArgumentError
        next
      end
    end
    date = Date.parse(string, true)
    raise ArgumentError if date.year < 0
    date
  end

  unless MingleUpgradeHelper.ruby_1_9?
    def +(n)
      if Numeric === n
        return self.class.respond_to?(:new0) ? self.class.new0(@ajd + n, @of, @sg) : self.class.new!(@ajd + n, @of, @sg)
      end
      raise TypeError
    end

    def -(x)
      case
        when Numeric === x; return self.class.respond_to?(:new0) ? self.class.new0(@ajd - x, @of, @sg) : self.class.new!(@ajd - x, @of, @sg)
        when Date === x;    return @ajd - x.ajd
      end
      raise TypeError
    end
  end

  self.send(:define_method, '+_with_coercion') do |n|
    begin
      return self.send('+_without_coercion',n)
    rescue TypeError
      return coerce_add(n) if n.respond_to?(:coerce)
    end
    raise TypeError, 'expected numeric'
  end

  def coerce_add(coerceable)
    sum = coerceable.coerce(self).sum
    sum = sum.value if sum.respond_to?(:value)
    return coerceable unless sum.to_s
    return self.class.respond_to?(:new0) ? self.class.new0(sum, @of, @sg) : self.class.new!(sum, @of, @sg)
  end

  self.send(:define_method, '-_with_coercion') do |x|
    begin
      return self.send('-_without_coercion',x)
    rescue TypeError
      return coerce_subtract(x) if x.respond_to?(:coerce)
    end
    raise TypeError, 'expected numeric or date'
  end

  def coerce_subtract(coerceable)
    subtractables = coerceable.coerce(self)
    difference = subtractables[0] - subtractables[1]
    return difference if subtractables.all? { |s| s.is_a?(Date) }
    difference = difference.value if difference.respond_to?(:value)
    return coerceable unless difference.to_s
    return self.class.respond_to?(:new0) ? self.class.new0(difference, @of, @sg) : self.class.new!(difference, @of, @sg)
  end

  alias_method_chain :-, :coercion
  alias_method_chain :+, :coercion

  def to_epoch_milliseconds
    self.to_time.milliseconds.to_i
  end

  private

  def self.default_to_current_year(string, preferred_format)
    current_year = Clock.now.year.to_s
    if (string =~ /^\d{1,2}-\d{1,4}$/)
      preferred_format.gsub(/(%d-%m)|(%m-%d)|(%d-%b)|(%b-%d)/, string).gsub(/%Y/, current_year)
    elsif (string =~ /^((\d{1,2}-[a-zA-Z]+)|([a-zA-Z]+-\d{1,2}))$/)
      string += "-#{current_year}"
    else
      string
    end
  end

  def self.pattern_for_format(format, stricted=true)
    pattern = format.gsub(/%d/, '(\d{1,2})')
    pattern.gsub!(/(%m)|(%b)/, "(\\d{1,2}|#{MONTH_MAPPINGS.keys.join('|')})")
    pattern.gsub!(/%Y/i, '(\d{1,4})')
    pattern.gsub!(/-/, '((\s|-|\/)+)')
    stricted ? Regexp.new("^#{pattern}$", true) : Regexp.new("(\\b|^)(#{pattern})(\\b|$)", true)
  end
end
