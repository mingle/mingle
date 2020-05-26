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

package com.thoughtworks.mingle.planner.fixtures;

import static junit.framework.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import net.sf.sahi.client.Browser;
import net.sf.sahi.client.ElementStub;

import com.thoughtworks.mingle.planner.smokeTest.util.Assertions;
import com.thoughtworks.mingle.planner.smokeTest.util.HelperUtils;

public class ProgramFixture extends Assertions {

    public ProgramFixture(Browser browser) {
        super(browser);

    }

    @com.thoughtworks.gauge.Step("Create plan in program <planName>")
	public void createPlanInProgram(String planName) throws Exception {
        createPlanForNewProgram(planName, "1 Apr 2011", "7 Apr 2011");
    }

    @com.thoughtworks.gauge.Step("Create program <planName> and switch to days view in plan")
	public void createProgramAndSwitchToDaysViewInPlan(String planName) throws Exception {
        createProgramWithPlanFromToAndSwitchToDaysView(planName, "1 Apr 2011", "7 Apr 2011");
    }

    @com.thoughtworks.gauge.Step("Create program <planName> with plan from <startDateString> to <endDateString> and switch to days view")
	public void createProgramWithPlanFromToAndSwitchToDaysView(String planName, String startDateString, String endDateString) throws Exception {
        createPlanForNewProgram(planName, startDateString, endDateString);
        switchToView("days");
    }

    private void createPlanForNewProgram(String programName, String startDateString, String endDateString) throws Exception {
        createProgram(programName);
        browser.click(browser.link(HelperUtils.nameToIdentifier(programName) + "_plan_link"));
        browser.click(browser.link("plan_edit"));
        browser.execute("$('plan_start_at').value = '" + startDateString + "';");
        browser.execute("$('plan_end_at').value = '" + endDateString + "';");
        browser.submit("Save").click();
    }

    @com.thoughtworks.gauge.Step("Create program <programName>")
	public void createProgram(String programName) throws Exception {
        createNewProgram();
        String new_program_identifier = HelperUtils.nameToIdentifier("new program");

        ElementStub new_program_name_header = browser.heading2("program_" + new_program_identifier + "_link_text");

        browser.textbox("program_name").near(new_program_name_header).setValue(programName);
        browser.execute("$j('#rename_program_" + new_program_identifier + "_form').submit()");
    }

    @com.thoughtworks.gauge.Step("Choose to delete program <programName>")
	public void chooseToDeleteProgram(String programName) throws Exception {
        browser.click(browser.link(programName));
        browser.click(browser.link("Delete"));
    }

    @com.thoughtworks.gauge.Step("Confirm program deletion")
	public void confirmProgramDeletion() throws Exception {
        browser.submit("Delete").click();
    }

    @com.thoughtworks.gauge.Step("Create new program")
	public void createNewProgram() throws Exception {
        browser.navigateTo(pathTo("programs"));
        browser.click(browser.link(HelperUtils.returnLinkText(browser, "new program")));
    }

    @com.thoughtworks.gauge.Step("Assert that current page is programs list page")
	public void assertThatCurrentPageIsProgramsListPage() throws Exception {
        assertCurrentPageIs("/programs");
    }

    @com.thoughtworks.gauge.Step("Assert that program <planName> is displayed on programs list")
	public void assertThatProgramIsDisplayedOnProgramsList(String planName) throws Exception {
        assertTrue(browser.heading2(planName).exists());
    }

    @com.thoughtworks.gauge.Step("Assert that program is not displayed on programs list <programName>")
	public void assertThatProgramIsNotDisplayedOnProgramsList(String programName) throws Exception {
        assertFalse(browser.heading2(programName).exists());
    }

    @com.thoughtworks.gauge.Step("Assert that tab <tabName> is highlighted")
	public void assertThatTabIsHighlighted(String tabName) throws Exception {
        String selectedTabStyles = browser.listItem(tabName).fetch("className");
        assertTrue(selectedTabStyles.contains("selected"));
    }

    @com.thoughtworks.gauge.Step("Assert that cannot see programs tab")
	public void assertThatCannotSeeProgramsTab() throws Exception {
        browser.navigateTo(getPlannerBaseUrl());
        assertFalse("The 'Programs' tab is currently visible! ", browser.byId("tab_programs_link").isVisible());
    }

    @com.thoughtworks.gauge.Step("Assert that projects programs tab is visible")
	public void assertThatProjectsProgramsTabIsVisible() throws Exception {
        assertTrue("The 'Projects' tab is currently invisible! ", projectsTab().isVisible());
        assertTrue("The 'Programs' tab is currently invisible! ", programsTab().isVisible());
    }

    private ElementStub programsTab() {
        return browser.link("Programs").in(browser.div("header-pills"));
    }

    private ElementStub projectsTab() {
        return browser.link("Projects").in(browser.div("header-pills"));
    }

    @com.thoughtworks.gauge.Step("Assert that programs tab is active")
	public void assertThatProgramsTabIsActive() throws Exception {
        assertTrue("The 'Plans' tab is currently not active! ", browser.listItem("Programs").in(browser.div("header-pills")).fetch("className").equals("header-menu-pill selected"));
    }

    @com.thoughtworks.gauge.Step("Assert that cannot create program")
	public void assertThatCannotCreateProgram() throws Exception {
        assertFalse("Can create a new Plan. ", browser.link(HelperUtils.returnLinkText(browser, "new program")).exists());
    }

    @com.thoughtworks.gauge.Step("Assert that cannot delete program")
	public void assertThatCannotDeleteProgram() throws Exception {
        assertFalse("Delete link for plan DOES EXIST!", browser.link("Delete").exists());
    }

    @com.thoughtworks.gauge.Step("Assert that the order of projects in dropdown on program projects page is <programProjectsList>")
	public void assertThatTheOrderOfProjectsInDropdownOnProgramProjectsPageIs(String programProjectsList) throws Exception {
        String trimmedProjectsList = programProjectsList.replaceAll("\\s*,\\s*", ",").trim();
        String actualProjectsList = browser.select("new_program_project_id").getText();
        assertEquals(trimmedProjectsList, actualProjectsList);
    }

    @com.thoughtworks.gauge.Step("Assert that the order of program projects is <programProjectsList>")
	public void assertThatTheOrderOfProgramProjectsIs(String programProjectsList) throws Exception {
        String[] trimmedProgramProjectsList = programProjectsList.replaceAll("\\s*,\\s*", ",").trim().split(",");
        for (int i = 0; i < (trimmedProgramProjectsList.length - 1); i++) {
            assertTrue("The project: " + trimmedProgramProjectsList[i + 1] + " is not under the project: " + trimmedProgramProjectsList[i], browser.cell(trimmedProgramProjectsList[i + 1]).under(browser.cell(trimmedProgramProjectsList[i])).isVisible());
        }
    }

    @com.thoughtworks.gauge.Step("Navigate to program <programName> plan page")
	public void navigateToProgramPlanPage(String programName) throws Exception {
        browser.link(HelperUtils.nameToIdentifier(programName) + "_plan_link").click();
    }

    @com.thoughtworks.gauge.Step("Navigate to program <planName> projects page")
	public void navigateToProgramProjectsPage(String planName) {
        this.navigateTo("programs", HelperUtils.nameToIdentifier(planName), "projects");
    }

    @com.thoughtworks.gauge.Step("Navigate to programs list page")
	public void navigateToProgramsListPage() {
        this.navigateTo("programs");
    }

    @com.thoughtworks.gauge.Step("Assert that program tab is visible")
	public void assertThatProgramTabIsVisible() throws Exception {
        this.navigateTo("projects");
        assertTrue("Programs tab is invisible", programsTab().isVisible());
    }

    @com.thoughtworks.gauge.Step("Assert that program tab is invisible")
	public void assertThatProgramTabIsInvisible() throws Exception {
        this.navigateTo("projects");
        assertFalse("Programs tab is visible", programsTab().isVisible());
    }

    public void renameProgramTo(String fromProgramName, String toProgramName) throws Exception {
        browser.click(browser.link(fromProgramName));
        browser.click(browser.link("Rename"));
        String new_program_identifier = HelperUtils.nameToIdentifier(fromProgramName);

        ElementStub new_program_name_header = browser.heading2("program_" + new_program_identifier + "_link_text");
        browser.textbox("program_name").near(new_program_name_header).setValue(toProgramName);
        browser.execute("$j('#rename_program_" + new_program_identifier + "_form').submit()");
    }

    public void clickBrowserBack() throws Exception {
        browser.execute("window.history.go(-1)");
    }
}
