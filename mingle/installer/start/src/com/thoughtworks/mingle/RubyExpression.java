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

import com.thoughtworks.mingle.rack.LoggedPool;
import com.thoughtworks.mingle.rack.MingleApplication;
import org.jruby.runtime.builtin.IRubyObject;

import javax.servlet.ServletContext;

public class RubyExpression {
    private LoggedPool pool;
    private String expression;

    public RubyExpression(ServletContext context, String expression) throws PoolWaitingTimeoutException {
        this(getInitializedRuntimePool(context), expression);
    }

    public RubyExpression(LoggedPool pool, String expression) {
        this.pool = pool;
        this.expression = expression;
    }

    public IRubyObject evaluateWithRuntimeException(String borrower) {
        try {
            return evaluateUsingBorrower(borrower);
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    public IRubyObject evaluateUsingBorrower(String borrower) throws Exception {
        MingleApplication application = (MingleApplication) pool.borrowApplication("RubyExpression(" + borrower + "): " + expression);
        try {
            return application.evalScriptlet(expression);
        } finally {
            if (application != null) {
                pool.finishedWithApplication(application);
            }
        }
    }

    private static LoggedPool getInitializedRuntimePool(ServletContext context) throws PoolWaitingTimeoutException {
        return new PoolServletStore(context).getInitializedRuntimePool();
    }

}
