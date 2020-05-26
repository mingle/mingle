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

import javax.net.ssl.KeyManager;
import javax.net.ssl.SSLContext;
import javax.net.ssl.SSLSocketFactory;
import javax.net.ssl.TrustManager;
import java.security.SecureRandom;


public class MingleSSLSocketFactory {
    public SSLSocketFactory getSSLSocketFactory(String certPath, String remoteHost, boolean trustAllCerts) {
        try {
            MingleCertificateTrustManager tm = new MingleCertificateTrustManager(certPath, remoteHost, trustAllCerts);
            KeyManager[] km = null;
            TrustManager[] tma = {tm};
            SSLContext sc = SSLContext.getInstance("SSL");
            sc.init(km, tma, new SecureRandom());
            SSLSocketFactory sf1 = sc.getSocketFactory();
            return sf1;
        } catch (Exception e) {
            return null;
        }
    }

}
