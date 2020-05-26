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

import com.thoughtworks.mingle.bootstrap.utils.BootstrapChecks;

import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;

public class RubyExecutorServlet extends HttpServlet {

    private BootstrapChecks checks;

    @Override
    public void init(final ServletConfig servletConfig) throws ServletException {
        super.init(servletConfig);
        checks = new BootstrapChecks(getServletContext());
        final String ruby = servletConfig.getInitParameter("rubyExpOnInit");
        Thread thread = new Thread(new Runnable() {

            @Override
            public void run() {
                while (!checks.isMingleReady()) {
                    try {
                        Thread.sleep(5000);
                    } catch (InterruptedException e) {
                        log("InterruptedException while waiting for Mingle installed, stop execute " + ruby, e);
                        return;
                    }
                }
                execute(ruby);
            }
        });
        thread.start();
    }

    private void execute(String exp) {
        try {
            new RubyExpression(this.getServletContext(), exp).evaluateWithRuntimeException("RubyExecutorServlet");
        } catch (PoolWaitingTimeoutException e) {
            log("Execute " + exp + " failed", e);
        }
    }
}
