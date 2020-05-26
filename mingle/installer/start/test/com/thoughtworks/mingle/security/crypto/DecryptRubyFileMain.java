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

import java.io.*;

public class DecryptRubyFileMain {
    public static void main(String[] args) throws Exception {
        new DecryptRubyFileMain(args[0], args[1]).decrypt();
    }

    private static final int DEFAULT_BUFFER_SIZE = 1024 * 4;
    private File file;
    private String destinationDir;

    public DecryptRubyFileMain(String fileName, String destinationDir) {
        this.file = new File(fileName);
        this.destinationDir = destinationDir;
    }

    public void decrypt() {
        InputStream inputStream = null;
        OutputStream outputStream = null;
        try {
            inputStream = new MingleCipherInputStream(new FileInputStream(file));
            outputStream = new FileOutputStream(new File(destinationDir, file.getName()));
            copy(inputStream, outputStream);
        } catch (IOException ex) {
            throw new RuntimeException(ex);
        } finally {
            closeStream(inputStream);
            closeStream(outputStream);
        }
    }

    private void closeStream(Closeable stream) {
        try {
            if (stream != null) {
                stream.close();
            }
        } catch (IOException ex) {
            throw new RuntimeException(ex);
        }
    }

    private static void copy(InputStream input, OutputStream output) throws IOException {
        byte[] buffer = new byte[DEFAULT_BUFFER_SIZE];
        int bytes;
        while (-1 != (bytes = input.read(buffer))) {
            output.write(buffer, 0, bytes);
        }
    }
}
