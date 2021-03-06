# DO NOT MODIFY!!!!
# This file is automatically generated by racc 1.4.5
# from racc grammer file "lib/formula_properties.grammar".

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


require 'racc/parser'


require 'strscan'

class FormulaParser < Racc::Parser

module_eval <<'..end lib/formula_properties.grammar modeval..ida9ef9302f1', 'lib/formula_properties.grammar', 36

def unquote(value)
  case value
  when /^'(.*)'$/ then $1
  when /^"(.*)"$/ then $1
  else value
  end
end

def escape_repeated_quotes(str)
  str.gsub(/''/, "'").gsub(/""/, '"')
end

def parse(str, null_is_zero=false)
  @input = str
  @null_is_zero = null_is_zero
  tokens = []
  str = "" if str.nil?

  scanner = StringScanner.new(str)

  until scanner.eos?
    case
    when scanner.scan(/\s+/)
      # ignore space
    when m = scanner.scan(/((\d+\.?\d*)|(\d*\.?\d+))/)
      tokens.push [:NUMBER, m.to_num]
    when m = scanner.scan(/\+/i)
      tokens.push [:PLUS, m]
    when m = scanner.scan(/\-/i)
      tokens.push [:MINUS, m]
    when m = scanner.scan(/\*/i)
      tokens.push [:MULTIPLY, m]
    when m = scanner.scan(/\//i)
      tokens.push [:DIVIDE, m]
    when m = scanner.scan(/\(/i)
      tokens.push [:L_PAREN, m]
    when m = scanner.scan(/\)/i)
      tokens.push [:R_PAREN, m]
    when m = scanner.scan(/\{/i)
      tokens.push [:L_CURLY, m]
    when m = scanner.scan(/\}/i)
      tokens.push [:R_CURLY, m]
    when m = scanner.scan(/\[/i)
      tokens.push [:L_BOX, m]
    when m = scanner.scan(/\]/i)
      tokens.push [:R_BOX, m]
    when m = scanner.scan(/'((('')|[^'])+)'/)
      tokens.push   [:IDENTIFIER, escape_repeated_quotes(unquote(m))]
    when m = scanner.scan(/"((("")|[^"])+)"/)
      tokens.push   [:IDENTIFIER, escape_repeated_quotes(unquote(m))]
    when m = scanner.scan(/(""|''|[!@$%\^_\\~`{}|;.,:?<>]|[^\s\/\+\-\*\(\)\[\]&=#;"'])+/)
      tokens.push   [:IDENTIFIER, escape_repeated_quotes(m)]
    else
      unexpected_chars = scanner.peek(10)
      unexpected_chars += ".." if unexpected_chars.length > 9
      raise "Unexpected characters encountered: #{unexpected_chars}"
    end
  end
  tokens.push [false, false]
  yyparse(tokens, :each)
end
..end lib/formula_properties.grammar modeval..ida9ef9302f1

##### racc 1.4.5 generates ###

racc_reduce_table = [
 0, 0, :racc_error,
 1, 17, :_reduce_1,
 3, 18, :_reduce_2,
 3, 18, :_reduce_3,
 3, 18, :_reduce_4,
 3, 18, :_reduce_5,
 3, 18, :_reduce_6,
 3, 18, :_reduce_7,
 3, 18, :_reduce_8,
 2, 18, :_reduce_9,
 1, 18, :_reduce_10,
 1, 18, :_reduce_11 ]

racc_reduce_n = 12

racc_shift_n = 26

racc_action_table = [
    12,    13,    10,    11,    18,     6,     7,     3,     9,     4,
    25,     5,    12,    13,     8,     6,     7,     3,   nil,     4,
   nil,     5,    12,    13,     8,     6,     7,     3,   nil,     4,
   nil,     5,   nil,   nil,     8,     6,     7,     3,   nil,     4,
   nil,     5,   nil,   nil,     8,     6,     7,     3,   nil,     4,
   nil,     5,   nil,   nil,     8,     6,     7,     3,   nil,     4,
   nil,     5,   nil,   nil,     8,     6,     7,     3,   nil,     4,
   nil,     5,   nil,   nil,     8,     6,     7,     3,   nil,     4,
   nil,     5,   nil,   nil,     8,     6,     7,     3,   nil,     4,
   nil,     5,   nil,   nil,     8,    12,    13,    10,    11,    12,
    13,    10,    11,    24,   nil,    23,    12,    13,    10,    11 ]

racc_action_check = [
    16,    16,    16,    16,     9,    13,    13,    13,     1,    13,
    16,    13,    19,    19,    13,     3,     3,     3,   nil,     3,
   nil,     3,    20,    20,     3,     4,     4,     4,   nil,     4,
   nil,     4,   nil,   nil,     4,     5,     5,     5,   nil,     5,
   nil,     5,   nil,   nil,     5,     6,     6,     6,   nil,     6,
   nil,     6,   nil,   nil,     6,    12,    12,    12,   nil,    12,
   nil,    12,   nil,   nil,    12,    10,    10,    10,   nil,    10,
   nil,    10,   nil,   nil,    10,    11,    11,    11,   nil,    11,
   nil,    11,   nil,   nil,    11,     0,     0,     0,   nil,     0,
   nil,     0,   nil,   nil,     0,    15,    15,    15,    15,    14,
    14,    14,    14,    15,   nil,    14,     2,     2,     2,     2 ]

racc_action_pointer = [
    79,     8,   103,     9,    19,    29,    39,   nil,   nil,     4,
    59,    69,    49,    -1,    96,    92,    -3,   nil,   nil,     9,
    19,   nil,   nil,   nil,   nil,   nil ]

racc_action_default = [
   -12,   -12,    -1,   -12,   -12,   -12,   -12,   -10,   -11,   -12,
   -12,   -12,   -12,   -12,   -12,   -12,   -12,    -9,    26,    -2,
    -3,    -4,    -5,    -6,    -7,    -8 ]

racc_goto_table = [
     2,     1,   nil,    14,    15,    16,    17,   nil,   nil,   nil,
    19,    20,    21,    22 ]

racc_goto_check = [
     2,     1,   nil,     2,     2,     2,     2,   nil,   nil,   nil,
     2,     2,     2,     2 ]

racc_goto_pointer = [
   nil,     1,     0 ]

racc_goto_default = [
   nil,   nil,   nil ]

racc_token_table = {
 false => 0,
 Object.new => 1,
 :UMINUS => 2,
 :MULTIPLY => 3,
 :DIVIDE => 4,
 :PLUS => 5,
 :MINUS => 6,
 :NUMBER => 7,
 :L_PAREN => 8,
 :R_PAREN => 9,
 :L_CURLY => 10,
 :R_CURLY => 11,
 :L_BOX => 12,
 :R_BOX => 13,
 :TODAY => 14,
 :IDENTIFIER => 15 }

racc_use_result_var = false

racc_nt_base = 16

Racc_arg = [
 racc_action_table,
 racc_action_check,
 racc_action_default,
 racc_action_pointer,
 racc_goto_table,
 racc_goto_check,
 racc_goto_default,
 racc_goto_pointer,
 racc_nt_base,
 racc_reduce_table,
 racc_token_table,
 racc_shift_n,
 racc_reduce_n,
 racc_use_result_var ]

Racc_token_to_s_table = [
'$end',
'error',
'UMINUS',
'MULTIPLY',
'DIVIDE',
'PLUS',
'MINUS',
'NUMBER',
'L_PAREN',
'R_PAREN',
'L_CURLY',
'R_CURLY',
'L_BOX',
'R_BOX',
'TODAY',
'IDENTIFIER',
'$start',
'target',
'exp']

Racc_debug_parser = false

##### racc system variables end #####

 # reduce 0 omitted

module_eval <<'.,.,', 'lib/formula_properties.grammar', 18
  def _reduce_1( val, _values)
 Formula::Output.new(val[0])
  end
.,.,

module_eval <<'.,.,', 'lib/formula_properties.grammar', 20
  def _reduce_2( val, _values)
 Formula::Addition.new(val[0], val[2])
  end
.,.,

module_eval <<'.,.,', 'lib/formula_properties.grammar', 21
  def _reduce_3( val, _values)
 Formula::Subtraction.new(val[0], val[2])
  end
.,.,

module_eval <<'.,.,', 'lib/formula_properties.grammar', 22
  def _reduce_4( val, _values)
 Formula::Multiplication.new(val[0], val[2])
  end
.,.,

module_eval <<'.,.,', 'lib/formula_properties.grammar', 23
  def _reduce_5( val, _values)
 Formula::Division.new(val[0], val[2])
  end
.,.,

module_eval <<'.,.,', 'lib/formula_properties.grammar', 24
  def _reduce_6( val, _values)
 Formula.new(val[1])
  end
.,.,

module_eval <<'.,.,', 'lib/formula_properties.grammar', 25
  def _reduce_7( val, _values)
 Formula.new(val[1], ['{', '}'])
  end
.,.,

module_eval <<'.,.,', 'lib/formula_properties.grammar', 26
  def _reduce_8( val, _values)
 Formula.new(val[1], ['[', ']'])
  end
.,.,

module_eval <<'.,.,', 'lib/formula_properties.grammar', 27
  def _reduce_9( val, _values)
 Formula::Negation.new(val[1])
  end
.,.,

module_eval <<'.,.,', 'lib/formula_properties.grammar', 28
  def _reduce_10( val, _values)
 Formula::Primitive.create(val[0])
  end
.,.,

module_eval <<'.,.,', 'lib/formula_properties.grammar', 29
  def _reduce_11( val, _values)
 Formula::CardPropertyValue.new(val[0], @null_is_zero)
  end
.,.,

 def _reduce_none( val, _values)
  val[0]
 end

end   # class FormulaParser
