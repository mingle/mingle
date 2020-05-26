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

class MingleCipher
  BLOWFISH_CIPHER_NAME = "Blowfish"

  def initialize(key)
    @key = javax.crypto.spec.SecretKeySpec.new(key.to_java_bytes, BLOWFISH_CIPHER_NAME)
    @cipher = javax.crypto.Cipher.getInstance(BLOWFISH_CIPHER_NAME)
  end

  def encrypt(plain_text)
    @cipher.init(javax.crypto.Cipher::ENCRYPT_MODE, @key)
    @cipher.doFinal(plain_text.to_java_bytes)
  end

  def decrypt(encrypted_java_bytes)
    @cipher.init(javax.crypto.Cipher::DECRYPT_MODE, @key)
    String.from_java_bytes(@cipher.doFinal(encrypted_java_bytes))
  end
end
