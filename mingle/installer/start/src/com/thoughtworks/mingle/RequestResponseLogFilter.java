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

import javax.servlet.*;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

public class RequestResponseLogFilter implements Filter {
    private static Logger logger = Logger.getLogger(RequestResponseLogFilter.class);

    public void init(FilterConfig filterConfig) throws ServletException {
    }

    public void destroy() {
    }

    public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain) throws IOException, ServletException {
        boolean logRequest = logRequest((HttpServletRequest) servletRequest);
        long start = System.currentTimeMillis();
        try {
            filterChain.doFilter(servletRequest, servletResponse);
        } finally {
            if (logRequest) {
                long time = System.currentTimeMillis() - start;
                logResponse(time, (HttpServletRequest) servletRequest, (HttpServletResponse) servletResponse);
            }
        }
    }

    private void logResponse(long time, HttpServletRequest request, HttpServletResponse response) {
        logger.info("response for request (" + time + " ms): " + request.getRequestURL() + "\n-------- start -------\n" + response.toString() + "\n======== end ========\n");
    }

    private boolean logRequest(HttpServletRequest request) {
        String url = request.getRequestURL().toString();
        if (url.endsWith(".css") || url.endsWith(".js") || url.endsWith(".png") || url.endsWith(".gif")) {
            return false;
        }
        logger.info("request: " + request.getRequestURL());
        return true;
    }
}
