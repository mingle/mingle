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

class MigrateEditorStyleToRedclothFlagInCardsTables < ActiveRecord::Migration
  def self.all_card_tables
    [safe_table_name('cards'),safe_table_name('card_versions')].tap do |tables|
      results = ActiveRecord::Base.connection.select_all "SELECT cards_table, card_versions_table FROM #{safe_table_name('deliverables')} WHERE type='Project';"
      tables << results.collect(&:values)
    end.flatten.map { |fully_qualified_table_name| fully_qualified_table_name.gsub(/^mi_\d{6}_/, '') }
  end

  def self.up
    all_card_tables.each do |card_table|
      # if we're upgrading a program export, there are no cards tables
      if table_exists?(card_table) && !column_exists?(card_table, 'redcloth')
        add_column card_table, :redcloth, :boolean
        execute(sanitize_sql("UPDATE #{safe_table_name(card_table)} SET redcloth = ? where editor_style is NULL or editor_style != 'WYSIWYG'", true))
        execute(sanitize_sql("UPDATE #{safe_table_name(card_table)} SET redcloth = ? where editor_style = 'WYSIWYG'", false))
        remove_column(card_table, :editor_style)
      end
    end
  end

  def self.down
    all_card_tables.each do |card_table|
      if table_exists?(card_table)
        add_column(card_table, :editor_style, :string)
        execute(sanitize_sql("UPDATE #{safe_table_name(card_table)} SET editor_style = 'WYSIWYG' where redcloth = ? or redcloth is NULL", false))
        execute(sanitize_sql("UPDATE #{safe_table_name(card_table)} SET editor_style = NULL where redcloth = ?", true))
        remove_column(card_table, :redcloth)
      end
    end
  end
end
