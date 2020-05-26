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

class FixEncodingOnCardListViewParams < ActiveRecord::Migration[5.0]
  def self.up
    CardListView.pluck(:id, :params).each do |(id, params)|
      begin
        encoded_params = params.force_utf8_encoding
        execute SqlHelper.sanitize_sql("UPDATE #{CardListView.quoted_table_name} SET #{quote_column_name('params')} = ? WHERE #{quote_column_name('id')} = ?", encoded_params, id)
      rescue Exception => e
        Rails.logger.error("Failed to update params of card_list_view: id:#{id}, params:#{params} with error: #{e.message}")
      end
    end
  end

  def self.down
  end
end
