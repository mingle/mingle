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

public class ConfigDirectory {

    private String configDir;
    private static final String CONFIG = "config";

    public ConfigDirectory(DataDirectory dataDir) {
        this(configDirPath(dataDir));
    }

    public ConfigDirectory(String configDir) {
        this.configDir = configDir;
    }

    public boolean containsFile(String filename) {
        return new File(filename).exists();
    }

    public String dir() {
        return this.configDir;
    }

    private static String configDirPath(DataDirectory dataDir) {
        if (System.getProperty(MingleProperties.CONFIG_DIR_KEY) != null && System.getProperty(MingleProperties.CONFIG_DIR_KEY).length() != 0) {
            return System.getProperty(MingleProperties.CONFIG_DIR_KEY);
        } else {
            return dataDir.dir() + File.separator + CONFIG;
        }
    }

    public void createIfNeeded() {
        new File(configDir).mkdirs();
        boolean success = new File(configDir).exists();
        if (!success) {
            throw new RuntimeException("Could not create config directory as specified at: " + configDir + ".");
        }
    }
}
