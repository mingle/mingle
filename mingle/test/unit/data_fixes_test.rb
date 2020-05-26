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

class DataFixesTest < ActiveSupport::TestCase
  self.use_transactional_fixtures = false

  def setup
    DataFixes.reset
  end

  def test_should_apply_the_fix_only_when_fix_is_required
    fix = FlexibleDataFix.new("name" => 'fix', "required" => false)
    register_and_apply(fix)
    assert_false fix.applied?
  end

  def test_should_apply_required_fixes
    fix = FlexibleDataFix.new("name" => 'fix', "required" => true)
    register_and_apply(fix)
    assert fix.applied?
  end

  def test_list_registered_fixes
    DataFixes.register(FlexibleDataFix.new("name" => 'fix1',
                                           "required" => false,
                                           "description" => 'desc1'))
    DataFixes.register(FlexibleDataFix.new("name" => 'fix2',
                                           "description" => 'desc2'))
    assert_include({'name' => 'fix1', 'description' => 'desc1', 'project_ids' => [], 'queued' => false}, DataFixes.list)
    assert_include({'name' => 'fix2', 'description' => 'desc2', 'project_ids' => [], 'queued' => false}, DataFixes.list)
  end

  def test_should_rollback_the_fix_if_application_failed
    fix = FlexibleDataFix.new("name" => 'bad_fix', "required" => true) do
      create_user!(:login => 'fool')
      raise 'boom'
    end
    assert_raise(RuntimeError) { register_and_apply(fix) }
    assert_nil User.find_by_login('fool')
  end

  private
  def register_and_apply(fix)
    DataFixes.register(fix)
    DataFixes.apply(fix.attrs)
  end

end
