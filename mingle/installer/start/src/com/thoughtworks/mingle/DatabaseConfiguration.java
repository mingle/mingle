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

import com.thoughtworks.mingle.util.MingleConfigUtils;

import java.io.File;
import java.util.Map;

public class DatabaseConfiguration {
    private Map databaseConfigurations = null;
    private String environment;
    private Map databaseProperties = null;

    public DatabaseConfiguration(String environment) {
        this.environment = environment;
        if (this.environment == null)
            this.environment = "production";
    }

    public Map getDatabaseProperties() {
        if (databaseProperties == null)
            databaseProperties = (Map) databaseConfigurations().get(environment);
        return databaseProperties;
    }

    public boolean isPostgres() {
        return url().contains("postgresql");
    }

    public String url() {
        return getDatabaseProperties().get(urlKey()).toString();
    }

    public String username() {

        return getDatabaseProperties().get(usernameKey()).toString();
    }

    public String password() {
        return getDatabaseProperties().get(passwordKey()).toString();
    }

    public String driver() {
        return getDatabaseProperties().get(driverKey()).toString();
    }

    private Map databaseConfigurations() {
        if (databaseConfigurations == null)
            databaseConfigurations = MingleConfigUtils.loadPropertiesFromYaml(databaseConfigFile());
        return databaseConfigurations;
    }

    private String databaseConfigFile() {
        return System.getProperty(MingleProperties.CONFIG_DIR_KEY) + File.separator + "database.yml";
    }

    private Object driverKey() {
        return mapKey(getDatabaseProperties(), "driver");
    }

    private Object urlKey() {
        return mapKey(getDatabaseProperties(), "url");
    }

    private Object usernameKey() {
        return mapKey(getDatabaseProperties(), "username");
    }

    private Object passwordKey() {
        return mapKey(getDatabaseProperties(), "password");
    }

    private Object mapKey(Map properties, String stringVersionOfKey) {
        for (Object o : properties.keySet()) {
            if (o.toString().equals(stringVersionOfKey)) {
                return o;
            }
        }
        return "";
    }

}
