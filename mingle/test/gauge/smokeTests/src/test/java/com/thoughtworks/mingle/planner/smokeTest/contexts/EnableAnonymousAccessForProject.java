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

import com.thoughtworks.mingle.planner.smokeTest.util.JRubyScriptRunner;
import com.thoughtworks.mingle.planner.smokeTest.util.JRubyScriptRunner.ScriptBuilder;
import com.thoughtworks.mingle.planner.smokeTest.util.JRubyScriptRunner.ScriptWriter;

public class EnableAnonymousAccessForProject {

    private final JRubyScriptRunner scriptRunner;

    public EnableAnonymousAccessForProject(JRubyScriptRunner jRubyScriptRunner) {
        this.scriptRunner = jRubyScriptRunner;
    }

    @com.thoughtworks.gauge.Step("Enable anonymous access for project <projectName> - setup")
	public void setUp(final String projectName) throws Exception {
        anonymousAccess(projectName, true);
    }

    @com.thoughtworks.gauge.Step("Enable anonymous access for project <projectName> - teardown")
	public void tearDown(String projectName) throws Exception {
        anonymousAccess(projectName, false);
    }

    private void anonymousAccess(final String project, final boolean anonymous) {
        this.scriptRunner.executeWithBuilder(new ScriptBuilder() {
            public void build(ScriptWriter scriptWriter) {
                makeProjectAnonymouslyAccessibleScript(project, anonymous, scriptWriter);
            }

            private void makeProjectAnonymouslyAccessibleScript(final String project, final boolean anonymous, ScriptWriter writer) {
                writer.printfln("User.with_first_admin do");
                writer.printfln("  project = Project.find_by_name('%s')", project);
                writer.printfln("  project.with_active_project do");
                writer.printfln("    project.update_attribute(:anonymous_accessible, %b)", anonymous);
                writer.printfln("  end");
                writer.printfln("end");
            }
        });
    }

}
