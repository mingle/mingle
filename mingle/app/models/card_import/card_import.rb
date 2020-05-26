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

module CardImport
  
  HYPHENATED_HEADERS_ERROR = "Cards were not imported. Hyphens are not allowed in header values."
  MISSING_NAMES_WARNING = "Some cards being imported do not have a card name. If you continue, Mingle will provide a generic card name."
  DUPLICATE_HEADER_ERROR = "Column headings have duplicate values, Mingle cannot import any cards."
  
  def duplicate_header
    CardImportException.new(DUPLICATE_HEADER_ERROR)
  end
  
  def no_content
    CardImportException.new("Please reread import instructions and paste data below.")
  end
  
  def invalid_card_number(card_number)
    CardImportException.new("Cards were not imported. #{card_number.bold} is not a valid card number.")
  end  
  
  def invalid_card_type_value_format(value)
    CardImportException.new("Cards were not imported. #{value.bold} is invalid card relationship value. Please use '# + card number' format")
  end
  
  def multiple_columns_marked_as(import_as)
    CardImportException.new("Multiple columns are marked as #{import_as}.")
  end  
  
  def hyphenated_headers
    CardImportException.new(HYPHENATED_HEADERS_ERROR)
  end  
  
  def duplicate_cards_numbered(card_number)
    CardImportException.new("Cards were not imported. Card with number #{card_number} is duplicated within the import.")
  end  
  
  def card_number_too_large(number)
    CardImportException.new("#{number} is too large to be used as a card number.")
  end
  
  def new_type_but_no_authorization(card_types)
    type_plural = 'type'.plural(card_types.size)
    does_plural = 'does'.plural(card_types.size)
    this_plural = 'this'.plural(card_types.size)
    CardImportException.new("Card #{type_plural} #{card_types.bold.to_sentence} #{does_plural} not exist.  Please change card types or contact your project administrator to create #{this_plural} card #{type_plural}.")
  end
  
  def fields_exceed_limit(fields)
    message = "Cards were not imported. All fields other than #{'Card Description'.bold} are limited to 255 characters. The following "
    if fields.values.flatten.length == 1
      message << 'field is'
    else
      message << 'fields are'
    end
    message << ' too long: '
    
    field_descriptions = [] 
    fields.keys.sort.each do |row|
      quoted_fields = fields[row].collect{ |field| field }
      field_descriptions << "Row #{row} (#{quoted_fields.bold.to_sentence})"
    end

    message << field_descriptions.join(', ')    

    CardImportException.new(message)
  end

  def invalid_dates_in_existing_date_property(fields)
    message = "Cards were not imported. The following date "
    if fields.values.flatten.length == 1
      message << 'value is'
    else
      message << 'values are'
    end
    message << ' not valid: '

    field_descriptions = [] 
    fields.keys.sort.each do |row|
      field_descriptions << row_text(row,fields[row])
    end
    message << field_descriptions.join(', ')

    CardImportException.new(message)
  end

  class InvalidUserError < StandardError
  end  
  
  def invalid_user_error
    CardImport::InvalidUserError.new
  end
  
  private
  
  def row_text(row, fields)
    quoted_fields = fields.collect{ |f| f.bold }
    "Row #{row} (#{quoted_fields.join(', ')})"
  end  
  
  module_function :duplicate_header,
   :no_content,
   :multiple_columns_marked_as,
   :invalid_card_number,
   :invalid_card_type_value_format,
   :hyphenated_headers, 
   :duplicate_cards_numbered, 
   :fields_exceed_limit, 
   :invalid_dates_in_existing_date_property, 
   :row_text,
   :card_number_too_large,
   :invalid_user_error,
   :new_type_but_no_authorization
end  
