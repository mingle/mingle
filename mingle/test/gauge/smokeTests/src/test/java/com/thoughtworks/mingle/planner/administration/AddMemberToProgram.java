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

import com.thoughtworks.mingle.planner.smokeTest.util.JRubyScriptRunner.ScriptBuilder;
import com.thoughtworks.mingle.planner.smokeTest.util.JRubyScriptRunner.ScriptWriter;

public final class AddMemberToProgram implements ScriptBuilder {
    private final String programName;
    private final String login;

    public AddMemberToProgram(String login, String programName) {
        this.programName = programName;
        this.login = login;
    }

    public void build(ScriptWriter scriptWriter) {
        scriptWriter.printfln("user = User.find_by_login('%s')", login);
        scriptWriter.printfln("program = Program.find_by_name('%s')", programName);
        scriptWriter.printfln("program.add_member(user)");
    }
}
