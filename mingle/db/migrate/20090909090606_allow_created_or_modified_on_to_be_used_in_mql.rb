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

class M2009090909060Formula
  class FormulaParser < Racc::Parser
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

    def parse(str)
      @input = str
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
        when m = scanner.scan(/(""|''|[\w!@$%\^_\\~`{}|;.,:?<>])+/)
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
        12,    13,    14,    15,    11,     3,     5,     7,    19,     8,
        18,     1,    12,    13,     2,     3,     5,     7,   nil,     8,
       nil,     1,    12,    13,     2,     3,     5,     7,   nil,     8,
       nil,     1,   nil,   nil,     2,     3,     5,     7,   nil,     8,
       nil,     1,   nil,   nil,     2,     3,     5,     7,   nil,     8,
       nil,     1,   nil,   nil,     2,     3,     5,     7,   nil,     8,
       nil,     1,   nil,   nil,     2,     3,     5,     7,   nil,     8,
       nil,     1,   nil,   nil,     2,     3,     5,     7,   nil,     8,
       nil,     1,   nil,   nil,     2,     3,     5,     7,   nil,     8,
       nil,     1,   nil,   nil,     2,    12,    13,    14,    15,    12,
        13,    14,    15,    25,   nil,    24,    12,    13,    14,    15 ]

    racc_action_check = [
         9,     9,     9,     9,     4,     0,     0,     0,    11,     0,
         9,     0,    22,    22,     0,     3,     3,     3,   nil,     3,
       nil,     3,    23,    23,     3,    15,    15,    15,   nil,    15,
       nil,    15,   nil,   nil,    15,    14,    14,    14,   nil,    14,
       nil,    14,   nil,   nil,    14,     7,     7,     7,   nil,     7,
       nil,     7,   nil,   nil,     7,     8,     8,     8,   nil,     8,
       nil,     8,   nil,   nil,     8,     1,     1,     1,   nil,     1,
       nil,     1,   nil,   nil,     1,    13,    13,    13,   nil,    13,
       nil,    13,   nil,   nil,    13,    12,    12,    12,   nil,    12,
       nil,    12,   nil,   nil,    12,    17,    17,    17,    17,    16,
        16,    16,    16,    17,   nil,    16,     6,     6,     6,     6 ]

    racc_action_pointer = [
        -1,    59,   nil,     9,     4,   nil,   103,    39,    49,    -3,
       nil,     8,    79,    69,    29,    19,    96,    92,   nil,   nil,
       nil,   nil,     9,    19,   nil,   nil ]

    racc_action_default = [
       -12,   -12,   -11,   -12,   -12,   -10,    -1,   -12,   -12,   -12,
        -9,   -12,   -12,   -12,   -12,   -12,   -12,   -12,    -8,    26,
        -4,    -5,    -2,    -3,    -6,    -7 ]

    racc_goto_table = [
         6,     9,     4,    10,   nil,   nil,   nil,    16,    17,   nil,
       nil,   nil,    20,    21,    22,    23 ]

    racc_goto_check = [
         2,     2,     1,     2,   nil,   nil,   nil,     2,     2,   nil,
       nil,   nil,     2,     2,     2,     2 ]

    racc_goto_pointer = [
       nil,     2,     0 ]

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

      def _reduce_1( val, _values)
     Formula.new(val[0])
      end

      def _reduce_2( val, _values)
     Formula::Addition.new(val[0], val[2])
      end

      def _reduce_3( val, _values)
     Formula::Subtraction.new(val[0], val[2])
      end

      def _reduce_4( val, _values)
     Formula::Multiplication.new(val[0], val[2])
      end

      def _reduce_5( val, _values)
     Formula::Division.new(val[0], val[2])
      end

      def _reduce_6( val, _values)
     Formula.new(val[1])
      end

      def _reduce_7( val, _values)
     Formula.new(val[1], ['{', '}'])
      end

      def _reduce_8( val, _values)
     Formula.new(val[1], ['[', ']'])
      end

      def _reduce_9( val, _values)
     Formula::Negation.new(val[1])
      end

      def _reduce_10( val, _values)
     Formula::Primitive.create(val[0])
      end

      def _reduce_11( val, _values)
     Formula::CardPropertyValue.new(val[0])
      end

     def _reduce_none( val, _values)
      val[0]
     end
  end   # class FormulaParser

  class Formula

    def initialize(formula, parentheses=['(', ')'])
      @formula = formula
      @parentheses = parentheses
    end  

    def rename_property(old_name, new_name)
      @formula.rename_property(old_name, new_name)
    end
    
    def to_s
      "#{@parentheses.first}#{@formula}#{@parentheses.last}"
    end
  end  

  class Formula::Primitive < Formula
    class << self
      def create(primitive_value)
        primitive_value.respond_to?(:strftime) ? Formula::DatePrimitive.new(primitive_value) : Formula::NumericPrimitive.new(primitive_value)
      end
    end
    
    def to_s
      "#{@value}"
    end
    
    def rename_property(old_name, new_name); end
  end

  class Formula::DatePrimitive < Formula::Primitive
  end

  class Formula::NumericPrimitive < Formula::Primitive
    def initialize(number)
      @value = if (number.respond_to?(:value))
        number.value
      else
        number
      end    
    end
  end

  class Formula::Null < Formula::Primitive
    def to_s; nil; end
  end

  class Formula::CardPropertyValue < Formula
    def initialize(property_name)
      @property_name = property_name
      @invalid_properties = []
    end

    def to_s
      if @property_name =~ /'.*"|".*'/
        property_name = @property_name.gsub(/'/, "''").gsub(/"/, '""') 
      else
        property_name = @property_name
      end

      if property_name.gsub(/''/, "") =~ /'/
        "\"#{property_name}\""
      elsif property_name =~ /\s/ || has_a_math_operator(property_name) || just_numbers(property_name)
        "'#{property_name}'"
      elsif property_name =~ /\(|\)/
        "'#{property_name}'"
      elsif property_name.gsub(/""/, "") =~ /"/
        "'#{property_name}'"
      else
        property_name
      end
    end

    def rename_property(old_name, new_name)
      if @property_name.downcase == old_name.downcase
        @property_name = new_name
      end
    end

    private

    def has_a_math_operator(str)
      str =~ /[+\-*\/]+/
    end

    def just_numbers(str)
      str =~ /\A\d+\Z/
    end
  end

  class Formula::Operator < Formula
    def rename_property(old_name, new_name)
      operands.each { |operand| operand.rename_property(old_name, new_name) }
    end
  end

  class Formula::Addition < Formula::Operator
    def initialize(operand1, operand2)
      @operand1, @operand2 = operand1, operand2
    end
    
    def operands
      [@operand1, @operand2]
    end

    def to_s
      "#{@operand1} + #{@operand2}"
    end
  end

  class Formula::Negation < Formula::Operator
    def initialize(operand)
      @operand = operand
    end
    
    def operands
      [@operand]
    end
    
    def to_s
      "-#{@operand}"
    end
  end

  class Formula::Subtraction < Formula::Operator

    def initialize(operand1, operand2)
      @operand1, @operand2 = operand1, operand2
    end
    
    def operands
      [@operand1, @operand2]
    end

    def to_s
      "#{@operand1} - #{@operand2}"
    end  
  end

  class Formula::Multiplication < Formula::Operator
    def initialize(operand1, operand2)
      @operand1, @operand2 = operand1, operand2
    end
    
    def operands
      [@operand1, @operand2]
    end

    def to_s
      "#{@operand1} * #{@operand2}"
    end
  end  

  class Formula::Division < Formula::Operator
    def initialize(operand1, operand2)
      @operand1, @operand2 = operand1, operand2
    end  
    
    def operands
      [@operand1, @operand2]
    end
    
    def to_s
      "#{@operand1} / #{@operand2}"
    end
  end

  class Formula::UnsupportedOperationException < StandardError; end

  class Formula::Number 
  end

  class Formula::Date
  end

  class Formula::NullType 
  end
end # end of Formula.class

class M2009090909060Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  has_many :property_definitions, :class_name => 'M2009090909060PropertyDefinition', :foreign_key => 'project_id'
  has_many :card_list_views, :class_name => 'M2009090909060CardListView', :foreign_key => 'project_id'
end

class M2009090909060CardListView < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}card_list_views"
  belongs_to :project_id, :class_name => 'M2009091506314Project', :foreign_key => 'project_id'
end

class M2009090909060PropertyDefinition < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}property_definitions"
  self.inheritance_column = 'M2009090909060_type' #disable single table inheretance
  belongs_to :project, :class_name => 'M2009090909060Project', :foreign_key => 'project_id'
  def quoted_column_name
    "#{Project.connection.quote_column_name(column_name)}"
  end
  
end

class AllowCreatedOrModifiedOnToBeUsedInMql < ActiveRecord::Migration
  def self.up
    M2009090909060Project.find(:all).each do |project|
      rename_predifined_property(project, 'created on')
      rename_predifined_property(project, 'modified on')
    end
  end
  
  class << self
    def fix_formula_usage(project, predefined_property_name, to_name)
      formula_paser = M2009090909060Formula::FormulaParser.new
      project.property_definitions.find_all_by_type('FormulaPropertyDefinition').each do |formula_prop_def|
        formula = formula_paser.parse(formula_prop_def.formula)
        formula.rename_property(predefined_property_name, to_name)
        formula_prop_def.formula = formula.to_s[1..-2]
        formula_prop_def.save!
      end
    end
    
    def fix_changes_usage(predefined_property_name, to_name)
      ActiveRecord::Base.connection.execute <<-SQL
        UPDATE #{safe_table_name('changes')} 
        SET field='#{to_name}' 
        WHERE type='PropertyChange' AND LOWER(field)='#{predefined_property_name.downcase}'
      SQL
    end
    
    def fix_filter_usage(project, predefined_property_name, to_name)
      project.card_list_views.each do |view|
        filter_string = view.params
        if filter_string =~ /\b#{predefined_property_name}\b/im
          filter_string.gsub! /\[#{predefined_property_name}\]\[([^\]]*)\]\[([^\]]*)\]/im do |match|
            "[#{to_name}][#{$1}][#{$2}]"
          end
          filter_string.gsub!(/:columns: (.*)$/) do |match|
            columns_match = $1
            columns = columns_match.split(',')
            columns = columns.collect {|column| column.trim.downcase == predefined_property_name ? to_name : column }
            ":columns: #{columns.join(',')}"
          end
            
          view.params = filter_string
          
          view.canonical_string.gsub! /\[#{predefined_property_name}\]\[([^\]]*)\]\[([^\]]*)\]/im do |match|
             "[#{to_name}][#{$1}][#{$2}]"
          end
          view.canonical_string = view.canonical_string.split(',').collect do |part|
            if part.downcase == predefined_property_name
              to_name
            elsif part.downcase == "columns=#{predefined_property_name}"
              "columns=#{to_name}"
            else
              part
            end
          end.join(',')
          
          view.save!
        end
      end
    end
  end
  
  def self.rename_predifined_property(project, predefined_property_name)
    conflict_property_definition = project.property_definitions.detect do |prop_def|
      predefined_property_name == prop_def.name.downcase
    end
    
    property_definition_names = project.property_definitions.collect(&:name)
    
    if conflict_property_definition
      renaming_chart = []
      to_name = build_new_name_for(conflict_property_definition.name, property_definition_names)
      conflict_property_definition.update_attribute :name, to_name
      fix_formula_usage(project, predefined_property_name, to_name)
      fix_changes_usage(predefined_property_name, to_name)
      fix_filter_usage(project, predefined_property_name, to_name)
    end
  end
  
  def self.down
  end
  
  def self.build_new_name_for(original_name, existing_names, suffix = 1)
    protential_name =  "#{original_name}_#{suffix}"
    if !existing_names.collect(&:downcase).include?(protential_name.downcase)
      return protential_name
    else
      build_new_name_for(original_name, existing_names, suffix + 1)
    end
  end
  
end
