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

class ProjectWithoutTransactionTest < ActiveSupport::TestCase
  self.use_transactional_fixtures = false
  
  def test_should_update_card_table_index_after_renamed_project_identifier
    login_as_admin
    with_new_project do |project|
      @old_identifier = project.identifier
      project.update_attribute(:identifier, @old_identifier[0..-2])
      create_project :identifier => @old_identifier
    end
  end
end
