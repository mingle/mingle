# This file is autogenrated. DO NOT MODIFY!
#
# $Id: grammarfileparser.rb.in,v 1.5 2005/11/20 17:31:32 aamine Exp $
#
# Copyright (c) 1999-2005 Minero Aoki
#
# This program is free software.
# You can distribute/modify this program under the terms of
# the GNU LGPL, Lesser General Public License version 2.1.
# For details of the GNU LGPL, see the file "COPYING".
#

require 'racc/compat'
require 'racc/parser'
require 'racc/grammarfilescanner'
require 'racc/usercodeparser'
require 'racc/exception'

module Racc

  class GrammarFileParser < Parser

    def initialize(racc)
      @yydebug     = racc.d_parse && Racc_debug_parser
      @ruletable   = racc.ruletable
      @symboltable = racc.symboltable

      @class_name = nil
      @super_class = nil
    end

    attr_reader :class_name
    attr_reader :super_class

    def parse(str)
      @scanner = GrammarFileScanner.new(str)
      @scanner.debug = @yydebug
      do_parse
    end

    private

    def next_token
      @scanner.scan
    end

    def on_error(tok, val, _values)
      if val.respond_to?(:id2name)
        v = val.id2name
      elsif String === val
        v = val
      else
        v = val.inspect
      end
      raise CompileError, "#{@scanner.lineno}: unexpected token '#{v}'"
    end


##### racc 1.4.5 generates ###

racc_reduce_table = [
 0, 0, :racc_error,
 6, 25, :_reduce_1,
 1, 26, :_reduce_2,
 3, 26, :_reduce_3,
 1, 30, :_reduce_4,
 4, 30, :_reduce_5,
 0, 27, :_reduce_none,
 2, 27, :_reduce_none,
 3, 31, :_reduce_8,
 1, 31, :_reduce_none,
 2, 31, :_reduce_10,
 2, 31, :_reduce_11,
 2, 31, :_reduce_12,
 2, 31, :_reduce_13,
 2, 32, :_reduce_14,
 3, 32, :_reduce_15,
 3, 33, :_reduce_16,
 3, 33, :_reduce_17,
 1, 37, :_reduce_none,
 2, 37, :_reduce_none,
 2, 38, :_reduce_20,
 2, 38, :_reduce_21,
 2, 38, :_reduce_22,
 1, 35, :_reduce_23,
 2, 35, :_reduce_24,
 2, 35, :_reduce_none,
 1, 34, :_reduce_26,
 1, 34, :_reduce_27,
 1, 28, :_reduce_28,
 0, 28, :_reduce_none,
 1, 39, :_reduce_30,
 2, 39, :_reduce_31,
 2, 39, :_reduce_32,
 2, 39, :_reduce_33,
 1, 40, :_reduce_none,
 1, 40, :_reduce_35,
 2, 40, :_reduce_36,
 1, 40, :_reduce_37,
 1, 36, :_reduce_38,
 2, 36, :_reduce_39,
 1, 29, :_reduce_none,
 0, 29, :_reduce_none ]

racc_reduce_n = 42

racc_shift_n = 66

racc_action_table = [
    28,    47,    28,    42,    28,    28,    33,    34,    35,    27,
    43,    27,    28,    27,    27,    49,    50,    44,    45,    63,
    63,    27,    28,    33,    34,    35,    14,    63,    52,     9,
    17,    27,    18,    20,    11,    13,    28,    63,    15,    16,
    28,    28,    28,    61,    28,    27,    28,    28,    28,    27,
    27,    27,     8,    27,     9,    27,    27,    27,    58,    25,
    33,    34,    35,    54,    33,    34,    35,    24,    59,    22,
     4,    10,     1,     6,     4,    65 ]

racc_action_check = [
    29,    29,    44,    22,    57,    56,    16,    16,    16,    29,
    23,    44,    41,    57,    56,    29,    29,    29,    29,    57,
    56,    41,    55,    15,    15,    15,     7,    41,    30,    21,
     7,    55,     7,     7,     7,     7,    33,    55,     7,     7,
    38,    35,    18,    38,    34,    33,    20,    17,    14,    38,
    35,    18,     5,    34,     5,    20,    17,    14,    36,    13,
    36,    36,    36,    31,    31,    31,    31,    11,    37,     9,
     8,     6,     0,     2,     1,    60 ]

racc_action_pointer = [
    70,    69,    73,   nil,   nil,    48,    71,    23,    65,    63,
   nil,    62,   nil,    46,    43,     6,   -11,    42,    37,   nil,
    41,    23,    -2,     5,   nil,   nil,   nil,   nil,   nil,    -5,
    20,    47,   nil,    31,    39,    36,    43,    54,    35,   nil,
   nil,     7,   nil,   nil,    -3,   nil,   nil,   nil,   nil,   nil,
   nil,   nil,   nil,   nil,   nil,    17,     0,    -1,   nil,   nil,
    61,   nil,   nil,   nil,   nil,   nil ]

racc_action_default = [
   -42,   -42,   -42,    -6,    -4,    -2,   -42,   -42,   -42,   -42,
    66,   -42,    -9,   -42,   -29,   -42,   -42,   -42,   -42,    -7,
   -42,    -3,   -42,   -12,   -38,   -13,   -30,   -27,   -26,   -28,
   -41,   -42,   -18,   -42,   -42,   -42,   -42,   -42,   -42,   -10,
   -23,   -11,    -5,   -39,   -42,   -37,   -34,   -33,   -31,   -35,
   -32,    -1,   -40,   -19,   -16,   -20,   -21,   -22,   -17,   -14,
   -42,    -8,   -24,   -25,   -36,   -15 ]

racc_goto_table = [
    26,     5,    53,    37,    39,    41,    12,    53,    21,    31,
    36,    19,    38,     2,    51,    46,    30,    23,    55,    56,
    57,     7,     3,    29,    60,    48,   nil,    62,   nil,   nil,
    64,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,
   nil,    62,    62,    62 ]

racc_goto_check = [
    10,     6,    14,    10,    10,    11,     9,    14,     6,    13,
    13,     7,     8,     1,     5,    10,     4,    12,    11,    11,
    11,     3,     2,    15,    10,    16,   nil,    10,   nil,   nil,
    10,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,
   nil,    10,    10,    10 ]

racc_goto_pointer = [
   nil,    13,    21,    18,     2,   -16,     0,     4,    -5,    -1,
   -14,   -15,     6,    -6,   -29,     9,    -4 ]

racc_goto_default = [
   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,   nil,
    40,   nil,   nil,   nil,    32,   nil,   nil ]

racc_token_table = {
 false => 0,
 Object.new => 1,
 :XCLASS => 2,
 :XRULE => 3,
 "<" => 4,
 :XSYMBOL => 5,
 ":" => 6,
 :XCONV => 7,
 :XEND => 8,
 :XSTART => 9,
 :XTOKEN => 10,
 :XOPTION => 11,
 :XEXPECT => 12,
 :DIGIT => 13,
 :STRING => 14,
 :XPRECHIGH => 15,
 :XPRECLOW => 16,
 :XLEFT => 17,
 :XRIGHT => 18,
 :XNONASSOC => 19,
 "|" => 20,
 ";" => 21,
 "=" => 22,
 :ACTION => 23 }

racc_use_result_var = true

racc_nt_base = 24

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
'XCLASS',
'XRULE',
'"<"',
'XSYMBOL',
'":"',
'XCONV',
'XEND',
'XSTART',
'XTOKEN',
'XOPTION',
'XEXPECT',
'DIGIT',
'STRING',
'XPRECHIGH',
'XPRECLOW',
'XLEFT',
'XRIGHT',
'XNONASSOC',
'"|"',
'";"',
'"="',
'ACTION',
'$start',
'xclass',
'class',
'params',
'rules',
'opt_end',
'rubyconst',
'param_seg',
'convdefs',
'xprec',
'symbol',
'symbol_list',
'bare_symlist',
'preclines',
'precline',
'rules_core',
'rule_item']

Racc_debug_parser = false

##### racc system variables end #####

 # reduce 0 omitted

module_eval <<'.,.,', '(boot.rb)', 114
  def _reduce_1( val, _values, result )
    @ruletable.end_register_rule
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 119
  def _reduce_2( val, _values, result )
    @class_name = val[0]
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 123
  def _reduce_3( val, _values, result )
    @class_name = val[0]
    @super_class = val[2]
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 129
  def _reduce_4( val, _values, result )
    result = result.id2name
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 133
  def _reduce_5( val, _values, result )
    result << '::' << val[3].id2name
   result
  end
.,.,

 # reduce 6 omitted

 # reduce 7 omitted

module_eval <<'.,.,', '(boot.rb)', 141
  def _reduce_8( val, _values, result )
    @symboltable.end_register_conv
   result
  end
.,.,

 # reduce 9 omitted

module_eval <<'.,.,', '(boot.rb)', 146
  def _reduce_10( val, _values, result )
    @ruletable.register_start val[1]
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 150
  def _reduce_11( val, _values, result )
    @symboltable.register_token val[1]
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 154
  def _reduce_12( val, _values, result )
    val[1].each do |s|
      @ruletable.register_option s.to_s
    end
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 160
  def _reduce_13( val, _values, result )
    @ruletable.expect val[1]
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 165
  def _reduce_14( val, _values, result )
    @symboltable.register_conv val[0], val[1]
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 169
  def _reduce_15( val, _values, result )
    @symboltable.register_conv val[1], val[2]
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 174
  def _reduce_16( val, _values, result )
    @symboltable.end_register_prec true
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 178
  def _reduce_17( val, _values, result )
    @symboltable.end_register_prec false
   result
  end
.,.,

 # reduce 18 omitted

 # reduce 19 omitted

module_eval <<'.,.,', '(boot.rb)', 186
  def _reduce_20( val, _values, result )
    @symboltable.register_prec :Left, val[1]
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 190
  def _reduce_21( val, _values, result )
    @symboltable.register_prec :Right, val[1]
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 194
  def _reduce_22( val, _values, result )
    @symboltable.register_prec :Nonassoc, val[1]
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 199
  def _reduce_23( val, _values, result )
    result = val
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 203
  def _reduce_24( val, _values, result )
    result.push val[1]
   result
  end
.,.,

 # reduce 25 omitted

module_eval <<'.,.,', '(boot.rb)', 209
  def _reduce_26( val, _values, result )
    result = @symboltable.get(result)
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 213
  def _reduce_27( val, _values, result )
    result = @symboltable.get(eval(%Q<"#{result}">))
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 218
  def _reduce_28( val, _values, result )
    unless result.empty?
      @ruletable.register_rule_from_array result
    end
   result
  end
.,.,

 # reduce 29 omitted

module_eval <<'.,.,', '(boot.rb)', 226
  def _reduce_30( val, _values, result )
    result = val
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 230
  def _reduce_31( val, _values, result )
    result.push val[1]
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 234
  def _reduce_32( val, _values, result )
    unless result.empty?
      @ruletable.register_rule_from_array result
    end
    result.clear
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 241
  def _reduce_33( val, _values, result )
    pre = result.pop
    unless result.empty?
      @ruletable.register_rule_from_array result
    end
    result = [pre]
   result
  end
.,.,

 # reduce 34 omitted

module_eval <<'.,.,', '(boot.rb)', 251
  def _reduce_35( val, _values, result )
    result = OrMark.new(@scanner.lineno)
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 255
  def _reduce_36( val, _values, result )
    result = Prec.new(val[1], @scanner.lineno)
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 259
  def _reduce_37( val, _values, result )
    result = UserAction.new(*result)
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 264
  def _reduce_38( val, _values, result )
    result = [ result.id2name ]
   result
  end
.,.,

module_eval <<'.,.,', '(boot.rb)', 268
  def _reduce_39( val, _values, result )
    result.push val[1].id2name
   result
  end
.,.,

 # reduce 40 omitted

 # reduce 41 omitted

 def _reduce_none( val, _values, result )
  result
 end


  end

end   # module Racc
