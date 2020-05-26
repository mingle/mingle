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

import org.jruby.Ruby;
import org.jruby.rack.RackApplication;
import org.jruby.rack.RackEnvironment;
import org.jruby.rack.RackInitializationException;
import org.jruby.rack.RackResponse;
import org.jruby.runtime.builtin.IRubyObject;

/** A MingleApplication controls the way we access a JRuby runtime */
public class MingleApplication implements RackApplication {

    private RackApplication application;

    public MingleApplication(RackApplication application) {
        this.application = application;
    }

    public void init() throws RackInitializationException {
        // NOOP - applications wrapped with MingleApplication should already be initialized
    }

    public void destroy() {
        this.application.destroy();
    }

    public RackResponse call(RackEnvironment rackEnvironment) {
        return this.application.call(rackEnvironment);
    }

    /** @deprecated should call evalScriptlet instead */
    public Ruby getRuntime() {
        throw new UnsupportedOperationException("Should call evalScript to execute ruby script instead");
    }

    public IRubyObject evalScriptlet(String script) {
        Ruby runtime = application.getRuntime();
        try {
            return runtime.evalScriptlet(script);
        } finally {
            runtime.evalScriptlet("ActiveRecord::Base.clear_active_connections!");
        }
    }
}
