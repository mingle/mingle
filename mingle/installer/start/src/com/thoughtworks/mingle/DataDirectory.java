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

package com.thoughtworks.mingle;

import java.io.File;

public class DataDirectory {

    private String datadir;

    public DataDirectory() {
        this(DataDirectory.dataDirPath());
    }

    public DataDirectory(String datadir) {
        this.datadir = datadir.trim();
        if (this.datadir.endsWith(File.separator)) {
            this.datadir = this.datadir.substring(0, this.datadir.length() - 1);
        }
        this.datadir = expandTilde(this.datadir);
    }

    public void moveMinglePropertiesToConfigDir(String configDir) {
        File oldPathWhenItLivedInDataDir = new File(dir() + File.separator + MingleProperties.FILE_NAME);
        File newPathInConfigDir = new File(configDir, MingleProperties.FILE_NAME);
        oldPathWhenItLivedInDataDir.renameTo(newPathInConfigDir);
    }

    public boolean containsMingleProperties() {
        File oldPathWhenItLivedInDataDir = new File(dir() + File.separator + MingleProperties.FILE_NAME);
        return oldPathWhenItLivedInDataDir.exists();
    }

    public boolean isEmpty() {
        return (this.datadir == null || this.datadir.equals(""));
    }

    public File subdirectoryNamed(String subdirectoryPath) {
        return new File(datadir + File.separator + subdirectoryPath);
    }

    public String dir() {
        return this.datadir;
    }

    public void createIfNeeded() {
        if (isEmpty()) return;
        new File(datadir).mkdirs();
        boolean success = new File(datadir).exists();
        if (!success) {
            throw new RuntimeException("Could not create data directory as specified at: " + datadir + ".");
        }
    }

    private static String dataDirPath() {
        if (System.getProperty(MingleProperties.DATA_DIR_KEY) != null && System.getProperty(MingleProperties.DATA_DIR_KEY).length() != 0) {
            return System.getProperty(MingleProperties.DATA_DIR_KEY);
        } else {
            return System.getProperty("user.home") + File.separator + "Mingle";
        }
    }

    private String expandTilde(String path) {
        if (!path.startsWith("~")) return path;
        path = path.replaceFirst("~", "");
        String homeDirectory = System.getProperty("user.home");
        if (homeDirectory.endsWith(File.separator) && path.startsWith(File.separator)) {
            path = path.replaceFirst(File.separator, "");
        }
        return homeDirectory + path;
    }
}
