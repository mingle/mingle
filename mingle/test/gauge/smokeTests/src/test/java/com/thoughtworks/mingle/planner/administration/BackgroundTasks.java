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

import net.sf.sahi.client.Browser;

import com.thoughtworks.mingle.planner.fixtures.MingleProjectFixture;
import com.thoughtworks.mingle.planner.smokeTest.util.Assertions;
import com.thoughtworks.mingle.planner.smokeTest.util.HelperUtils;
import com.thoughtworks.mingle.planner.smokeTest.util.JRubyScriptRunner;

public class BackgroundTasks extends Assertions {

    private final JRubyScriptRunner scriptRunner;

    public BackgroundTasks(Browser browser, JRubyScriptRunner jRubyScriptRunner) {
        super(browser);
        this.scriptRunner = jRubyScriptRunner;
    }

    @com.thoughtworks.gauge.Step("Fake date <year> <month> <day> and login to mingle as <user>")
	public void fakeDateAndLoginToMingleAs(int year, int month, int day, String user) throws Exception {
        fakeDateAs(year, month, day);
        new MingleProjectFixture(browser).loginAs(user);

    }

    public void fakeDateAs(int year, int month, int day) throws Exception {
        navigateTo("_class_method_call?class=Clock&method=fake_now&year=" + year + "&month=" + month + "&day=" + day + "&hour=12");
        assertTextPresent("Clock.fake_now called");
        scriptRunner.executeRaw("Clock.fake_now :year => " + year + ", :month => " + month + ", :day => " + day);
    }

    public void resetToCurrentDateAndLoginToMingleAs(String user) throws Exception {
        resetToCurrentDate();
        new MingleProjectFixture(browser).loginAs(user);
    }

    public void resetToCurrentDate() {
        navigateTo("_class_method_call?class=Clock&method=reset_fake");
        assertTextPresent("Clock.reset_fake called");
        scriptRunner.executeRaw("Clock.reset_fake");
    }

    public void takeObjectiveSnapshot(String objectiveName, String projectName) throws Exception {
        scriptRunner.executeRaw("ObjectiveSnapshot.find_all_by_objective_id_and_project_id(Objective.find_by_name('" + objectiveName + "').id, Project.find_by_name('" + projectName + "').id).map(&:destroy)");

        scriptRunner.executeRaw("ObjectiveSnapshot.rebuild_snapshots_for(Objective.find_by_name('" + objectiveName + "').id, Project.find_by_name('" + projectName + "').id)");
    }

    @com.thoughtworks.gauge.Step("Get planner forecasting info for objective <objectiveName> and project <projectName>")
	public void getPlannerForecastingInfoForObjectiveAndProject(String objectiveName, String projectName) throws Exception {
        takeObjectiveSnapshot(objectiveName, projectName);
    }

    @com.thoughtworks.gauge.Step("Get planner forecasting info and login to mingle as <user>")
	public void getPlannerForecastingInfoAndLoginToMingleAs(String user) throws Exception {
        getPlannerForecastingInfoForObjectiveAndProject("Payroll System", "SAP");
        new MingleProjectFixture(browser).loginAs(user);

    }

    @com.thoughtworks.gauge.Step("Run auto sync for project <projectName>")
	public void runAutoSyncForProject(String projectName) throws Exception {
        scriptRunner.executeRaw("SyncObjectiveWorkProcessor.enqueue(Project.find_by_identifier('" + HelperUtils.nameToIdentifier(projectName) + "').id)");
        scriptRunner.executeRaw("SyncObjectiveWorkProcessor.run_once");
    }

}
