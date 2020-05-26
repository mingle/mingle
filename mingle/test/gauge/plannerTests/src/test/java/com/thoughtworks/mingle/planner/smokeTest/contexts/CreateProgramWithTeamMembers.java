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
import com.thoughtworks.mingle.planner.smokeTest.utils.JRubyScriptRunner;

import java.util.Arrays;
import java.util.List;

public class CreateProgramWithTeamMembers {
    final private JRubyScriptRunner scriptRunner;
    private List<String> logins;

    public CreateProgramWithTeamMembers() {
        this.scriptRunner = DriverFactory.getScriptRunner();
    }

    @com.thoughtworks.gauge.Step("Create program <programName> with <numberOfTeamMembers> team members - setup")
    public void setUp(final String programName, Integer numberOfTeamMembers) throws Exception {
        createProgram(programName);
        addUserToProgram("admin", programName);
        String[] userLogins = buildUserLoginsArray("user", numberOfTeamMembers);
        createUsers(userLogins);
        addUsersToPlan(userLogins, programName);
    }

    private void createProgram(final String planName) throws Exception {
        scriptRunner.executeWithTestHelpers(new CreateProgramScript(planName));
    }

    private void addUsersToPlan(String[] userLogins, String planName) {
        for (String login : userLogins) {

            addUserToProgram(login, planName);
        }
    }

    private void addUserToProgram(final String login, final String programName) {
        scriptRunner.executeWithTestHelpers(new AddMemberToProgram(login, programName));
    }

    private String[] buildUserLoginsArray(String userLoginPrefix, int numberOfUsers) {
        String[] userLoginsArray = new String[numberOfUsers];
        for (int i = 0; i < numberOfUsers; i++) {
            userLoginsArray[i] = userLoginPrefix + "_" + i;
        }
        return userLoginsArray;
    }

    private void createUsers(final String[] userLogins) {
        scriptRunner.executeWithTestHelpers(new JRubyScriptRunner.ScriptBuilder() {
            public void build(JRubyScriptRunner.ScriptWriter scriptWriter) {
                for (String login : userLogins) {
                    scriptWriter.printfln("create_user!(:name => '%s_name',:login => '%s', :password=>'test123.', :password_confirmation=>'test123.')", login, login);
                }
            }
        });
        this.logins = Arrays.asList(userLogins);
    }

    @com.thoughtworks.gauge.Step("Create program <programName> with <numberOfTeamMembers> team members - teardown")
    public void tearDown(final String programName, Integer numberOfTeamMembers) throws Exception {
        final List<String> localLogins = this.logins;
        if (this.logins != null) {
            scriptRunner.executeWithTestHelpers(new JRubyScriptRunner.ScriptBuilder() {
                public void build(JRubyScriptRunner.ScriptWriter scriptWriter) {
                    for (String login : localLogins) {
                        scriptWriter.printfln("User.find_by_login('%s').destroy", login);
                    }
                }
            });
        }
    }
}
