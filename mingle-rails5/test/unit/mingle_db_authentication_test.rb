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

require File.expand_path(File.dirname(__FILE__) + '/../test_helper')

# Tags: user, authenticator
class MingleDBAuthenticationTest < ActiveSupport::TestCase
  def setup
    @auth = MingleDBAuthentication.new
  end

  def test_login_by_email
    create(:user, email: 'first@email.com', login: 'first')
    assert @auth.authenticate?({user: {login: 'first@email.com', password: MINGLE_TEST_DEFAULT_PASSWORD}}, nil)
    assert @auth.authenticate?({user: {login: 'first', password: MINGLE_TEST_DEFAULT_PASSWORD}}, nil)
  end

  def test_login_by_email_should_be_case_insensitive
    create(:user, email: 'CAP.name@email.com')
    assert @auth.authenticate?({user: {login: 'cap.name@email.com', password: MINGLE_TEST_DEFAULT_PASSWORD}}, nil)
  end

  def test_should_try_user_login_first_before_try_email
    create(:user, email: 'ABC@email.com')
    create(:user, login: 'Abc@email.com', email: 'foo@email.com')
    user = @auth.authenticate?({user: {login: 'aBC@email.com', password: MINGLE_TEST_DEFAULT_PASSWORD}}, nil)
    assert user
    assert_equal 'abc@email.com', user.login
  end
end
