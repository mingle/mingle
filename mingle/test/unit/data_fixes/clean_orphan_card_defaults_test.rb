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

require File.expand_path(File.dirname(__FILE__) + '/../../unit_test_helper')

class CleanOrphanCardDefaultsTest < ActiveSupport::TestCase

  def setup
    login_as_admin
    @project = create_project
    @project.activate
  end

  def test_applying_fix_will_create_missing_login_access_record
    story = @project.card_types.create(:name => 'story')
    bug = @project.card_types.create(:name => 'bug')
    sd = @project.card_defaults.create(:card_type => story, :description => 'foo');
    assert_false DataFixes::CleanOrphanCardDefaults.required?
    bd = @project.card_defaults.create(:card_type_id => 10000, :description => 'bar')
    assert DataFixes::CleanOrphanCardDefaults.required?
    DataFixes::CleanOrphanCardDefaults.apply
    assert_false DataFixes::CleanOrphanCardDefaults.required?
    assert_nil CardDefaults.find_by_id(bd.id)
    assert_not_nil CardDefaults.find_by_id(sd.id)
  end

end
