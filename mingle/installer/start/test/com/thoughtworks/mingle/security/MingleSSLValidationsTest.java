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

package com.thoughtworks.mingle.security;

import org.junit.Rule;
import org.junit.Test;
import org.junit.rules.ExpectedException;

import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

import static com.thoughtworks.mingle.MingleProperties.*;

public class MingleSSLValidationsTest {
    @Rule
    public ExpectedException thrown = ExpectedException.none();

    @Test
    public void shouldInformUserThatKeyStoreIsRequiredIfSSLPortIsSpecified() throws IOException, MingleSSLValidations.ValidationException {
        expectValidationError("KeyStore properties must be specified if a SSL port is configured");
        validate(
                new String[]{MINGLE_SSL_PORT_KEY, "8089"});
    }

    @Test
    public void shouldInformUserThatKeyStorePasswordIsRequired() throws IOException, MingleSSLValidations.ValidationException {
        expectValidationError("KeyStore password must be specified");
        validate(
                new String[]{MINGLE_SSL_PORT_KEY, "8089"},
                new String[]{MINGLE_SSL_KEYSTORE_KEY, "keystore"});
    }

    @Test
    public void shouldAcceptEmptyKeyStorePassword() throws IOException, MingleSSLValidations.ValidationException {
        validate(
                new String[]{MINGLE_SSL_PORT_KEY, "8089"},
                new String[]{MINGLE_SSL_KEYSTORE_KEY, "keystore"},
                new String[]{MINGLE_SSL_KEYSTORE_PASSWORD_KEY, ""},
                new String[]{MINGLE_SSL_KEY_PASSWORD_KEY, ""});
    }

    @Test
    public void shouldInformUserThatKeyPasswordIsRequired() throws IOException, MingleSSLValidations.ValidationException {
        expectValidationError("Key password must be specified");
        validate(
                new String[]{MINGLE_SSL_PORT_KEY, "8089"},
                new String[]{MINGLE_SSL_KEYSTORE_KEY, "keystore"},
                new String[]{MINGLE_SSL_KEYSTORE_PASSWORD_KEY, "password"});
    }

    @Test
    public void shouldAllowEmptyKeyPasswords() throws IOException, MingleSSLValidations.ValidationException {
        validate(
                new String[]{MINGLE_SSL_PORT_KEY, "8089"},
                new String[]{MINGLE_SSL_KEYSTORE_KEY, "keystore"},
                new String[]{MINGLE_SSL_KEYSTORE_PASSWORD_KEY, "password"},
                new String[]{MINGLE_SSL_KEY_PASSWORD_KEY, ""});
    }

    private void validate(String[]... keyValuePairs) throws MingleSSLValidations.ValidationException {
        new MingleSSLValidations(sslPropertiesFrom(keyValuePairs)).validate();
    }

    private void expectValidationError(String message) {
        thrown.expect(MingleSSLValidations.ValidationException.class);
        thrown.expectMessage(message);
    }

    private Map<String, String> sslPropertiesFrom(String[]... keyValuePairs) {
        Map<String, String> result = new HashMap<String, String>();
        for (String[] keyValuePair : keyValuePairs) {
            result.put(keyValuePair[0], keyValuePair[1]);
        }
        return result;
    }
}
