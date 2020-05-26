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

class ActionControllerBaseFlashPatchTest < ActiveSupport::TestCase

  def setup
    @controller = ActionController::Base.new
    @controller.session = {}
  end

  test 'should_return_new_flash_hash_back_when_session_flash_not_present' do
    assert_instance_of(ActionController::Flash::FlashHash, @controller.flash)
    assert_equal({}, @controller.flash)
  end

  test 'should_return_flash_hash_back_when_session_flash_is_flash_hash' do
    flash_hash = ActionController::Flash::FlashHash.new
    flash_hash[:notice] = 'notice flash message'
    @controller.session['flash'] = flash_hash

    assert_same(flash_hash, @controller.flash)
  end

  test 'should_return_flash_hash_with_flashes_and_discard_messages_marked_discard_when_session_flash_is_hash' do
    flashes = {'notice' => 'notice flash message', 'discarded' => 'discard'}
    @controller.session['flash'] = {'flashes' => flashes, 'discard' => ['discarded']}

    assert_equal(flashes.slice('notice'), @controller.flash)
    assert_nil( @controller.flash[:discarded])
  end
end

class FlashHashJSONPatchesTest < ActiveSupport::TestCase

  def setup
    @flash = ActionController::Flash::FlashHash.new
  end

  test 'should_return_message_for_symbol_and_string_key_when_message_was_created_using_symbol' do
    msg = 'notice flash message'
    @flash[:notice] = msg

    assert_equal(msg, @flash[:notice])
    assert_equal(msg, @flash['notice'])
  end

  test 'should_return_message_for_string_and_symbol_keys_when_message_was_created_using_string' do
    msg = 'notice flash message'
    @flash['notice'] = msg

    assert_equal(msg, @flash[:notice])
    assert_equal(msg, @flash['notice'])
  end

  test 'store_should_store_flash_hash_as_hash_of_flashes_and_discard_keys' do
    discard_key = 'to_be_discarded'
    flashes = {'notice' => 'flash notice message', discard_key => 'discarded message'}
    @flash.update(flashes)
    @flash.discard(discard_key)
    session = {}

    stored_flash = @flash.store(session)

    assert_equal(flashes, stored_flash[:flashes])
    assert_equal([discard_key], stored_flash[:discard])
    assert_equal({flashes: flashes, discard: [discard_key], html_safe: []}, session['flash'])
  end

  test 'should_overwrite_existing_symbolic_key_when_adding_using_string_key' do
    @flash.update( notice: 'flash notice')

    assert_equal('flash notice', @flash[:notice])

    @flash['notice'] = 'updated notice'

    assert_equal('updated notice', @flash[:notice])
  end

  test 'should_save_html_safe_content_keys_in_html_safe_values' do
    @flash[:notice] = 'hello <br> world <br>'.html_safe
    session = {}

    @flash.store(session)

    assert_equal({flashes: {'notice' => 'hello <br> world <br>'}, discard: [], html_safe: ['notice']}, session['flash'])
  end

  test 'from_session_value_should_convert_html_safe_values_to_safe_buffer' do
    flash = ActionController::Flash::FlashHash.from_session_value({flashes: {'notice' => 'hello <br> world <br>'}, discard: [], html_safe: ['notice']})

    assert_equal('hello <br> world <br>', flash[:notice])
    assert_instance_of(ActiveSupport::SafeBuffer, flash[:notice])
  end
end
