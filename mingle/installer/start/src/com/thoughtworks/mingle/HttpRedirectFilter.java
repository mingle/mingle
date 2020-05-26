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

import org.apache.log4j.Logger;

import javax.servlet.Filter;
import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.ServletException;
import javax.servlet.ServletRequest;
import javax.servlet.ServletResponse;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.File;
import java.io.IOException;

public class HttpRedirectFilter implements Filter {
    public static String X_FORWARDED_PROTO = "X-Forwarded-Proto";

    private static Logger logger = Logger.getLogger(HttpRedirectFilter.class);

    private boolean isRedirectHttpRequest;
    private RailsPathHelper helper;

    @Override
    public void init(FilterConfig filterConfig) throws ServletException {
        helper = new RailsPathHelper(filterConfig.getServletContext());
        String config = System.getProperty("mingle.redirectHttpRequest");
        isRedirectHttpRequest = "true".equalsIgnoreCase(config);
        if (config != null) {
            logger.info("mingle.redirectHttpRequest is configured: " + config);
        }
    }

    @Override
    public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain) throws IOException, ServletException {
        if (isRedirectHttpRequest) {
            HttpServletRequest request = (HttpServletRequest) servletRequest;
            // Only redirect a forwarded http request to https if it was not assets requests.
            // This is only used for SaaS env, redirecting http requests from ELB
            if (isForwardedHttpRequest(request.getHeader(X_FORWARDED_PROTO))) {
                if (isStaticAsset(request)) {
                    String pathInfo = request.getPathInfo();
                    if (pathInfo.endsWith("eot") ||
                            pathInfo.endsWith("ttf") ||
                            pathInfo.endsWith("woff") ||
                            pathInfo.endsWith("woff2") ||
                            pathInfo.endsWith("svg") ||
                            pathInfo.endsWith("otf")) {
                        ((HttpServletResponse) servletResponse).addHeader("Access-Control-Allow-Origin", "*");
                    }
                } else {
                    String url = replaceHttpWithHttps(request.getRequestURL());
                    if (logger.isDebugEnabled()) {
                        logger.debug("Redirect from " + request.getRequestURL() + " to " + url);
                    }
                    ((HttpServletResponse) servletResponse).sendRedirect(url);
                    return;
                }
            }
        }
        filterChain.doFilter(servletRequest, servletResponse);
    }

    private boolean isStaticAsset(HttpServletRequest request) {
        String path = request.getPathInfo();
        if (path == null) {
            return false;
        }
        File file = new File(helper.publicRealPath(path));
        return file.exists() && file.isFile();
    }

    @Override
    public void destroy() {
    }

    public String replaceHttpWithHttps(StringBuffer url) {
        return url.replace(0, 4, "https").toString();
    }

    public boolean isForwardedHttpRequest(String forwardedProto) {
        return forwardedProto != null && "http".equalsIgnoreCase(forwardedProto);
    }

}
