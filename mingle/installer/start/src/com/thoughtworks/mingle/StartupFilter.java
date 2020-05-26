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

import com.thoughtworks.mingle.bootstrap.CurrentBootstrapState;
import com.thoughtworks.mingle.bootstrap.utils.BootstrapChecks;

import javax.servlet.*;
import javax.servlet.http.HttpServletRequest;
import java.io.File;
import java.io.IOException;

import static com.thoughtworks.mingle.bootstrap.BootstrapState.*;

public class StartupFilter implements Filter {
    private String forwardToWhileStarting;
    private BootstrapChecks checks;
    private ServletContext servletContext;
    private RailsPathHelper helper;


    public void init(final FilterConfig filterConfig) throws ServletException {
        servletContext = filterConfig.getServletContext();
        helper = new RailsPathHelper(servletContext);

        forwardToWhileStarting = filterConfig.getInitParameter("forwardToWhileStarting");
        if (forwardToWhileStarting == null) {
            throw new ServletException("'forwardToWhileStarting' init-param is required");
        }

        checks = new BootstrapChecks(servletContext);
    }

    public void destroy() {
    }


    public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain) throws IOException, ServletException {
        if (isFileRequest(servletRequest) || isBootstrapStatusQuery(servletRequest) || isRuntimeStatusQuery(servletRequest) || isAlsoViewRequest(servletRequest) || isDataPublicFile(servletRequest)) {
            passThrough(filterChain, servletRequest, servletResponse);
            return;
        }

        try {
            if (CurrentBootstrapState.hasReached(SCHEMA_UP_TO_DATE) || requiresInstallController()) {
                passThrough(filterChain, servletRequest, servletResponse);
            } else {
                forwardToStartupServlet(servletRequest, servletResponse);
            }
        } catch (Exception e) {
            throw new ServletException(e);
        }
    }

    private void forwardToStartupServlet(ServletRequest servletRequest, ServletResponse servletResponse) throws ServletException, IOException {
        RequestDispatcher dispatcher = servletContext.getRequestDispatcher(forwardToWhileStarting);
        if (dispatcher == null) {
            throw new ServletException("Could not find: " + forwardToWhileStarting);
        }
        dispatcher.forward(servletRequest, servletResponse);
    }

    private void passThrough(FilterChain filterChain, ServletRequest servletRequest, ServletResponse servletResponse) throws IOException, ServletException {
        filterChain.doFilter(servletRequest, servletResponse);
    }

    private boolean requiresInstallController() throws Exception {
        if (CurrentBootstrapState.hasReached(INITIALIZED)) {
            if (CurrentBootstrapState.hasNotReached(DATABASE_CONFIGURED) || !checks.isPendingUpgrade()) {
                return true;
            }
        }
        return false;
    }

    private boolean isBootstrapStatusQuery(ServletRequest servletRequest) {
        return ((HttpServletRequest) servletRequest).getServletPath().equals("/bootstrap_status");
    }

    private boolean isRuntimeStatusQuery(ServletRequest servletRequest) {
        return ((HttpServletRequest) servletRequest).getServletPath().equals("/status");
    }

    private boolean isAlsoViewRequest(ServletRequest servletRequest) {
        return ((HttpServletRequest) servletRequest).getServletPath().equals("/also_viewing");
    }

    private boolean isDataPublicFile(ServletRequest servletRequest) {
      String path = ((HttpServletRequest) servletRequest).getPathInfo();

      return path != null && DataDirPublicFileServlet.isDataDirPublicFileRequest(path);
    }

    private boolean isFileRequest(ServletRequest servletRequest) {
        HttpServletRequest request = (HttpServletRequest) servletRequest;
        String path = request.getServletPath();
        if (request.getPathInfo() != null) {
            path += request.getPathInfo();
        }
        File f = resolveStaticUriToFilesystem(path);
        return f != null && f.isFile();
    }

    private File resolveStaticUriToFilesystem(String uriPath) {
        String pathname = helper.publicRealPath(uriPath.replace('/', File.separatorChar));
        if (pathname == null) {
            return null;
        }
        return new File(pathname);
    }

}
