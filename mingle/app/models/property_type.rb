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

module PropertyType
  module IdentifierComparator
    def equal_values?(one_value, another_value)
      return false unless another_value
      return false unless one_value.property_definition == another_value.property_definition
      one_value.db_identifier == another_value.db_identifier
    end
  end

  module ObjectComparator
    def equal_values?(one_value, another_value)
      return false unless another_value
      return false unless one_value.property_definition == another_value.property_definition
      find_object(one_value.db_identifier) == find_object(another_value.db_identifier)
    end
  end

  def has_case_problem?(property_type)
    ![CalculatedType, IntegerType, NumericType, DateType].include?(property_type.class)
  end

  def association_type?(property_type)
    [:user, :card].include?(property_type.to_sym)
  end

  def compatible?(property_type, with_property_types)
    type_list = with_property_types.map(&:to_sym)
    type_list << :integer if type_list.include?(:numeric)
    type_list << :project if type_list.include?(:string)
    type_list.include?(property_type.to_sym)
  end

  module_function :has_case_problem?, :association_type?, :compatible?

  class Base
    include IdentifierComparator
    def db_to_lane_identifier(db_identifier)
      db_to_url_identifier(db_identifier)
    end

    def format_value_for_card_query(value, cast_numeric_columns=false)
      value
    end

    def sanitize_db_identifier(identifier, property_definition)
      identifier
    end

    def reserved_identifiers
      []
    end

    def detect_existing(value, existing_values, managed=true); end

    def export_value(db_identifier)
      return unless db_identifier
      db_to_url_identifier(db_identifier)
    end

    def parse_import_value(value)
      value
    end

    def to_s
      to_sym.to_s
    end
  end

  # for StringType url_identifier, db_identifier and display_value are all the same
  class StringType < Base
    def db_to_url_identifier(db_identifier)
      db_identifier
    end

    alias_method :url_to_db_identifier, :db_to_url_identifier
    alias_method :display_value_for_db_identifier, :db_to_url_identifier
    alias_method :object_to_db_identifier, :db_to_url_identifier

    def find_object(db_identifier)
      db_identifier
    end

    def validate(value)
      []
    end

    def sort_value(property_value)
      property_value.display_value
    end

    def detect_existing(value, existing_values, managed=true)
      existing_values.detect { |enum| enum.value.upcase == value.to_s.upcase }
    end

    def make_uniq(values)
      values.inject([]) do |uniq_results, value|
        if value.blank?
          uniq_results << nil unless uniq_results.include?(nil)
          next uniq_results
        end
        uniq_results << value unless uniq_results.compact.collect(&:downcase).include?(value.downcase)
        uniq_results
      end
    end

    def to_sym
      :string
    end

  end

  class BigNumericType < StringType
    include ObjectComparator

    def detect_existing(value, existing_values, managed=true)
      return value if (existing_values.empty? || value.nil?)
      existing_value = existing_values.detect { |enum| !enum.value.nil? && BigDecimal.new(enum.value.to_s) == BigDecimal.new(value.to_s) }
      existing_value ? existing_value : value
    end

    def make_uniq(values)
      values.map do |value|
        value.blank? ? nil : BigDecimal.new(value.to_s)
      end.uniq
    end

    def to_sym
      :numeric
    end
  end

  class NumericType < StringType
    include ObjectComparator

    def initialize(project)
      @project = project
    end

    def find_object(db_identifier)
      return if db_identifier.blank?
      errors = validate(db_identifier)
      raise PropertyDefinition::InvalidValueException.new(errors.join(',')) if errors.any?
      @project.to_num_maintain_precision(db_identifier.to_s)
    end

    def object_to_db_identifier(obj)
      return nil unless obj
      obj.to_s()
    end

    def display_value_for_db_identifier(identifier)
      @project.to_num_maintain_precision(identifier)
    end

    def format_value_for_card_query(value, cast_numeric_columns=false)
      !value.blank? && cast_numeric_columns ? @project.format_num(value) : value
    end

    def validate(value)
      return [] if value.blank?
      if numeric?(value)
        max_precision = ActiveRecord::Base.connection.max_precision
        return value.to_s.to_num_maintain_precision(max_precision).size - 1 > max_precision ? ["#{value.bold} is of invalid numeric precision. Value should have numeric precision less than #{max_precision}"] : []
      end
      ["#{value.bold} is an invalid numeric value"]
    end

    def numeric?(value)
       value.respond_to?(:numeric?) && value.numeric?
    end

    def sort_value(property_value)
      property_value.display_value.to_num
    end

    def make_uniq(values)
      values.inject([]) do |uniq_results, value|
        if value.blank?
          uniq_results << nil unless uniq_results.include?(nil)
          next uniq_results
        end
        uniq_results << value if !existing_value?(value, uniq_results) && most_precise?(value, values)
        uniq_results
      end
    end

    def existing_value?(number_string, values)
      values.collect { |v| v.to_num(@project.precision) }.include?(number_string.to_num(@project.precision))
    end

    def most_precise?(number_string, values)
      (integral?(number_string) && values.grep(integer_with_trailing_zeroes(number_string)).empty?) ||
      (decimal?(number_string) && values.grep(decimal_with_trailing_zeroes(number_string)).empty?)
    end

    def integral?(number_string)
      number_string !~ /\./
    end

    def decimal?(number_string)
      number_string =~ /\./
    end

    def integer_with_trailing_zeroes(number_string)
      /^#{number_string}\.(0)+$/
    end

    def decimal_with_trailing_zeroes(number_string)
      escaped = Regexp.escape(number_string)
      /^#{escaped}(0)+$/
    end

    def detect_existing(value, existing_values, managed=true)
      if managed
        return nil if existing_values.empty? || !value.numeric?
        existing_values.detect { |enum| @project.compare_numbers(enum.value.to_num, value.to_num) }
      else
        return value if (existing_values.empty? || !value.numeric?)
        existing_value = existing_values.detect { |val| @project.compare_numbers(val.to_num, value.to_num)}
        existing_value ? existing_value : value
      end
    end

    def sanitize_db_identifier(identifier, property_definition)
      return identifier if identifier.nil? || !numeric?(identifier)
      identifier = @project.to_num_maintain_precision(identifier.to_s)

      if (property_definition.finite_valued?)
        existing_values = property_definition.values
        enum_value = detect_existing(identifier, existing_values, true)
        enum_value ? enum_value.value : identifier
      else
        identifier
      end
    end

    def to_sym
      :numeric
    end

  end

  class IntegerType < StringType
    include ObjectComparator

    def find_object(db_identifier)
      db_identifier.to_i
    end

    def to_sym
      :integer
    end
  end

  class CalculatedType < StringType

    def initialize(project, property_definition)
      @project = project
      @property_definition = property_definition
    end

    def sanitize_db_identifier(identifier, property_definition)
      return unless identifier
      get_derived_type(identifier).sanitize_db_identifier(identifier, property_definition)
    end

    def display_value_for_db_identifier(identifier)
      return unless identifier
      if identifier.to_s.numeric?
        @property_definition.to_output_format(identifier).to_s
      else
        get_derived_type(identifier).display_value_for_db_identifier(identifier)
      end
    end

    def db_to_url_identifier(identifier)
      identifier.to_s
    end

    def format_value_for_card_query(value, cast_numeric_columns=false)
      if value.to_s.numeric?
        @property_definition.to_output_format(value)
      else
        get_derived_type(value).format_value_for_card_query(value, cast_numeric_columns)
      end
    end

    def to_sym
      @property_definition.numeric? ? :numeric : :date
    end

    #todo shouldn't use property_definition to make decision what's derived type?
    def get_derived_type(identifier)
      identifier.to_s.numeric? ? NumericType.new(@project) : DateType.new(@project)
    end
  end

  class ProjectType < Base
    def object_to_db_identifier(project)
      project.id.to_s
    end

    def find_object(db_identifier)
      Project.find_by_id(db_identifier)
    end

    def db_to_url_identifier(db_identifier)
      if project = find_object(db_identifier)
        project.identifier
      end
    end

    def url_to_db_identifier(url_identifier)
      if project = ProjectCacheFacade.instance.load_project(url_identifier)
        project.id.to_s
      end
    end

    def display_value_for_db_identifier(db_identifier)
      if project = find_object(db_identifier)
        project.name
      end
    end

    def to_sym
      :project
    end
  end

  # for user type, db_identifier is user id, url_identifier is user login, display_value is user name
  class UserType < Base
    include ObjectComparator
    CURRENT_USER = '(current user)'
    ALIAS_CURRENT_USER = 'current user'

    def initialize(project)
      @team_members = project.users
    end

    def reserved_identifiers
      [CURRENT_USER]
    end

    def db_to_url_identifier(db_identifier)
      return CURRENT_USER if is_current_user?(db_identifier)
      if user = find_user_by_id(db_identifier)
        user.login
      end
    end
    memoize :db_to_url_identifier

    def url_to_db_identifier(url_identifier)
      return User.current.id if is_current_user?(url_identifier)

      user = find_user_by_login_or_id(url_identifier)
      user.id if user
    end

    def valid_url?(url_identifier)
      return true if url_identifier.blank?
      url_to_db_identifier(url_identifier)
    end

    def display_value_for_db_identifier(db_identifier)
      return CURRENT_USER if is_current_user?(db_identifier)
      if user = find_object(db_identifier)
        user.name
      end
    end

    def format_value_for_card_query(value, cast_numeric_columns=false)
      if user = find_user_by_login_or_id(value)
        user.name_and_login
      end
    end

    def sort_value(property_value)
      display_value_for_db_identifier(property_value.db_identifier)
    end

    def is_current_user?(db_identifier)
      return false unless db_identifier.respond_to?(:downcase)
      [CURRENT_USER, ALIAS_CURRENT_USER].include?(db_identifier.downcase)
    end

    def object_to_db_identifier(obj)
      return nil unless obj
      obj.id.to_s
    end

    def parse_import_value(value)
      if mingle_user = User.find_by_login(value)
        mingle_user.id.to_s
      else
        raise CardImport.invalid_user_error
      end
    end

    def find_object(db_identifier)
      return User.current if db_identifier && is_current_user?(db_identifier.to_s)
      find_user_by_id(db_identifier)
    end

    def to_sym
      :user
    end

    private
    def find_user_by_id(db_identifier)
      return nil unless db_identifier

      if user = cached_users[db_identifier.to_i]
        return user
      elsif user = User.find_by_id(db_identifier.to_i)
        cached_users[user.id] = user
        return user
      else
        raise PropertyDefinition::InvalidValueException.new(" #{db_identifier.to_s.bold} is not a valid user")
      end
    end

    memoize :find_user_by_id

    def find_user_by_login_or_id(login_or_id)
      return nil unless login_or_id

      if user = cached_users[login_or_id]
        return user
      end

      if user = User.find_by_login(login_or_id)
        cached_users[user.id] = user
        cached_users[user.login] = user
        return user
      end

      find_user_by_id(login_or_id)
    end

    def cached_users
      @__cached_users ||= Hash[@team_members.to_a.map{|m| [[m.id, m], [m.login, m]]}.flatten(1)]
    end

  end

  # for date type, url_identifier is same with display_identifier (date with formate), db_idenitfier is
  # date formatted in database formate yyyy-mm-dd
  class DateType < Base
    include ObjectComparator

    TODAY = '(today)'
    PROJECT_TODAY = 'today'

    class << self
      def error(project, cell)
        return cell if cell.blank? || cell == TODAY || cell == PROJECT_TODAY
        Date.parse_with_hint(cell, project.date_format).strftime(project.date_format) rescue "Error: #{cell}"
      end
    end

    def initialize(project)
      @project = project
    end

    def reserved_identifiers
      [TODAY, PROJECT_TODAY]
    end

    def is_today?(value)
      reserved_identifiers.include?(value.downcase)
    end

    def sanitize_db_identifier(identifier, property_definition)
      return unless identifier
      find_object(identifier).to_formatted_s(:db) rescue identifier
    end

    def db_to_url_identifier(db_identifier)
      return TODAY if db_identifier == TODAY
      format(find_object(db_identifier))
    end

    def url_to_db_identifier(url_identifier)
      if date = find_object(url_identifier)
        date.to_formatted_s(:db)
      end
    end

    def object_to_db_identifier(obj)
      return nil unless obj
      obj.to_formatted_s(:db)
    end

    def format_value_for_card_query(url_identifier, cast_numeric_columns=false)
      format(find_object(url_identifier))
    end

    alias_method :display_value_for_db_identifier, :db_to_url_identifier

    def display_value_for_url_identifier(url_identifier)
      url_identifier
    end

    def sort_value(property_value)
      find_object(property_value.display_value)
    end

    def find_object(date_str)
      return nil if date_str.blank?
      return date_str if date_str.is_a?(Date)
      return date_str.to_date if date_str.is_a?(Time)
      begin
        project_today_identifiers?(date_str) ? @project.today : Date.parse_with_hint(date_str, @project.date_format)
      rescue ArgumentError
        raise PropertyDefinition::InvalidValueException.new(validation_error_message(date_str))
      end
    end
    memoize :find_object

    def project_today_identifiers?(date_str)
      return false if !date_str.respond_to?(:downcase)
      date_str.downcase == TODAY || date_str.downcase == PROJECT_TODAY
    end

    def validation_error_message(value)
      "#{value.bold} is an invalid date. Enter dates in #{@project.humanize_date_format.bold} format or enter existing project variable which is available for this property."
    end

    def format(date)
      return unless date
      date.strftime(@project.date_format)
    end

    def to_sym
      :date
    end
  end

  class CardType < Base
    def initialize(project)
      @project = project
    end

    def db_to_url_identifier(db_identifier)
      return unless db_identifier
      @project.card_id_to_number(db_identifier)
    end

    def db_to_lane_identifier(db_identifier)
      return unless db_identifier
      @project.card_id_to_number(db_identifier)
    end

    def url_to_db_identifier(url_identifier)
      return unless url_identifier
      id = @project.card_number_to_id(url_identifier) rescue nil
      raise PropertyDefinition::InvalidValueException unless id
      id.to_s
    end

    def display_value_for_db_identifier(db_identifier)
      return if db_identifier.blank?
      get_display_value_from("##{@project.card_id_to_number(db_identifier)} #{@project.card_id_to_name(db_identifier)}")
    end

    def object_to_db_identifier(obj)
      return unless obj
      obj.id.to_s
    end

    def sort_value(property_value)
      find_object(property_value.db_identifier).number
    end

    def export_value(db_identifier)
      return unless db_identifier
      card = find_object(db_identifier)
      card.number_and_name
    end

    def parse_import_value(value)
     return if value.blank?
     value = value.strip
     if value =~ /^#(\d+)/
       if card = @project.cards.find_by_number($1)
         card.id.to_s
       else
         raise CardImport.invalid_card_number($1)
       end
     else
       raise CardImport.invalid_card_type_value_format(value);
     end
    end

    def find_object(db_identifier)
      return if db_identifier.blank?
      begin
        @project.cards.find_existing_or_deleted_card(db_identifier)
      rescue ActiveRecord::RecordNotFound => e
        raise PropertyDefinition::InvalidValueException, "Card properties can only be updated with ids of existing cards: #{e.message}"
      end
    end

    def valid_url?(url_identifier)
      return true if url_identifier.blank?
      url_to_db_identifier(url_identifier)
    end

    def to_sym
      :card
    end

    private

    def get_display_value_from(value)
      value.to_s.gsub(/#/, '').strip.blank? ? 'deleted card' : value
    end
  end

  class BooleanType < StringType
    def export_value(db_identifier)
      db_identifier ? 'yes' : 'no'
    end

    def parse_import_value(value)
      ['yes', 'true'].ignore_case_include?(value)
    end

    def to_sym
      :boolean
    end
  end

  class TreeBelongingType < StringType
    def display_value_for_db_identifier(db_identifier)
      TreeBelongingPropertyDefinition::TEXT_AND_VALUES[db_identifier]
    end

    def sort_value(property_value)
      display_value_for_db_identifier(property_value.db_identifier)
    end
  end
end
