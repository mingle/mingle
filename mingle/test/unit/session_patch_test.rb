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

class SessionMarshallingPatchesTest < ActiveSupport::TestCase
  test 'marshal_should_return_nil_when_data_not_present' do
    assert_nil(ActiveRecord::SessionStore::Session.marshal(nil))
  end

  test 'marshal_should_serialize_session_as_json' do
    flash = ActionController::Flash::FlashHash.new
    flash[:notice] = 'notice blah'
    flash[:error] = 'error blah'
    flash[:discard] = 'discard blah'
    session_json = ActiveRecord::SessionStore::Session.marshal({login: 'login name', flash: flash})

    assert_equal('{"value":{"login":"login name","flash":{"notice":"notice blah","error":"error blah","discard":"discard blah"}}}', session_json)
  end

  test 'unmarshal_should_return_nil_when_data_not_present' do
    assert_nil(ActiveRecord::SessionStore::Session.unmarshal(nil))
  end

  test 'unmarshal_should_deserialize_marshaled_data' do
    flash = ActionController::Flash::FlashHash.new
    flash[:notice] = 'notice blah'
    flash[:error] = 'error blah'
    flash[:discard] = 'discard blah'
    session = {login: 'login info', flash: flash}
    marshaled_data = Base64::encode64(Marshal.dump(session))
    deserialized_data = ActiveRecord::SessionStore::Session.unmarshal(marshaled_data)

    assert_equal(session, deserialized_data)
  end

  test 'unmarshal_should_deserialize_json_data' do
    expected_session_data = {'login' => 'login name', 'flash' => {'notice' => 'notice blah', 'error' => 'error blah', 'discard' => 'discard blah'}}
    json_data =  '{"value":{"login":"login name","flash":{"notice":"notice blah","error":"error blah","discard":"discard blah"}}}'
    deserialized_data = ActiveRecord::SessionStore::Session.unmarshal(json_data)

    assert_equal(expected_session_data, deserialized_data)
  end
end
