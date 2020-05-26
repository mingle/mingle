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

class SystemUserTest < ActiveSupport::TestCase

  def setup
    User.find(:all).each(&:destroy_without_callbacks)
  end

  def test_ensure_system_user_creates_a_system_user_if_configured
    requires_jruby do
      begin
        java.lang.System.setProperty('mingle.systemUser', 'mysecretuser@email.com')
        java.lang.System.setProperty('mingle.systemUserPassword', 'pass1!')

        SystemUser.ensure_exists

        user = User.authenticate('mysecretuser@email.com', 'pass1!')
        assert_not_nil user
        assert user.system
        assert user.activated
        assert_equal "mysecretuser@email.com", user.email
      ensure
        java.lang.System.clearProperty('mingle.systemUser')
        java.lang.System.clearProperty('mingle.systemUserPassword')
      end
    end
  end

  def test_ensure_system_user_does_nothing_if_not_configured
    assert_no_difference "User.count_by_sql(#{SqlHelper.sanitize_sql('select * from users where system = ?', true).inspect})" do
      SystemUser.ensure_exists

    end
  end

  def test_ensure_system_user_creates_a_system_user_if_configured
    requires_jruby do
      begin
        java.lang.System.setProperty('mingle.systemUser', 'mysecretuser@email.com')
        java.lang.System.setProperty('mingle.systemUserPassword', 'pass1!')

        SystemUser.ensure_exists

        user = User.authenticate('mysecretuser@email.com', 'pass1!')
        assert_not_nil user
        assert user.system
        assert user.activated
        assert_equal "mysecretuser@email.com", user.email
      ensure
        java.lang.System.clearProperty('mingle.systemUser')
        java.lang.System.clearProperty('mingle.systemUserPassword')
      end
    end
  end

  def test_ensure_system_user_does_not_attempt_to_recreate_configured_user
    requires_jruby do
      begin
        java.lang.System.setProperty('mingle.systemUser', 'mysecretuser@email.com')

        SystemUser.ensure_exists
        SystemUser.ensure_exists

        user = User.find_by_login 'mysecretuser@email.com'
        assert_not_nil user
        assert user.system
        assert user.activated
        assert user.admin?
        assert_equal "mysecretuser@email.com", user.email
      ensure
        java.lang.System.clearProperty('mingle.systemUser')
      end
    end
  end

  def test_ensure_system_user_but_the_email_has_been_taken
    requires_jruby do
      create_user!(:login => 'xli', :email => 'x@email.com')
      begin
        java.lang.System.setProperty('mingle.systemUser', 'x@email.com')

        SystemUser.ensure_exists

        user = User.find_by_login 'x@email.com'
        assert_not_nil user
        assert user.system
        assert user.activated
        assert user.admin?
        assert_equal "x@email.com", user.email
      ensure
        java.lang.System.clearProperty('mingle.systemUser')
      end
    end
  end
end
