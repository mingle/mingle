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

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class DeleteOrphanUsersTest < ActiveSupport::TestCase

  def setup
    @admin = create(:admin, login: :admin, admin: true)
    login_as_admin
    @user1, @user2, @user3 = [create(:user, login: :user1), create(:user, login: :user2), create(:user, login: :user3)]
  end


  def test_should_not_delete_user_if_user_has_created_objective
    program = create(:program)
    program.add_member(@user1)
    program.add_member(@user2)
    login @user1.email
    program.objectives.planned.create(:name => 'first', :start_at => '2011-1-1', :end_at => '2011-2-1')

    login_as_admin

    assert User.has_ever_created_or_edited_objectives.include?(@user1.id)
    assert !User.has_ever_created_or_edited_objectives.include?(@user2.id)
  end

  def test_should_not_delete_user_if_user_has_modified_objective
    program = create(:program)
    program.add_member(@user1)
    objective = program.objectives.planned.create(:name => 'first', :start_at => '2011-1-1', :end_at => '2011-2-1')
    login @user1.email
    objective.update_attributes(:name => 'changed_name')

    login_as_admin

    assert User.has_ever_created_or_edited_objectives.include?(@user1.id)
    assert !User.has_ever_created_or_edited_objectives.include?(@user2.id)
    assert !User.has_ever_created_or_edited_objectives.include?(@user3.id)
  end

end
