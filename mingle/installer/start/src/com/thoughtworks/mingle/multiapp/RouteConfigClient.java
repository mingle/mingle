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

import com.thoughtworks.mingle.util.MingleConfigUtils;
import net.spy.memcached.MemcachedClient;

public class RouteConfigClient {
    public static final String MULTI_APP_ROUTING_DISABLED = "MULTI_APP_ROUTING_DISABLED";
    private RouteConfigs routingConfig;
    private final MemcachedClient memcachedClient;

    public RouteConfigClient(String multiAppRoutingConfigFile, MemcachedClient memcachedClient) {
        this.routingConfig = RouteConfigs.build(multiAppRoutingConfigFile);
        this.memcachedClient = memcachedClient;
    }

    public boolean isEnabled() {
        return !MingleConfigUtils.isTruthy(String.valueOf(memcachedClient.get(MULTI_APP_ROUTING_DISABLED)));
    }

    public RouteConfig getConfigForRoute(String requestURI) {
        return routingConfig.getConfigForRoute(requestURI);
    }

    public void destroy() {
        this.memcachedClient.shutdown();
    }
}
