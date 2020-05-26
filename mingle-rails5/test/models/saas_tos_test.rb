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

class SaasTosTest < ActiveSupport::TestCase

  def setup
    SaasTos.clear_cache!
  end

  def test_accepted_creates_saas_tos_instance_if_not_present
    SaasTos.accepted?
    assert SaasTos.first
    assert_false SaasTos.accepted?
  end

  def test_accepted_is_cached_after_first_read
    user = create(:user)
    saas_tos = nil
    Cache.expects(:put).with do |arg1, arg2|
      assert_equal 'saas_tos', arg1
      saas_tos = arg2
      assert arg2.is_a? SaasTos
    end
    SaasTos.accept(user)

    SaasTos.delete_all
    Cache.expects(:get).with('saas_tos').returns(saas_tos)
    assert SaasTos.accepted?
  end

  def test_knows_how_to_accept_saas_tos

    user_email = "#{unique_name}@email.com"
    user = create(:user, email: user_email)
    SaasTos.accept(user)
    saas_tos = SaasTos.first
    assert saas_tos
    assert saas_tos.accepted
    assert_equal user_email, saas_tos.user_email
  end
end
