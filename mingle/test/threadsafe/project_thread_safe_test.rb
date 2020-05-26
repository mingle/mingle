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

class ProjectThreadSafeTest < ActiveSupport::TestCase
  def test_activate_project
    with_first_project do |project|
      t = start_thread do
        assert_false Project.activated?
        assert_raise RuntimeError do
          Project.current
        end
      end
      t.join
      assert Project.activated?
      assert_equal project, Project.current
    end
  end

  def test_deactivate_callbacks
    deactivate_triggered = false
    with_first_project do |project|
      project.on_deactivate do
        deactivate_triggered = true
      end
      t = start_thread do
        with_new_project do |project|
        end
      end
      t.join
      assert_false deactivate_triggered
    end
    assert deactivate_triggered
  end

  def start_thread(&block)
    Thread.start do
      begin
        block.call
      ensure
        ActiveRecord::Base.clear_active_connections!
      end
    end
  end

end
