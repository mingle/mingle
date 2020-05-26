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

import org.jruby.rack.DefaultRackDispatcher;
import org.jruby.rack.RackApplication;
import org.jruby.rack.RackContext;
import org.jruby.rack.RackEnvironment;
import org.jruby.rack.RackResponseEnvironment;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.IOException;

/** changed to borrow object with reason */
public class MingleRackDispatcher extends DefaultRackDispatcher {

    private static Logger logger = LoggerFactory.getLogger("com.thoughtworks.mingle.servlet");

    public MingleRackDispatcher(RackContext context) {
        super(context);
    }

    public void process(RackEnvironment request, RackResponseEnvironment response) throws IOException {
        RackApplication app = null;
        Benchmark stats = null;
        try {
            if (logger.isDebugEnabled()) {
                stats = new Benchmark(request.getRequestURI()).start();
            }

            app = ((LoggedPool) getRackFactory()).borrowApplication("Web request: " + request.getRequestURI());
            app.call(request).respond(response);
        } catch (Exception e) {
            handleException(e, request, response);
        } finally {
            if (app != null) afterProcess(app);

            if (stats != null) {
                stats.finish();
                if (stats.duration() > 1500 || Math.abs(stats.heapUsage()) > 5) {
                    logger.debug(stats.toString());
                }
            }
        }
    }
}
