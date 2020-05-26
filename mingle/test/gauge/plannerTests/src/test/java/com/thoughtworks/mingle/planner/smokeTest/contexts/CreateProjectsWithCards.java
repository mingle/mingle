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

public class CreateProjectsWithCards {
    private final JRubyScriptRunner scriptRunner;

    public CreateProjectsWithCards() {
        this.scriptRunner = DriverFactory.getScriptRunner();
    }

    @com.thoughtworks.gauge.Step("Create projects <projectNames> with <numberOfCards> cards - setup")
    public void setUp(final String projectNames, final Integer numberOfCards) throws Exception {
        System.out.println("Setting up the script");
        this.scriptRunner.executeWithTestHelpers(new JRubyScriptRunner.ScriptBuilder() {
            public void build(JRubyScriptRunner.ScriptWriter scriptWriter) {
                for (String projectName : projectNames.split(",")) {
                    scriptWriter.printfln("create_project(:name => '%s').with_active_project do |project|", projectName);
                    for (int i = 1; i <= numberOfCards; i++) {
                        scriptWriter.printfln("create_card!(:name => '%s_%d')", projectName, i);
                    }
                    scriptWriter.printfln("end");
                }
            }
        });
    }

    @com.thoughtworks.gauge.Step("Create projects <projectNames> with cards - setup")
    public void setUp(String projectNames) throws Exception {
        setUp(projectNames, 3);
    }

    @com.thoughtworks.gauge.Step("Create projects <projectNames> with <numberOfCards> cards - teardown")
    public void tearDown(String projectNames, Integer numberOfCards) throws Exception {
        tearDown(projectNames);
    }

    @com.thoughtworks.gauge.Step("Create projects <projectNames> with cards - teardown")
    public void tearDown(final String projectNames) throws Exception {
        this.scriptRunner.executeWithTestHelpers(new JRubyScriptRunner.ScriptBuilder() {
            public void build(JRubyScriptRunner.ScriptWriter scriptWriter) {
                for (String projectName : projectNames.split(",")) {
                    scriptWriter.printfln("Project.all.each do |project|");
                    scriptWriter.printfln("  if project.name == '%s'", projectName.trim());
                    scriptWriter.printfln("    project.with_active_project { project.destroy rescue nil } #rescue project may already been deleted");
                    scriptWriter.printfln("  end");
                    scriptWriter.printfln("end");
                }
            }
        });
    }
}
