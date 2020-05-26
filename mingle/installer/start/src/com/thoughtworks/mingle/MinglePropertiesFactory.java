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

import org.apache.commons.lang.StringUtils;

import java.io.*;
import java.util.Properties;

public class MinglePropertiesFactory {

    public MingleProperties loadMingleProperties(String dataDirProperty) {
        if (StringUtils.isEmpty(dataDirProperty)) {
            throw new RuntimeException("Cannot start Mingle without a data directory specified. On windows or *NIX platforms, you can set this via an environment variable called mingle.dataDir. On OSX, edit the Info.plist inside the appliction package to include a Java system property called mingle.dataDir which points to your data directory");
        }
        DataDirectory dataDir = new DataDirectory(dataDirProperty);
        dataDir.createIfNeeded();
        ConfigDirectory configDir = new ConfigDirectory(dataDir);
        configDir.createIfNeeded();
        return loadMingleProperties(dataDir, configDir);
    }

    MingleProperties loadMingleProperties(DataDirectory dataDir, ConfigDirectory configDir) {
        Properties defaultValues = defaultValues(dataDir);
        try {
            moveIfNecessary(dataDir, configDir);

            Properties properties = mergeDefaultValues(defaultValues, loadProperties(configDir.dir()));

            return createAndSave(dataDir, configDir, properties);
        } catch (FileNotFoundException e) {
            return createAndSave(dataDir, configDir, defaultValues);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    private MingleProperties createAndSave(DataDirectory dataDir, ConfigDirectory configDir, Properties properties) {
        MingleProperties mingleProperties = new MingleProperties(dataDir, configDir, properties);
        mingleProperties.save();
        return mingleProperties;
    }

    private Properties mergeDefaultValues(Properties defaultValues, Properties properties) {
        if (properties.containsKey(MingleProperties.MINGLE_SSL_PORT_KEY))
            defaultValues.remove(MingleProperties.MINGLE_PORT_KEY);

        defaultValues.putAll(properties);
        return defaultValues;
    }

    private Properties defaultValues(DataDirectory dataDir) {
        Properties defaultValues = new Properties();
        defaultValues.setProperty(MingleProperties.SWAP_DIR_KEY, SwapDirectory.defaultInstance(dataDir).toString());
        defaultValues.setProperty(MingleProperties.LOG_DIR_KEY, LogDirectory.defaultInstance(dataDir).toString());
        defaultValues.setProperty(MingleProperties.MEMCACHED_HOST_KEY, "127.0.0.1");
        defaultValues.setProperty(MingleProperties.MEMCACHED_PORT_KEY, "11211");
        defaultValues.setProperty(MingleProperties.APP_CONTEXT_KEY, "/");
        defaultValues.setProperty(MingleProperties.MINGLE_PORT_KEY, "8080");
        return defaultValues;
    }

    private Properties loadProperties(String path) throws IOException {
        Properties properties = new Properties();
        String readline;

        File file = new File(path, MingleProperties.FILE_NAME);
        System.out.println("loading properties from: " + file.getAbsolutePath());
        BufferedReader reader = new BufferedReader(new FileReader(file));
        while ((readline = reader.readLine()) != null) {
            if (readline.startsWith("-D")) {
                String[] systemProps = readline.split("=", 2);

                if ((systemProps[0] != null) && (systemProps[1] != null)) {
                    String keyWithoutDashD = systemProps[0].replaceFirst("^-D", "").trim();
                    String value = systemProps[1].trim();
                    properties.setProperty(keyWithoutDashD, value);
                }
            }
        }
        reader.close();
        return properties;
    }

    private static void moveIfNecessary(DataDirectory dataDir, ConfigDirectory configDir) {
        String minglePropertiesPath = configDir.dir() + File.separator + MingleProperties.FILE_NAME;
        if (!configDir.containsFile(minglePropertiesPath) && dataDir.containsMingleProperties()) {
            dataDir.moveMinglePropertiesToConfigDir(configDir.dir());
        }
    }

}
