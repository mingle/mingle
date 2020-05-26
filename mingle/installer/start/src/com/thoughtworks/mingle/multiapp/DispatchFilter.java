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
import com.thoughtworks.mingle.MingleProperties;
import com.thoughtworks.mingle.MinglePropertiesFactory;
import com.thoughtworks.mingle.util.MingleConfigUtils;

import javax.servlet.*;
import java.io.IOException;

public class DispatchFilter implements Filter {

    private Router router;
    private static Logger logger = new Logger();
    private MingleProperties mingleProperties;

    @Override
    public void init(FilterConfig filterConfig) throws ServletException {
        try {
            mingleProperties = (MingleProperties) filterConfig.getServletContext().getAttribute(MingleProperties.MINGLE_PROPERTIES_KEY);
            this.router = new StaticRouter();
            this.router = RouterFactory.create(
                    mingleProperties.isMultiAppRoutingEnabled(), mingleProperties.multiAppRoutingConfig(MingleConfigUtils.railsRoot(filterConfig.getServletContext())),
                    mingleProperties.memcachedHost, mingleProperties.memcachedPort);
            logger.info("Initialized DispatchFilter");
        } catch (Exception e) {
            logger.info(String.format("Failed initialisation of router in Dispatch filter: %s", e.getMessage()));
            throw new RuntimeException(e);
        }
    }

    @Override
    public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse, FilterChain filterChain) throws IOException, ServletException {
        router.route(servletRequest, servletResponse, filterChain);
    }

    @Override
    public void destroy() {
        this.router.destroy();
    }
}
