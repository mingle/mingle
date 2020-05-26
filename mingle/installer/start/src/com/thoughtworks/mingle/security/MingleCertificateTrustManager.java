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

import javax.net.ssl.X509TrustManager;
import java.io.FileInputStream;
import java.security.cert.Certificate;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.security.cert.X509Certificate;
import java.util.Collection;


public class MingleCertificateTrustManager implements X509TrustManager {
    private String certPath = null;
    private String remoteHost = null;
    private boolean isTrustAllCerts = false;

    public MingleCertificateTrustManager(String certPath, String remoteHost, boolean trustAllCerts) {
        this.certPath = certPath;
        this.remoteHost = remoteHost;
        this.isTrustAllCerts = trustAllCerts;
    }

    public X509Certificate[] getAcceptedIssuers() {
        return null;
    }

    public void checkClientTrusted(X509Certificate[] arg0, String arg1)
            throws CertificateException {
        throw new CertificateException("Check Client Certificate");
    }

    public void checkServerTrusted(X509Certificate[] chain, String authType) throws CertificateException {
        if (isTrustAllCerts)
            return;
        try {
            CertificateFactory cf = CertificateFactory.getInstance("x509");
            final FileInputStream fis = new FileInputStream(this.certPath);
            X509Certificate verificationCert = verificationCert(cf.generateCertificates(fis));
            X509Certificate remoteCert = remoteCert(chain);
            verifyHostName(remoteCert);
            verifySignedByTrustedSigner(remoteCert, verificationCert);
        } catch (Exception e) {

        }
    }

    private void verifySignedByTrustedSigner(X509Certificate remoteCert, X509Certificate verificationCert) throws Exception {
        remoteCert.verify(verificationCert.getPublicKey());
    }

    private void verifyHostName(X509Certificate remoteCert) throws CertificateException {
        if (this.remoteHost == null) {
            throw new CertificateException("Remote host is unknown");
        } else {
            if (!this.getCN(remoteCert).equals(this.remoteHost)) {
                throw new CertificateException("Remote hostname did not match the CN in certificate");
            }
        }
    }

    private X509Certificate remoteCert(X509Certificate[] chain) throws CertificateException {
        for (Certificate cert : chain) {
            if (cert instanceof X509Certificate) {
                return (X509Certificate) cert;
            }
        }
        throw new CertificateException("Cannot verify Server Certificate: cannot retrieve remote server certificate");
    }

    private X509Certificate verificationCert(Collection<? extends Certificate> certs) throws CertificateException {
        for (Certificate cert : certs) {
            if (cert instanceof X509Certificate) {
                return (X509Certificate) cert;
            }
        }
        throw new CertificateException("Cannot verify Server Certificate: cannot retrieve verification server certificate");
    }

    private String getCN(X509Certificate cert) {
        String subjectPrincipal = cert.getSubjectX500Principal().toString();
        int x = subjectPrincipal.indexOf("CN=");
        if (x >= 0) {
            int y = subjectPrincipal.indexOf(',', x);
            y = (y >= 0) ? y : subjectPrincipal.length();
            return subjectPrincipal.substring(x + 3, y);
        } else {
            return null;
        }
    }
}
