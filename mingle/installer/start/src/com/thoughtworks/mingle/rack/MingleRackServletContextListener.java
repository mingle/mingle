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

import com.thoughtworks.mingle.MingleProperties;
import com.thoughtworks.mingle.util.MingleConfigUtils;
import org.jruby.rack.RackApplication;
import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackConfig;
import org.jruby.rack.RackServletContextListener;
import org.jruby.rack.SharedRackApplicationFactory;
import org.jruby.rack.servlet.DefaultServletRackContext;
import org.jruby.rack.servlet.ServletRackConfig;

import javax.servlet.ServletContext;

import static com.thoughtworks.mingle.util.MingleConfigUtils.railsRoot;

public class MingleRackServletContextListener extends RackServletContextListener {

    public static LoggedPool getRuntimeObjectPool(ServletContext context) {
        return (LoggedPool) new DefaultServletRackContext(new ServletRackConfig(context)).getRackFactory();
    }

    @Override
    protected RackApplicationFactory newApplicationFactory(RackConfig config) {
        ServletContext context = ((ServletRackConfig) config).getServletContext();
        int maxThreads = MingleProperties.jrubyMaxRuntimes(System.getProperties());
        context.log("jruby.max.runtimes: " + maxThreads);
        String appRootDir = railsRoot(context);
        MingleRuntimeFactory baseFactory = new MingleRuntimeFactory(context.getContextPath(), maxThreads, appRootDir);

        return new MinglePoolingRackApplicationFactory(new SharedRackApplicationFactory(baseFactory) {

            @Override
            public RackApplication getApplication() {
                return new MingleApplication(super.getApplication());
            }
        });
    }

}
