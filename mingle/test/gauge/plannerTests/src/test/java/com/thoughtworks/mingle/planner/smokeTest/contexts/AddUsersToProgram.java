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

import com.thoughtworks.mingle.planner.administration.AddMemberToProgram;
import com.thoughtworks.mingle.planner.smokeTest.utils.DriverFactory;
import com.thoughtworks.mingle.planner.smokeTest.utils.HelperUtils;
import com.thoughtworks.mingle.planner.smokeTest.utils.JRubyScriptRunner;

public class AddUsersToProgram {

    private final JRubyScriptRunner scriptRunner;

    public AddUsersToProgram() {
        this.scriptRunner = DriverFactory.getScriptRunner();
    }

    @com.thoughtworks.gauge.Step("Add users <userLoginsString> to program <programName> - setup")
    public void setUp(final String userLoginsString, final String programName) throws Exception {
        for (String login : HelperUtils.arrayFromString(userLoginsString)) {
            this.scriptRunner.executeWithTestHelpers(new AddMemberToProgram(login, programName));
        }
    }

    @com.thoughtworks.gauge.Step("Add users <string1> to program <string2> - teardown")
    public void tearDown(String string1, String string2) throws Exception {}
}
