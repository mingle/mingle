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
require File.expand_path(File.dirname(__FILE__) + '/messaging_test_helper')


class FixOrphanPropertyChangesTest < ActiveSupport::TestCase
  include MigrationHelper
  include MessagingTestHelper


  def setup
    login_as_member
    @project = create_project
    @project.activate
  end

  def test_applying_fix_will_repair_all_orphan_changes
    assert_false DataFixes::FixOrphanPropertyChanges.required?

    property = setup_text_property_definition('some')
    setup_text_property_definition('status')

    card1 = create_card! :name => "one"
    card1.cp_some = "hello"
    card1.cp_status = 'ok'
    card1.save!

    card2 = create_card! :name => "two"
    card2.cp_some = "hola"
    card2.save!

    @project.events.map(&:generate_changes)

    assert_false DataFixes::FixOrphanPropertyChanges.required?

    ActiveRecord::Base.connection.execute(<<-SQL)
DELETE FROM #{ safe_table_name('property_definitions') }
WHERE #{quote_column_name('id')} = #{property.id}
SQL

    assert DataFixes::FixOrphanPropertyChanges.required?

    another_project = with_new_project do |project|
      setup_text_property_definition('some')
    end

    assert DataFixes::FixOrphanPropertyChanges.required?

    DataFixes::FixOrphanPropertyChanges.apply

    HistoryGeneration.run_once

    assert_false DataFixes::FixOrphanPropertyChanges.required?

    changes = @project.events.map(&:changes).flatten
    assert_equal 1, changes.select { |c| c.field == 'status' }.size
  end

end
