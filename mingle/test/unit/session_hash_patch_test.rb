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

class SessionHashStringifyKeysPatchTest < ActiveSupport::TestCase
  def setup
    session = {'login' => 'login name'}
    session_provider = OpenStruct.new.mock_methods load_session: ['session_id', session], exists?: true
    @session_hash = ActionController::Session::AbstractStore::SessionHash.new(session_provider, {'rack.session.options' => {}})
  end

  test 'should_return_for_both_string_and_symbol_keys_when_session_values_are_set_using_string_key' do
    assert_equal('login name', @session_hash[:login])
    assert_equal('login name', @session_hash['login'])

    @session_hash['_csrf'] = 'csrf token value'

    assert_equal('csrf token value', @session_hash[:_csrf])
    assert_equal('csrf token value', @session_hash['_csrf'])
  end

  test 'should_return_for_both_string_and_symbol_keys_when_session_values_are_set_using_symbol_key' do
    @session_hash[:csrf] = 'csrf token value'

    assert_equal('csrf token value', @session_hash[:csrf])
    assert_equal('csrf token value', @session_hash['csrf'])
  end
end
