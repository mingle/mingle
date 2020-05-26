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


public class AssociateProjectsWithProgram {

    private final JRubyScriptRunner scriptRunner;

    public AssociateProjectsWithProgram() {
        this.scriptRunner = DriverFactory.getScriptRunner();
    }

    @com.thoughtworks.gauge.Step("Associate projects <string1> with program <string2> - teardown")
    public void tearDown(String string1, String string2) throws Exception {}


    @com.thoughtworks.gauge.Step("Associate projects <projectNames> with program <planName> - setup")
    public void setUp(String projectNames, final String planName) throws Exception {
        for (final String projectName : projectNames.split(",")) {
            scriptRunner.executeWithTestHelpers(new JRubyScriptRunner.ScriptBuilder() {
                public void build(JRubyScriptRunner.ScriptWriter scriptWriter) {
                    scriptWriter.printfln("Program.find_by_name('%s').projects << Project.find_by_name('%s')", planName, projectName.trim());
                }
            });
        }
    }
}
