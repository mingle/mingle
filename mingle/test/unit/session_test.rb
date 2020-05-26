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

class SessionTest < ActiveSupport::TestCase

  def test_should_not_find_expired_session_by_session_id
    with_session_expires(1.second) do
      @session = Session.create(:session_id => '123', :data => 'xxx')
      sleep(2)
      assert_nil Session.find_by_session_id(@session.session_id)
    end
  end

  def test_load_session_in_jruby
    @session = Session.create(:session_id => '123', :data => 'xxx')
    @found = Session.find_by_session_id(@session.session_id)
    assert_equal @session, @found
    assert_equal @session.data, @found.data
    assert_equal @session.updated_at.class, @found.updated_at.class
    assert_equal @session.updated_at.to_s, @found.updated_at.to_s
    assert_equal @session.session_id, @found.session_id
  end

  def test_clean_expired_sessions
    with_session_expires 1.second do
      @session = Session.create(:session_id => '123', :data => 'xxx')
      sleep(2)
      Session.clean_expired_sessions
      assert_record_deleted @session
    end
  end

  def test_default_session_expires
    assert_equal 1.week, Session.expires
  end

  def test_should_be_invalid_when_session_id_is_blank
    assert_false Session.new.valid?
    assert_false Session.new(:session_id => '').valid?
  end

  def with_session_expires(timeout)
    default_expires = Session.expires
    Session.expires = timeout
    yield
  ensure
    Session.expires = default_expires
  end

end
