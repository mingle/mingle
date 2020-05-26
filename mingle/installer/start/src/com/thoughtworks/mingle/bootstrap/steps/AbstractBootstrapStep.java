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

package com.thoughtworks.mingle.bootstrap.steps;

import com.thoughtworks.mingle.bootstrap.BootstrapState;
import com.thoughtworks.mingle.bootstrap.CurrentBootstrapState;
import com.thoughtworks.mingle.bootstrap.utils.BootstrapChecks;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.servlet.ServletContext;

public abstract class AbstractBootstrapStep {

    private Logger logger;

    private final BootstrapChecks checks;
    protected final ServletContext context;

    public AbstractBootstrapStep(ServletContext context) {
        this.context = context;
        this.checks = new BootstrapChecks(context);
        this.logger = LoggerFactory.getLogger(this.getClass());
    }

    protected abstract AbstractBootstrapStep process();

    public AbstractBootstrapStep next() {
        synchronized (CurrentBootstrapState.class) {
            if (isInErrorState()) return null;

            return process();
        }
    }

    protected Logger logger() {
        return logger;
    }

    protected void setState(BootstrapState state) {
        CurrentBootstrapState.set(state);
    }

    protected BootstrapChecks checks() {
        return checks;
    }

    private boolean isInErrorState() {
        BootstrapState state = CurrentBootstrapState.get();
        switch (state) {
            case UNSUPPORTED_DATABASE:
            case MIGRATION_ERROR:
            case UNEXPECTED_FAILURE:
                return true;
            default:
                return false;
        }
    }
}
