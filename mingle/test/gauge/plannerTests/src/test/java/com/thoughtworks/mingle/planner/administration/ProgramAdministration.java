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

package com.thoughtworks.mingle.planner.administration;

import com.thoughtworks.mingle.planner.smokeTest.utils.DriverFactory;
import com.thoughtworks.mingle.planner.smokeTest.utils.JRubyScriptRunner;

public class ProgramAdministration {

    public class Program {
        private final StringBuffer script;

        public Program(String name) {
            this.script = new StringBuffer("program = Program.find_by_name('" + name + "');");
        }

        public void addMember(String user) {
            this.script.append("program.add_member(" + user + ");");
        }

        public void execute() {
            scriptRunner.executeRaw(this.script.toString());
        }

        public String toString() {
            return this.script.toString();
        }
    }

    private final JRubyScriptRunner scriptRunner;

    public ProgramAdministration() {
        this.scriptRunner = DriverFactory.getScriptRunner();
    }

    @com.thoughtworks.gauge.Step("Add full team member <loginName> to program <programName>")
    public void addFullTeamMemberToProgram(String loginName, String programName) throws Exception {
        Program program = new Program(programName);
        program.addMember(user(loginName));
        program.execute();
    }

    private String user(String login) {
        return "User.find_by_login('" + login + "')";
    }
}
