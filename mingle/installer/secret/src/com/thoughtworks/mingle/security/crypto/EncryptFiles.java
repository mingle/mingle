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
import javax.crypto.CipherOutputStream;
import javax.crypto.spec.SecretKeySpec;
import java.io.*;
import java.nio.channels.FileChannel;
import java.security.GeneralSecurityException;

public class EncryptFiles {
    private static final int DEFAULT_BUFFER_SIZE = 1024 * 4;
    private File src;
    private File dest;
    private SecretKeySpec key;

    public EncryptFiles(File src, File dest) {
        this.src = src;
        this.dest = dest;
    }

    public static void main(String[] args) throws GeneralSecurityException, IOException {
        File src = new File(args[0]);
        File dest = new File(args[1]);
        new EncryptFiles(src, dest).encrypt();
    }

    public void encrypt() throws GeneralSecurityException, IOException {
        key = new SecretKeySpec(Base64.decodeBase64(Key.KEY_BASE_64), Key.ALGORITHM);
        encryptDirectory(src, dest);
    }

    private void encryptDirectory(File src, File dest) throws GeneralSecurityException, IOException {
        if (src.isFile() && dest.isFile()) {
            encryptFile(src, dest);
            return;
        }

        dest.mkdirs();

        File[] children = src.listFiles();
        if (children != null) {
            for (File child : children) {
                File destination = new File(dest, child.getName());
                if (child.isFile()) {
                    if (child.getAbsolutePath().endsWith(".rb")) {
                        encryptFile(child, destination);
                    } else {
                        FileChannel srcFC = new FileInputStream(child).getChannel();
                        FileChannel destFC = new FileOutputStream(destination).getChannel();
                        destFC.transferFrom(srcFC, 0, srcFC.size());
                    }
                } else {
                    encryptDirectory(child, destination);
                }
            }
        }
    }

    private void encryptFile(File src, File dest) throws GeneralSecurityException, IOException {
        Cipher cipher = Cipher.getInstance(Key.ALGORITHM);
        cipher.init(Cipher.ENCRYPT_MODE, key);

        OutputStream out = null;
        InputStream in = null;
        try {
            // make sure only UTF8 encoded data is written to the cipher
            // therefor read platform encoded and write out UTF8 on top of cipher stream
            out = new CipherOutputStream(new FileOutputStream(dest), cipher);
            in = new FileInputStream(src);
            copy(in, out);
        } finally {
            if (out != null) out.close();
            if (in != null) in.close();
        }
    }

    public static void copy(InputStream input, OutputStream output) throws IOException {
        byte[] buffer = new byte[DEFAULT_BUFFER_SIZE];
        int bytes;
        while (-1 != (bytes = input.read(buffer))) {
            output.write(buffer, 0, bytes);
        }
    }
}
