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

# DO NOT MODIFY THIS FILE, IT IS GENEREATED FROM card_attribute_methods.rake
class Card
  module DefaultAttributeMethods
    def name; missing_attribute('name', caller) unless @attributes.has_key?('name'); @attributes['name']; end
    def name=(new_value);write_attribute('name', new_value);end
    def name?; query_attribute('name'); end
    def number; missing_attribute('number', caller) unless @attributes.has_key?('number'); (v=@attributes['number']) && (v.to_i rescue v ? 1 : 0); end
    def number=(new_value);write_attribute('number', new_value);end
    def number?; query_attribute('number'); end
    def has_macros; missing_attribute('has_macros', caller) unless @attributes.has_key?('has_macros'); (v=@attributes['has_macros']) && ActiveRecord::ConnectionAdapters::Column.value_to_boolean(v); end
    def has_macros=(new_value);write_attribute('has_macros', new_value);end
    def has_macros?; query_attribute('has_macros'); end
    def card_type_name?; query_attribute('card_type_name'); end
    def created_at; @attributes_cache['created_at'] ||= (missing_attribute('created_at', caller) unless @attributes.has_key?('created_at'); (v=@attributes['created_at']) && ActiveRecord::ConnectionAdapters::Column.string_to_time(v)); end
    def created_at=(new_value);write_attribute('created_at', new_value);end
    def created_at?; query_attribute('created_at'); end
    def modified_by_user_id; missing_attribute('modified_by_user_id', caller) unless @attributes.has_key?('modified_by_user_id'); (v=@attributes['modified_by_user_id']) && (v.to_i rescue v ? 1 : 0); end
    def modified_by_user_id=(new_value);write_attribute('modified_by_user_id', new_value);end
    def modified_by_user_id?; query_attribute('modified_by_user_id'); end
    def project_card_rank; missing_attribute('project_card_rank', caller) unless @attributes.has_key?('project_card_rank'); BigDecimal.new(@attributes['project_card_rank'].to_s); end
    def project_card_rank=(new_value);write_attribute('project_card_rank', new_value);end
    def project_card_rank?; query_attribute('project_card_rank'); end
    def updated_at; @attributes_cache['updated_at'] ||= (missing_attribute('updated_at', caller) unless @attributes.has_key?('updated_at'); (v=@attributes['updated_at']) && ActiveRecord::ConnectionAdapters::Column.string_to_time(v)); end
    def updated_at=(new_value);write_attribute('updated_at', new_value);end
    def updated_at?; query_attribute('updated_at'); end
    def project_id; missing_attribute('project_id', caller) unless @attributes.has_key?('project_id'); (v=@attributes['project_id']) && (v.to_i rescue v ? 1 : 0); end
    def project_id=(new_value);write_attribute('project_id', new_value);end
    def project_id?; query_attribute('project_id'); end
    def caching_stamp; missing_attribute('caching_stamp', caller) unless @attributes.has_key?('caching_stamp'); (v=@attributes['caching_stamp']) && (v.to_i rescue v ? 1 : 0); end
    def caching_stamp=(new_value);write_attribute('caching_stamp', new_value);end
    def caching_stamp?; query_attribute('caching_stamp'); end
    def version; missing_attribute('version', caller) unless @attributes.has_key?('version'); (v=@attributes['version']) && (v.to_i rescue v ? 1 : 0); end
    def version=(new_value);write_attribute('version', new_value);end
    def version?; query_attribute('version'); end
    def created_by_user_id; missing_attribute('created_by_user_id', caller) unless @attributes.has_key?('created_by_user_id'); (v=@attributes['created_by_user_id']) && (v.to_i rescue v ? 1 : 0); end
    def created_by_user_id=(new_value);write_attribute('created_by_user_id', new_value);end
    def created_by_user_id?; query_attribute('created_by_user_id'); end
    def description; missing_attribute('description', caller) unless @attributes.has_key?('description'); @attributes['description']; end
    def description?; query_attribute('description'); end
    def id; (v=@attributes['id']) && (v.to_i rescue v ? 1 : 0); end
  end
end
