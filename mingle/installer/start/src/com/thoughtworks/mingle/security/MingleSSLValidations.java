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

import java.util.Map;

import static com.thoughtworks.mingle.MingleProperties.*;


public class MingleSSLValidations {
    private final Map<String, String> sslProperties;

    public MingleSSLValidations(Map<String, String> properties) {
        this.sslProperties = properties;
    }

    public void validate() throws ValidationException {
        if (!sslProperties.containsKey(MINGLE_SSL_PORT_KEY)) return;
        if (isBlank(sslProperties.get(MINGLE_SSL_KEYSTORE_KEY))) {
            throw new ValidationException("KeyStore properties must be specified if a SSL port is configured");
        }
        if (sslProperties.get(MINGLE_SSL_KEYSTORE_PASSWORD_KEY) == null) {
            throw new ValidationException("KeyStore password must be specified");
        }
        if (sslProperties.get(MINGLE_SSL_KEY_PASSWORD_KEY) == null) {
            throw new ValidationException("Key password must be specified");
        }
    }

    private boolean isBlank(String s) {
        return s == null || s.length() == 0;
    }

    public static class ValidationException extends Exception {
        public ValidationException(String message) {
            super(message);
        }
    }
}
