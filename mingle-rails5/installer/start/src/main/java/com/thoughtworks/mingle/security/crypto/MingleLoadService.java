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

import org.jruby.Ruby;
import org.jruby.runtime.load.LoadService;

import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.ArrayList;

public class MingleLoadService extends LoadService {

    private static File[] encryptedBaseDirs = new File[]{
            new File("app", "models"),
            new File("app", "controllers"),
            new File("app", "helpers"),
            new File("app", "jobs"),
            new File("app", "lib"),
            new File("app", "mailers"),
            new File("app", "channels"),
            new File("lib")
    };
    private final String appRootDir;

    public MingleLoadService(Ruby runtime, String appRootDir) {
        super(runtime);
        this.appRootDir = appRootDir;
    }

    public boolean require(String file) {
        File encryptedFile = getEncryptedFile(file);
        if (encryptedFile != null) {
            String filename = "encrypted:" + file;
            try {
                if (featureAlreadyLoaded(filename)) {
                    return false;
                } else {
                    addLoadedFeature(filename, filename);
                    loadEncryptedScript(encryptedFile);
                }

                return true;
            } catch (Exception e) {
//                e.printStackTrace(System.err);
                return super.require(file);
            }
        } else {
            return super.require(file);
        }
    }

    public void load(String file, boolean wrap) {
        File encrypted = getEncryptedFile(file);
        if (encrypted != null) {
            try {
                loadEncryptedScript(encrypted);
            } catch (Exception e) {
                super.load(file, wrap);
            }
        } else {
            super.load(file, wrap);
        }
    }

    private void loadEncryptedScript(File file) throws IOException {
        InputStream stream = openDecrypted(file);
        try {
            runtime.loadFile(file.getPath(), stream, false);
        } finally {
            close(stream);
        }
    }

    private File getEncryptedFile(String file) {
        if (!file.endsWith(".rb")) {
            file += ".rb";
        }

        File rbFile = new File(file);

        for (File dirName : encryptedBaseDirs) {
            File dir = appRootDir.length() > 0 ? new File(appRootDir, dirName.getPath())  : dirName;
            if (rbFile.isAbsolute()) {
                if (fileExistsWithinDirectory(rbFile, dir)) {
                    return rbFile;
                }
            } else {
                if (fileExistsWithinDirectory(rbFile, dir)) {
                    return rbFile;
                } else {
                    File guessedPath = new File(dir, file);
                    if (fileExistsWithinDirectory(guessedPath, dir)) {
                        return guessedPath;
                    }
                }
            }
        }
        return null;
    }

    private static boolean fileExistsWithinDirectory(File file, File dir) {
        try {
            return file.getCanonicalPath().startsWith(dir.getCanonicalPath()) && file.isFile();
        } catch (IOException e) {
            return false;
        }
    }

    private void close(InputStream stream) {
        try {
            if (stream != null) stream.close();
        } catch (IOException ignore) {
        }
    }

    private InputStream openDecrypted(File file) throws IOException {
        return new MingleCipherInputStream(new FileInputStream(file));
    }
}
