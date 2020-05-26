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

class MingleCipherTest < ActiveSupport::TestCase

  def test_should_encrypt_plain_text
    mingle_cipher = MingleCipher.new(Base64.decode64('kkCSxzaucrCTn0GK/MEH7Q=='))

    actual_encrypted_bytes = mingle_cipher.encrypt('plainText')
    actual_encrypted_bytes_as_string = java.util.Arrays.toString(actual_encrypted_bytes)

    expected_encrypted_bytes = [36, -69, 12, 122, 63, -69, 5, -99, 116, -113, 72, -126, 80, -96, -49, 36]
    expected_encrypted_bytes_as_string = expected_encrypted_bytes.inspect

    assert_equal(expected_encrypted_bytes_as_string, actual_encrypted_bytes_as_string)
  end

  def test_should_decrypt_encrypted_text
    mingle_cipher = MingleCipher.new(Base64.decode64('kkCSxzaucrCTn0GK/MEH7Q=='))
    encrypted_java_hex_string = '24bb0c7a3fbb059d748f488250a0cf24'.to_java_string
    encrypted_java_bytes = ApacheHexHelper.decodeHex(encrypted_java_hex_string.toCharArray)

    actual_decrypted_text = mingle_cipher.decrypt(encrypted_java_bytes)
    expected_plain_text = 'plainText'

    assert_equal(expected_plain_text, actual_decrypted_text)
  end
end
