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

import java.util.Collections;
import java.util.List;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

public class RouteConfig {
    private String context;
    private List<Pattern> routes;
    private String rootServletName;

    public RouteConfig() {
        this.context = this.rootServletName = "";
        this.routes = Collections.emptyList();
    }

    public boolean hasRoute(String route) {
        if (routes.isEmpty())
            return false;

        return this.routes.stream().anyMatch(routePattern -> routePattern.asPredicate().test(route));
    }

    public String getContext() {
        return context;
    }

    public String getRootServletName() {
        return rootServletName;
    }
    public void setContext(String context) {
        this.context = context;
    }

    public void setRoutes(List<String> routes) {
        if (routes != null && routes.isEmpty())
            this.routes =  Collections.emptyList();

        this.routes = routes.stream().map(route -> Pattern.compile("\\A"+ route + "\\z")).collect(Collectors.toList());
    }

    public void setRootServletName(String rootServletName) {
        this.rootServletName = rootServletName;
    }

}
