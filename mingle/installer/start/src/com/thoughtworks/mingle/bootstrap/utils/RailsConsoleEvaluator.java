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

package com.thoughtworks.mingle.bootstrap.utils;

import com.thoughtworks.mingle.RubyExpression;
import org.jruby.runtime.builtin.IRubyObject;

import javax.servlet.ServletContext;

public abstract class RailsConsoleEvaluator {

    protected ServletContext context;

    protected RailsConsoleEvaluator(ServletContext context) {
        this.context = context;
    }

    public abstract String getBorrowerName();

    protected IRubyObject evaluate(String expression) throws Exception {
        return new RubyExpression(context, expression).evaluateUsingBorrower(getBorrowerName());
    }
}
