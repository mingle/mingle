/*
*  Copyright 2020 ThoughtWorks, Inc.
*
*  This program is free software: you can redistribute it and/or modify
*  it under the terms of the GNU Affero General Public License as
*  published by the Free Software Foundation, either version 3 of the
*  License, or (at your option) any later version.
*
*  This program is distributed in the hope that it will be useful,
*  but WITHOUT ANY WARRANTY; without even the implied warranty of
*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
*  GNU Affero General Public License for more details.
*
*  You should have received a copy of the GNU Affero General Public License
*  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.
*/

package com.thoughtworks.mingle.security.crypto;

import org.apache.commons.codec.binary.Base64;

import javax.crypto.Cipher;
import javax.crypto.CipherInputStream;
import javax.crypto.spec.SecretKeySpec;
import java.io.InputStream;
import java.security.GeneralSecurityException;


class MingleCipherInputStream extends CipherInputStream {

    MingleCipherInputStream(InputStream inputStream) {
        super(inputStream, getMingleCipher());
    }

    private static Cipher getMingleCipher() {
        try {
            Cipher cipher = Cipher.getInstance(Key.ALGORITHM);
            SecretKeySpec key = new SecretKeySpec(Base64.decodeBase64(Key.KEY_BASE_64), Key.ALGORITHM);
            cipher.init(Cipher.DECRYPT_MODE, key);
            return cipher;
        } catch (GeneralSecurityException e) {
            throw new RuntimeException(e);
        }
    }

}
