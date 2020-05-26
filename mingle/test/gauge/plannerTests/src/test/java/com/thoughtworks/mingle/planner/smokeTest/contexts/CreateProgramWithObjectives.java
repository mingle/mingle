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

import com.thoughtworks.mingle.planner.smokeTest.utils.DriverFactory;
import com.thoughtworks.mingle.planner.smokeTest.utils.JRubyScriptRunner;

public class CreateProgramWithObjectives {

    private final JRubyScriptRunner scriptRunner;

    public CreateProgramWithObjectives() {
        this.scriptRunner = DriverFactory.getScriptRunner();
    }

    @com.thoughtworks.gauge.Step("Create program with objectives <programName> <objectiveNames> - setup")
    public void setUp(String programName, String objectiveNames) throws Exception {
        createProgram(programName);
        if ("".equals(objectiveNames)) { return; }
        String[] names = objectiveNames.split(",");
        for (int i = 0; i < names.length; i++) {
            createObjective(programName, names[i].trim(), i);
        }
    }

    public void createProgram(final String programName) throws Exception {
        scriptRunner.executeWithTestHelpers(new CreateProgramScript(programName));
    }

    @com.thoughtworks.gauge.Step("Create program with objectives <programName> <ignored> - teardown")
    public void tearDown(String programName, String ignored) throws Exception {
        scriptRunner.executeRaw("Program.find_by_name('" + programName + "').destroy");
    }

    // Private methods
    private void createObjective(final String programName, final String objectiveName, final int index) throws Exception {
        if ((objectiveName == null) || "".equals(objectiveName)) { throw new RuntimeException("Tried to create an objective with blank name"); }
        scriptRunner.executeWithTestHelpers(new JRubyScriptRunner.ScriptBuilder() {
            public void build(JRubyScriptRunner.ScriptWriter scriptWriter) {
                scriptWriter.println("create_planned_objective(Program.find_by_name('" + programName + "'), :name => '" + objectiveName + "', :start_at => '2011-01-01', :end_at => '2011-01-14', :vertical_position => " + index + ")");
            }
        });
    }
}
