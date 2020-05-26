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

import org.junit.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.Mockito;

import javax.servlet.*;
import javax.servlet.http.HttpServletRequest;

import static org.junit.Assert.*;
import static org.mockito.Matchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

public class DynamicRouterTest {

    @Test
    public void testShouldContinueFilterChainWhenRoutingDoesNotMatch() throws Exception {
        RouteConfigClient routeConfigClient = mock(RouteConfigClient.class);
        DynamicRouter dynamicRouter = new DynamicRouter(routeConfigClient);

        ServletRequest request = mock(HttpServletRequest.class);
        ServletResponse response = mock(ServletResponse.class);
        FilterChain filterChain = mock(FilterChain.class);
        RouteConfig routeConfig = mock(RouteConfig.class);

        when(routeConfigClient.isEnabled()).thenReturn(true);
        when(routeConfigClient.getConfigForRoute(any())).thenReturn(routeConfig);
        when(routeConfig.getContext()).thenReturn("");

        dynamicRouter.route(request, response, filterChain);
        ArgumentCaptor<ServletRequest> requestArgumentCaptor = ArgumentCaptor.forClass(ServletRequest.class);
        ArgumentCaptor<ServletResponse> responseArgumentCaptor = ArgumentCaptor.forClass(ServletResponse.class);

        verify(filterChain).doFilter(requestArgumentCaptor.capture(), responseArgumentCaptor.capture());
        assertEquals(request, requestArgumentCaptor.getValue());
        assertEquals(response, responseArgumentCaptor.getValue());
    }


    @Test
    public void testShouldContinueFilterChainWhenRoutingEnabledAndRouteDoesNotMatch() throws Exception {
        RouteConfigClient routeConfigClient = mock(RouteConfigClient.class);
        DynamicRouter dynamicRouter = new DynamicRouter(routeConfigClient);

        ServletRequest request = mock(HttpServletRequest.class);
        ServletResponse response = mock(ServletResponse.class);
        FilterChain filterChain = mock(FilterChain.class);

        when(routeConfigClient.isEnabled()).thenReturn(true);

        when(routeConfigClient.getConfigForRoute(any())).thenReturn(new RouteConfig());

        dynamicRouter.route(request, response, filterChain);
        ArgumentCaptor<ServletRequest> requestArgumentCaptor = ArgumentCaptor.forClass(ServletRequest.class);
        ArgumentCaptor<ServletResponse> responseArgumentCaptor = ArgumentCaptor.forClass(ServletResponse.class);

        verify(filterChain).doFilter(requestArgumentCaptor.capture(), responseArgumentCaptor.capture());
        assertEquals(request, requestArgumentCaptor.getValue());
        assertEquals(response, responseArgumentCaptor.getValue());
    }

    @Test
    public void testShouldForwardToServletDispatcherForMatchedRouteConfigWhenRoutingEnabledAndRouteMatches() throws Exception {
        RouteConfigClient routeConfigClient = mock(RouteConfigClient.class);
        DynamicRouter dynamicRouter = new DynamicRouter(routeConfigClient);

        HttpServletRequest request = mock(HttpServletRequest.class);
        ServletResponse response = mock(ServletResponse.class);
        FilterChain filterChain = mock(FilterChain.class);
        ServletContext servletContext = mock(ServletContext.class);
        ServletContext targetContext = mock(ServletContext.class);
        RequestDispatcher requestDispatcher = mock(RequestDispatcher.class);
        RouteConfig routeConfig = mock(RouteConfig.class);

        when(routeConfigClient.isEnabled()).thenReturn(true);
        when(routeConfigClient.getConfigForRoute(any())).thenReturn(routeConfig);
        when(routeConfig.getContext()).thenReturn("rails_5");
        when(routeConfig.getRootServletName()).thenReturn("RackServlet");
        when(request.getContextPath()).thenReturn("/");
        when(request.getServletContext()).thenReturn(servletContext);
        when(servletContext.getContext("/rails_5")).thenReturn(targetContext);
        when(targetContext.getNamedDispatcher("RackServlet")).thenReturn(requestDispatcher);

        dynamicRouter.route(request, response, filterChain);

        ArgumentCaptor<ServletRequest> requestArgumentCaptor = ArgumentCaptor.forClass(ServletRequest.class);
        ArgumentCaptor<ServletResponse> responseArgumentCaptor = ArgumentCaptor.forClass(ServletResponse.class);

        verify(requestDispatcher).forward(requestArgumentCaptor.capture(), responseArgumentCaptor.capture());

        assertEquals(request, requestArgumentCaptor.getValue());
        assertEquals(response, responseArgumentCaptor.getValue());
    }

    @Test
    public void testShouldContinueFilterChainWhenMatchedRouteConfigAndRoutingDisabled() throws Exception {
        RouteConfigClient routeConfigClient = mock(RouteConfigClient.class);
        DynamicRouter dynamicRouter = new DynamicRouter(routeConfigClient);

        HttpServletRequest request = mock(HttpServletRequest.class);
        ServletResponse response = mock(ServletResponse.class);
        FilterChain filterChain = mock(FilterChain.class);
        RouteConfig routeConfig = mock(RouteConfig.class);

        when(routeConfigClient.isEnabled()).thenReturn(false);
        when(routeConfigClient.getConfigForRoute(any())).thenReturn(routeConfig);
        when(routeConfig.getContext()).thenReturn("rails_5");
        when(routeConfig.getRootServletName()).thenReturn("RackServlet");
        when(request.getContextPath()).thenReturn("/");

        dynamicRouter.route(request, response, filterChain);

        ArgumentCaptor<ServletRequest> requestArgumentCaptor = ArgumentCaptor.forClass(ServletRequest.class);
        ArgumentCaptor<ServletResponse> responseArgumentCaptor = ArgumentCaptor.forClass(ServletResponse.class);

        verify(filterChain).doFilter(requestArgumentCaptor.capture(), responseArgumentCaptor.capture());

        assertEquals(request, requestArgumentCaptor.getValue());
        assertEquals(response, responseArgumentCaptor.getValue());
    }
}
