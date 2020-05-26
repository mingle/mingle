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

import org.apache.catalina.servlets.DefaultServlet;
import org.apache.commons.lang.StringUtils;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.regex.Pattern;

public class StaticFilesServlet extends DefaultServlet {
    private static Pattern assetRegex = Pattern.compile("^\\/(assets/|images/|javascripts/|flash/|fonts/|maintenance/|plugin_assets/|favicon\\.ico).*");

    private String cacheControl;
    private String publicRoot;

    public static boolean isStaticFile(String requestURI) {
        return assetRegex.matcher(requestURI).matches();
    }

    @Override
    public void init() throws ServletException {
        super.init();
        cacheControl = getServletConfig().getInitParameter("cacheControl");
        publicRoot = getServletContext().getInitParameter("public.root");
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws IOException, ServletException {
        if (!StringUtils.isBlank(cacheControl)) {
            response.setHeader("Cache-Control", cacheControl);
        }
        super.doGet(request, response);
    }

    @Override
    protected String getRelativePath(HttpServletRequest request) {
        String path = super.getRelativePath(request);
        if (path.startsWith("/")) {
            return publicRoot + path;
        } else {
            return publicRoot + "/" + path;
        }
    }
}
