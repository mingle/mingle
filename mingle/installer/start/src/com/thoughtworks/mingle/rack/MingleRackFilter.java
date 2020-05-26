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

package com.thoughtworks.mingle.rack;

import com.thoughtworks.mingle.DataDirPublicFileServlet;
import com.thoughtworks.mingle.StaticFilesServlet;
import org.jruby.rack.RackDispatcher;
import org.jruby.rack.RackEnvironment;
import org.jruby.rack.RackFilter;
import org.jruby.rack.servlet.RequestCapture;
import org.jruby.rack.servlet.ResponseCapture;
import org.jruby.rack.servlet.ServletRackContext;

import javax.servlet.FilterChain;
import javax.servlet.FilterConfig;
import javax.servlet.RequestDispatcher;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import java.io.IOException;

public class MingleRackFilter extends RackFilter {
    protected RackDispatcher dispatcher;

    public void init(FilterConfig config) throws ServletException {
        super.init(config);
        dispatcher = new MingleRackDispatcher(getContext());
    }

    @Override
    protected boolean isDoDispatch(RequestCapture requestCapture, ResponseCapture responseCapture,
                                   FilterChain filterChain, RackEnvironment rackEnvironment)
            throws IOException, ServletException {
        String path = ((HttpServletRequest) requestCapture.getRequest()).getPathInfo();
        if (null != path) {
            if (DataDirPublicFileServlet.isDataDirPublicFileRequest(path)) {
                RequestDispatcher dataDirDispatcher = ((ServletRackContext) getContext()).getNamedDispatcher("mingleFiles");
                dataDirDispatcher.forward(requestCapture.getRequest(), responseCapture.getResponse());

                return false;
            }

            if (StaticFilesServlet.isStaticFile(path)) {
                RequestDispatcher assetDispatcher = ((ServletRackContext) getContext()).getNamedDispatcher("StaticContent");
                assetDispatcher.forward(requestCapture.getRequest(), responseCapture.getResponse());

                return false;
            }
        }

        return super.isDoDispatch(requestCapture, responseCapture, filterChain, rackEnvironment);
    }

    @Override
    protected RackDispatcher getDispatcher() {
        return dispatcher;
    }
}
