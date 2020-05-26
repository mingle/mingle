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

package com.thoughtworks.mingle.multiapp;

import com.thoughtworks.mingle.Logger;
import org.yaml.snakeyaml.TypeDescription;
import org.yaml.snakeyaml.Yaml;
import org.yaml.snakeyaml.constructor.Constructor;

import java.io.*;
import java.util.List;

public class RouteConfigs {

    private static final String RESOURCE="resource";
    private static Logger logger = new Logger();

    private List<RouteConfig> routeConfigs;

    public void setRouteConfigs(List<RouteConfig> routeConfigs) {
            this.routeConfigs = routeConfigs;
        }

    public RouteConfig getConfigForRoute(String route) {
        for (RouteConfig routeConfig : routeConfigs) {
            if (routeConfig.hasRoute(route))
                return routeConfig;
        }
        return new RouteConfig();
    }

    public static RouteConfigs build(String multiAppRoutingConfig) {
        Constructor configsConstructor = new Constructor(RouteConfigs.class);
        TypeDescription configsType = new TypeDescription(RouteConfigs.class);
        configsType.putListPropertyType("routeConfigs", RouteConfig.class);
        configsConstructor.addTypeDescription(configsType);
        Yaml yaml = new Yaml(configsConstructor);
        return (RouteConfigs) yaml.load(getRoutingConfigsFile(multiAppRoutingConfig));
    }

    private static InputStream getRoutingConfigsFile(String multiAppRoutingConfigSource) {

        String[] sourceParts = multiAppRoutingConfigSource.split(":");
        logger.info("multiAppRoutingConfigSource: " + multiAppRoutingConfigSource);
        if(sourceParts.length > 1 && sourceParts[0].equals(RESOURCE)) {
            logger.info("MultiAppRouting: loading route configs from resource: " + sourceParts[1]);
            return RouteConfigs.class.getClassLoader().getResourceAsStream(sourceParts[1]);
        }

        File configSourceFile = new File(multiAppRoutingConfigSource);

        try {
            logger.info("MultiAppRouting: trying to load route configs from file: " + configSourceFile.getCanonicalPath());
            return new FileInputStream(configSourceFile.getCanonicalFile());
        } catch (IOException e ) {
            logger.info("MultiAppRoutingFailure: route config file not found at " + multiAppRoutingConfigSource);
            logger.info("MultiAppRoutingFailure: stopping server as MULTI_APP_ROUTING is enabled and no route configs found");
            throw new RuntimeException(e);
        }

    }
}
