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

# require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')
# require File.dirname(__FILE__) + '/073_create_card_defaults.rb'
# 
# class Migration73Test < ActiveSupport::TestCase
#   
#   def tear_down
#     @project.deactivate
#   end
#   
#   def test_migration_after_import_works
#     @project = first_project
#     table_name = "#{ActiveRecord::Base.table_name_prefix}#{@project.identifier}_card_defaults"
#     assert !@project.connection.table_exists?(table_name)
#     CreateCardDefaults.up
#     assert @project.connection.table_exists?(table_name)
#     CreateCardDefaults.up
#     assert @project.connection.table_exists?(table_name)
#   end
#   
#   def test_migration_creates_blank_card_defaults
#     @project = first_project
#     CreateCardDefaults.up
#     @project.activate
#     @project.connection.execute("DELETE FROM #{CardDefaults.table_name}")
#     
#     CreateCardDefaults.up
#     
#     @project.activate
#     @project.card_types.each do |card_type|
#       assert !card_type.card_defaults.nil?
#     end
#   end
#   
#   def test_adds_template_table_for_existing_projects
#     @project = first_project
#     table_name = "#{ActiveRecord::Base.table_name_prefix}#{@project.identifier}_card_defaults"
#     assert !@project.connection.table_exists?(table_name)
#     CreateCardDefaults.up
#     assert @project.connection.table_exists?(table_name)
#   end
#   
#   def test_adds_custom_property_def_columns_to_templates_tables
#     @project = first_project
# 
#     table_name = "#{ActiveRecord::Base.table_name_prefix}#{@project.identifier}_card_defaults"
#     assert !@project.connection.table_exists?(table_name)
#     CreateCardDefaults.up
# 
#     @project.activate
#     
#     status = CardDefaults.columns.detect {|column| column.name == 'cp_status'}
#     assert 'String', status.klass
#     dev = CardDefaults.columns.detect {|column| column.name == 'cp_dev_user_id'}
#     assert !dev.nil?
#     assert 'Integer', dev.klass
#     status = CardDefaults.columns.detect {|column| column.name == 'cp_start_date'}
#     assert 'Date', status.klass
#   end
#   
#   def test_create_card_type_records
#     @project = first_project
#     
#     table_name = "#{ActiveRecord::Base.table_name_prefix}#{@project.identifier}_card_defaults"
#     CreateCardDefaults.up
#     @project.activate
#     @project.card_types.each do |card_type|
#       assert !card_type.card_defaults.nil?
#     end
#   end
#   
#   def test_down_removes_card_defaults_table
#     @project = first_project
#     table_name = "#{ActiveRecord::Base.table_name_prefix}#{@project.identifier}_card_defaults"
#     assert !@project.connection.table_exists?(table_name)
#     CreateCardDefaults.up
#     assert @project.connection.table_exists?(table_name)
#     CreateCardDefaults.down
#     assert !@project.connection.table_exists?(table_name)
#   end
# end
