#encoding: UTF-8

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


require File.expand_path(File.dirname(__FILE__) + '/../unit_test_helper')

class MultiByteSupportTest < ActiveSupport::TestCase
      
  def test_basic_card_support
    chinese_word = '中文'
    User.with_first_admin do
      with_first_project do |project|
        card = project.cards.create!(:name => chinese_word, :description => chinese_word, 
          :card_type_name => 'Card', :cp_status => chinese_word)
        card.reload
        assert_equal chinese_word, card.name
        assert_equal chinese_word, card.description
        assert_equal chinese_word, card.cp_status
      end
    end
  end
  
  # this is currently required by CardQuery 
  def test_alias_is_record_key
    with_first_project do |project|
      quoted = Project.connection.quote_column_name('专题')
      sql = "SELECT identifier as #{quoted} FROM #{Project.table_name} WHERE type = 'Project'"
      records = Project.connection.select_all(sql)
      assert_equal records.size, Project.count
      records.each do |record|
        record.keys.each do |key|
          assert_equal '专题', key
        end
      end
    end
  end  

end
