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

require_relative '../test_helper'

class ProfileServerUserSyncTest < ActiveSupport::TestCase

  def setup
    @user = create(:user)
  end

  def test_should_not_call_profile_server_when_not_configured
    ProfileServer.expects(:sync_user).never
    ProfileServerUserSync.perform(@user)

    ProfileServer.expects(:delete_user).never
    ProfileServerUserSync.perform(@user, :delete)
  end

  def test_should_not_call_profile_server_when_active_record_table_name_prefix
    ActiveRecord::Base.table_name_prefix = 'mi_foo'
    ProfileServer.configure({url: 'https://profile_server'}, HttpStub.new)

    ProfileServer.expects(:sync_user).never
    ProfileServerUserSync.perform(@user)

    ProfileServer.expects(:delete_user).never
    ProfileServerUserSync.perform(@user, :delete)
  end

  def test_should_call_profile_server_when_configured_and_no_table_prefix
    ProfileServer.configure({url: 'https://profile_server'}, HttpStub.new)
    ProfileServer.expects(:sync_user).with(@user).once
    ProfileServerUserSync.perform(@user)

    ProfileServer.expects(:delete_user).with(@user).once
    ProfileServerUserSync.perform(@user, :delete)
  end

  def teardown
    ProfileServer.reset
    ActiveRecord::Base.table_name_prefix = ''
  end
end
