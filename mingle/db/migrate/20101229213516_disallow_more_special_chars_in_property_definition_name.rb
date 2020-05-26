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

class DisallowMoreSpecialCharsInPropertyDefinitionName < ActiveRecord::Migration
  INVALID_CHARS = /[";]/
  
  def self.up
    projects_with_invalid_property_definitions = []
    
    M20101229213516Project.all.each do |project|
      project.with_active_project do
        project.all_property_definitions.each do |property_definition|
          next if property_definition.name !~ INVALID_CHARS

          new_proposed_name = property_definition.name.gsub(INVALID_CHARS, '_')
          new_appendage = next_unique_appendage do |next_appendage|
            project.all_property_definitions.any? { |definition| definition.name.downcase == new_proposed_name.downcase + next_appendage }
          end
          new_unique_name = new_proposed_name + new_appendage
          property_definition.update_attributes!(:name => new_unique_name)

          projects_with_invalid_property_definitions << project
        end
      end
    end
    
    projects_with_invalid_property_definitions.uniq.each do |project|
      ActiveRecord::Base.logger.info "[DisallowMoreSpecialCharsInPropertyDefinitionName] Re-generating changes for project '#{project.identifier}'."
      project.with_active_project do
        ::HistoryGeneration::ProjectChangesGenerationProcessor.new.send_message(::HistoryGeneration::ProjectChangesGenerationProcessor::QUEUE, [Messaging::SendingMessage.new(:id => project.id)])
      end
    end
  end

  def self.down
  end
  
  def self.next_unique_appendage
    append, number = '', 0
    while yield(append)
      number = number.succ
      append = number.to_s
    end
    append
  end
end

class M20101229213516HistoryFilterParams
  PARAM_KEYS = ['involved_filter_tags', 'acquired_filter_tags', 'involved_filter_properties', 'acquired_filter_properties', 'filter_user', 'filter_types', 'card_number', 'page_identifier']
  
  def initialize(params={}, period=nil)
    @params = if params.blank?
      @params = {} 
    else
      params.is_a?(String) ? parse_str_params(params) : parse_hash_params(params)
    end
    @params.merge!(:period => period) if period
  end

  def serialize
    if str = ActionController::Routing::Route.new.build_query_string(@params)[1..-1]
      URI.unescape(str)
    end
  end

  def rename_property_name(original_name, new_name)
    rename_property_name_for_filter_property('involved_filter_properties', original_name, new_name)
    rename_property_name_for_filter_property('acquired_filter_properties', original_name, new_name)
  end

  private
  
  def rename_property_name_for_filter_property(filter_property, original_name, new_name)
    return unless @params[filter_property]
    @params[filter_property][new_name] = @params[filter_property].delete(original_name) if @params[filter_property].has_key?(original_name)
  end

  def parse_str_params(params)
    parse_hash_params(ActionController::Request.parse_query_parameters(params))
  end
  
  def parse_hash_params(params)
    params.reject! { |key, value| value.blank? }
    PARAM_KEYS.inject({}) do |result, key|
      value = params[key] || params[key.to_sym]
      value.reject_all!(PropertyValue::IGNORED_IDENTIFIER) if value.respond_to?(:reject_all!)
      result[key] = value unless value.blank?
      result
    end
  end
end

class M20101229213516HistorySubscription < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}history_subscriptions"
  
  serialize :filter_params
  before_save :hash_filter_params
  
  class << self
    def param_hash(params)
      HistoryFilterParams.new(params).serialize.to_yaml.md5
    end
  end
  
  def to_history_filter_params
    @history_filter_params ||= M20101229213516HistoryFilterParams.new(self.filter_params)
  end
  
  def rename_property(original_name, new_name)
    with_filter_params_update do |params|
      params.rename_property_name(original_name, new_name)
    end
  end
  
  protected
  
  def with_filter_params_update
    params = to_history_filter_params
    yield(params)
    self.filter_params = params.serialize
  end
  
  def hash_filter_params
    self.hashed_filter_params = self.class.param_hash(self.filter_params)
  end
end

class M20101229213516PropertyDefinition < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}property_definitions"
  self.inheritance_column = 'm_type' # disable single table inheretance

  belongs_to :project, :class_name => "M20101229213516Project", :foreign_key => "project_id"
  
  def name=(new_name)
    if name && name != new_name && record_exists?
      update_history_subscriptions_on_name_change(new_name)
      update_formula_property_definitions_on_name_change(new_name)
      
      # NOTE:
      # Due to the complexity of the embedded code of bug fix, this migration will not fix aggregate properties whose aggregate_condition references such
      # renamed properties, nor will it fix favorites whose advanced MQL that references such renamed properties.
    end
    write_attribute(:name, new_name)
  end
  
  protected
  
  def update_history_subscriptions_on_name_change(new_name)
    project.history_subscriptions.each do |subscription|
      subscription.rename_property(name, new_name)
      subscription.save!
    end
  end
  
  def update_formula_property_definitions_on_name_change(new_name)
    project.formula_property_definitions_with_hidden.each do |property_definition|
      property_definition.rename_property(name, new_name)
      property_definition.save!
    end
  end  
end

class M20101229213516Formula
  require 'racc/parser'
  require 'strscan'

  class FormulaParser < Racc::Parser

    module_eval <<'..end lib/formula_properties.grammar modeval..ide7df68603e', 'lib/formula_properties.grammar', 36

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

..end lib/formula_properties.grammar modeval..ide7df68603e

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

module_eval <<'.,.,', 'lib/formula_properties.grammar', 18
  def _reduce_1( val, _values)
 Formula.new(val[0])
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
 Formula::CardPropertyValue.new(val[0])
  end
.,.,

   def _reduce_none( val, _values)
    val[0]
   end

  end   # class FormulaParser

  class Formula
    attr_reader :formula

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
    
    def rename_property(old_name, new_name); end
    
    def to_s
      "#{@value}"
    end
  end
  
  class Formula::DatePrimitive < Formula::Primitive
    def initialize(date)
      @value = if (date.respond_to?(:value))
        date.value
      else
        date
      end
    end
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
    def initialize; end
    
    def to_s
      nil
    end
  end
  
  class Formula::CardPropertyValue < Formula
    attr_reader :invalid_properties

    def initialize(property_name)
      @property_name = property_name
      @invalid_properties = []
    end
    
    def rename_property(old_name, new_name)
      if @property_name.downcase.strip == old_name.downcase
        @property_name = new_name
      end
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
  
  class Formula::Number
  end
  
  class Formula::Date
  end
  
  class Formula::NullType
  end
  
end

class M20101229213516FormulaPropertyDefinition < M20101229213516PropertyDefinition
  def rename_property(old_name, new_name)
    formula.rename_property(old_name, new_name)
    write_attribute(:formula, formula.to_s[1..-2])
    reset_formula_cache
  end
  
  def formula
    @formula_cache ||= M20101229213516Formula::FormulaParser.new.parse(attributes['formula'])
  end
  
  def reset_formula_cache
    @formula_cache = nil
  end
end

class M20101229213516Project < ActiveRecord::Base
  set_table_name "#{ActiveRecord::Base.table_name_prefix}projects"
  cattr_accessor :current
  
  has_many :all_property_definitions, :class_name => 'M20101229213516PropertyDefinition', :order => "#{ActiveRecord::Base.table_name_prefix}property_definitions.name", :foreign_key => 'project_id'
  has_many :formula_property_definitions_with_hidden, :conditions => ["#{MigrationHelper.safe_table_name('property_definitions')}.type = ?", 'FormulaPropertyDefinition'], :class_name => 'M20101229213516FormulaPropertyDefinition', :foreign_key => "project_id"
  has_many :history_subscriptions, :class_name => 'M20101229213516HistorySubscription', :foreign_key => 'project_id'
  
  def activate
    @@current = self
  end

  def deactivate
    @@current = nil
  end

  def with_active_project
    previous_active_project = @@current
    begin
      if previous_active_project
        previous_active_project.deactivate
      end
      activate
      yield(self)
    ensure
      deactivate
      if previous_active_project
        previous_active_project.activate
      end
    end
  end
end
