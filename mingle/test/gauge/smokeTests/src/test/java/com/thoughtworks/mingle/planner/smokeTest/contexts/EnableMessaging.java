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

package com.thoughtworks.mingle.planner.smokeTest.contexts;

// JUnit Assert framework can be used for verification

import com.thoughtworks.mingle.planner.smokeTest.util.JRubyScriptRunner;

public class EnableMessaging {

    private final JRubyScriptRunner scriptRunner;

    public EnableMessaging(JRubyScriptRunner jRubyScriptRunner) {
        this.scriptRunner = jRubyScriptRunner;
    }

    @com.thoughtworks.gauge.Step("Enable messaging - setup")
	public void setUp() throws Exception {
        enableMessaging();

    }

    @com.thoughtworks.gauge.Step("Enable messaging - teardown")
	public void tearDown() throws Exception {
        disableMessaging();
    }

    private void enableMessaging() {
        scriptRunner.executeRaw("Messaging.enable");
        scriptRunner.executeRaw(" $__broker__ = org.apache.activemq.broker.BrokerFactory.createBroker('xbean:' + File.join(Rails.root, 'test', 'data', 'test_activemq.xml'), true)");
    }

    private void disableMessaging() {
        scriptRunner.executeRaw("Messaging.reset_connection");
        scriptRunner.executeRaw("$__broker__.stop if $__broker__");
        scriptRunner.executeRaw("Messaging.disable");
    }
}
