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

import com.thoughtworks.mingle.bootstrap.BootstrapState;
import com.thoughtworks.mingle.bootstrap.BootstrapStateChain;
import com.thoughtworks.mingle.bootstrap.CurrentBootstrapState;

import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;

public class BootstrapListener implements ServletContextListener {

    public void contextInitialized(ServletContextEvent event) {
        if ("true".equals(java.lang.System.getProperty("mingle.skipInstallCheck"))) {
            CurrentBootstrapState.set(BootstrapState.BOOTSTRAP_COMPLETED);
        } else {
            new BootstrapStateChain(event.getServletContext()).start();
        }
    }

    public void contextDestroyed(ServletContextEvent event) {
    }
}
