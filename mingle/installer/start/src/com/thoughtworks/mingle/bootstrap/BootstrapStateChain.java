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

package com.thoughtworks.mingle.bootstrap;

import com.thoughtworks.mingle.bootstrap.steps.AbstractBootstrapStep;
import com.thoughtworks.mingle.bootstrap.steps.InitiateBootstrap;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.servlet.ServletContext;

public class BootstrapStateChain {

    /** how often do we check for the next pipeline stage? */
    public static final int CHECK_INTERVAL = 500;

    private AbstractBootstrapStep currentLink;
    private final Logger logger = LoggerFactory.getLogger(BootstrapStateChain.class);

    public BootstrapStateChain(ServletContext context) {
        currentLink = new InitiateBootstrap(context);
    }

    public void start() {
        new Thread() {
            @Override
            public void run() {
                while ((currentLink = currentLink.next()) != null) {
                    logger.debug("BOOTSTRAP VALIDATED: " + CurrentBootstrapState.get());

                    if (BootstrapState.UNEXPECTED_FAILURE == CurrentBootstrapState.get()) {
                        logger.error("BOOTSTRAP FAILED after " + currentLink.getClass().getSimpleName());
                        break;
                    }
                    try {
                        Thread.sleep(CHECK_INTERVAL);
                    } catch (InterruptedException e) {
                        // do nothing
                    }
                }
                logger.debug("FINAL BOOTSTRAP STATE: " + CurrentBootstrapState.get());
            }
        }.start();
    }
}
