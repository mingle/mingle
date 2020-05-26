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

package com.thoughtworks.mingle.security;

import com.thoughtworks.mingle.bootstrap.utils.RailsConsoleEvaluator;

import javax.servlet.*;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;

public class TokenAuthFilter implements Filter {

    public static final String AUTHENTICATED_ATTR = "authenticated";
    private TokenAuthFilter.MingleTokenAuthenticator authenticator;

    @Override
    public void destroy() {
    }

    @Override
    public void init(FilterConfig filterConfig) throws ServletException {
        authenticator = new MingleTokenAuthenticator(filterConfig.getServletContext());
    }

    @Override
    public void doFilter(ServletRequest request, ServletResponse response, FilterChain filterChain) throws IOException, ServletException {
        if (authenticator.authenticate((HttpServletRequest) request)) {
            filterChain.doFilter(request, response);
            return;
        }
        ((HttpServletResponse) response).sendError(HttpServletResponse.SC_FORBIDDEN, "Forbidden");
    }

    public class MingleTokenAuthenticator extends RailsConsoleEvaluator {

        public static final String AUTH_HEADER = "MINGLE_API_KEY";

        public MingleTokenAuthenticator(ServletContext context) {
            super(context);
        }

        public boolean authenticate(HttpServletRequest request) {
            boolean isGetRequest = "GET".equalsIgnoreCase(request.getMethod());
            String key = request.getHeader(AUTH_HEADER);
            if (key == null || key.contains("\"")) {
                // we have to set auth attr value, as
                // MinglePeriodicalTaskServlet need the info
                request.setAttribute(AUTHENTICATED_ATTR, false);
                return isGetRequest;
            }
            try {
                boolean authenticated = evaluate("AuthenticationKeys.auth?(\"" + key + "\")").isTrue();
                request.setAttribute(AUTHENTICATED_ATTR, authenticated);
                return authenticated || isGetRequest;
            } catch (Exception e) {
                e.printStackTrace();
                return false;
            }
        }

        @Override
        public String getBorrowerName() {
            return getClass().getSimpleName();
        }
    }
}
