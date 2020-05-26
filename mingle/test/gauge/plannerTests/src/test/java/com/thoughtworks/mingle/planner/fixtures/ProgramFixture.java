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

import com.thoughtworks.mingle.planner.smokeTest.utils.Assertions;
import com.thoughtworks.mingle.planner.smokeTest.utils.HelperUtils;
import org.openqa.selenium.By;
import org.openqa.selenium.JavascriptExecutor;
import org.openqa.selenium.Keys;
import org.openqa.selenium.WebElement;

import java.util.List;

public class ProgramFixture extends Assertions {

    public ProgramFixture() {
        super();
    }

    @com.thoughtworks.gauge.Step("Create program <planName> and switch to days view in plan")
    public void createProgramAndSwitchToDaysViewInPlan(String planName) throws Exception {
        createProgramWithPlanFromToAndSwitchToDaysView(planName, "1 Apr 2011", "7 Apr 2011");
    }

    @com.thoughtworks.gauge.Step("Navigate to programs list page")
    public void navigateToProgramsListPage() {
        this.navigateTo("programs");
    }

    @com.thoughtworks.gauge.Step("Assert that program <planName> is displayed on programs list")
    public void assertThatProgramIsDisplayedOnProgramsList(String planName) throws Exception {
       assertTrue(findElementById("program_"+ HelperUtils.nameToIdentifier(planName)+"_link_text").isDisplayed());
    }

    @com.thoughtworks.gauge.Step("Assert that program is not displayed on programs list <programName>")
    public void assertThatProgramIsNotDisplayedOnProgramsList(String programName) throws Exception {
        assertFalse("Pragram is displayed on the program list page", findElementsById("program_"+HelperUtils.nameToIdentifier(programName)+"_link_text").size() > 0);
    }

    @com.thoughtworks.gauge.Step("Navigate to program <planName> projects page")
    public void navigateToProgramProjectsPage(String planName) {
        this.navigateTo("programs", HelperUtils.nameToIdentifier(planName), "projects");
    }

    @com.thoughtworks.gauge.Step("Create program <planName> with plan from <startDateString> to <endDateString> and switch to days view")
    public void createProgramWithPlanFromToAndSwitchToDaysView(String planName, String startDateString, String endDateString) throws Exception {
        createPlanForNewProgram(planName, startDateString, endDateString);
        switchToView("days");
    }

    private void createPlanForNewProgram(String programName, String startDateString, String endDateString) throws Exception {
        createProgram(programName);
        waitForElement(By.id(HelperUtils.nameToIdentifier(programName) + "_plan_link"));
        findElementById(HelperUtils.nameToIdentifier(programName) + "_plan_link").click();
        findElementById("plan_edit").click();
        waitForPageLoad(3000);
        excecuteJs("$('plan_start_at').value = '" + startDateString + "';");
        excecuteJs("$('plan_end_at').value = '" + endDateString + "';");
        findElementById("save_plan_button").click();
    }
    @com.thoughtworks.gauge.Step("Set planner Start date <startDate> and End date <endDate>")
    public void setPlannerDate(String startDate, String endDate) throws InterruptedException {
        findElementById("plan_edit").click();
        waitForPageLoad(3000);
        excecuteJs("$('plan_start_at').value = '" + startDate.trim() + "';");
        excecuteJs("$('plan_end_at').value = '" + endDate.trim() + "';");
        findElementById("save_plan_button").click();
    }

    @com.thoughtworks.gauge.Step("Create program <programName>")
    public void createProgram(String programName) throws Exception {
        createNewProgram();
        String newProgramIdentifier = HelperUtils.nameToIdentifier("new program");
        waitForPageLoad(2000);
        excecuteJs("document.getElementById(\"program_name\").value=\""+programName+"\"");
        excecuteJs("$j('#rename_program_" + newProgramIdentifier + "_form').submit()");
    }

    public void createProgramWithCount(String programName, int count) throws Exception {
        createNewProgram();
        String newProgramIdentifier = HelperUtils.nameToIdentifier("new program");
        waitForPageLoad(2000);
        excecuteJs("document.getElementById(\"program_name\").value=\""+programName+"\"");
        if(count >= 2){
            newProgramIdentifier = newProgramIdentifier+Integer.toString(count-1);
        }
        excecuteJs("$j('#rename_program_" + newProgramIdentifier + "_form').submit()");
    }

    @com.thoughtworks.gauge.Step("Create new program")
    public void createNewProgram() throws Exception {
        this.driver.get(pathTo("programs"));
        findElementByXpath("//a[text()='new program']").click();
    }

    @com.thoughtworks.gauge.Step("Assert that cannot see programs tab")
    public void assertThatCannotSeeProgramsTab() throws Exception {
        this.driver.get(getPlannerBaseUrl());
        assertFalse("The 'Programs' tab is currently visible! ", findElementsById("tab_programs_link").size() < 0);
    }

    @com.thoughtworks.gauge.Step("Choose to delete program <programName>")
    public void chooseToDeleteProgram(String programName) throws Exception {
        findElementByXpath("//*[@title=\"Finance Program\"]").click();
        waitForElement(By.xpath("//a[text()='Delete']"));
        findElementByXpath("//a[text()='Delete']").click();
    }

    @com.thoughtworks.gauge.Step("Confirm program deletion")
    public void confirmProgramDeletion() throws Exception {
        //Change it to ID
        waitForElement(By.xpath("//*[@value=\"Delete\"]"));
        findElementByXpath("//*[@value=\"Delete\"]").click();
    }

    @com.thoughtworks.gauge.Step("Assert that current page is programs list page")
    public void assertThatCurrentPageIsProgramsListPage() throws Exception {
        assertCurrentPageIs("/programs");
    }

    @com.thoughtworks.gauge.Step("Assert that programs tab is active")
    public void assertThatProgramsTabIsActive() throws Exception {
        assertTrue("The 'Plans' tab is currently not active! ", findElementById("header-pills").findElements(By.linkText("Programs")).size()>0);
    }

    @com.thoughtworks.gauge.Step("Assert that tab <tabName> is highlighted")
    public void assertThatTabIsHighlighted(String tabName) throws Exception {
        assertTrue("Project tab is not highlighed", findElementByCssSelector("li.header-menu-pill.selected").getText().equals(tabName));
    }

    @com.thoughtworks.gauge.Step("Assert that projects programs tab is visible")
    public void assertThatProjectsProgramsTabIsVisible() throws Exception {
        assertTrue("The 'Projects' tab is currently invisible! ", projectsTab().size()>0);
        assertTrue("The 'Programs' tab is currently invisible! ", programsTab().size()>0);
    }

    private List<WebElement> projectsTab() {
        return findElementById("header-pills").findElements(By.linkText("Projects"));
    }

    private List<WebElement> programsTab() {
        return findElementById("header-pills").findElements(By.linkText("Programs"));
    }

    @com.thoughtworks.gauge.Step("Navigate to program <programName> plan page")
    public void navigateToProgramPlanPage(String programName) throws Exception {
        waitForElement(By.id(HelperUtils.nameToIdentifier(programName)+"_plan_link"));
        findElementById(HelperUtils.nameToIdentifier(programName)+"_plan_link").click();
    }
    @com.thoughtworks.gauge.Step("Assert that cannot create program")
    public void assertThatCannotCreateProgram() throws Exception {
        assertFalse("Can create a new Plan. ", findElementsByXpath("//*[text()=\""+HelperUtils.nameToIdentifier("new program")+"\"]").size() > 0);
    }

    @com.thoughtworks.gauge.Step("Create plan in program <planName>")
    public void createPlanInProgram(String planName) throws Exception {
        createPlanForNewProgram(planName, "1 Apr 2011", "7 Apr 2011");
    }

    @com.thoughtworks.gauge.Step("Assert that the order of projects in dropdown on program projects page is <programProjectsList>")
    public void assertThatTheOrderOfProjectsInDropdownOnProgramProjectsPageIs(String programProjectsList) throws Exception {
        String trimmedProjectsList = programProjectsList.replaceAll("\\s*,\\s*", "\n").trim();
        String actualProjectsList = findElementById("new_program_project_id").getText();
        assertEquals(trimmedProjectsList, actualProjectsList);
    }


    @com.thoughtworks.gauge.Step("Assert that the order of program projects is <programProjectsList>")
    public void assertThatTheOrderOfProgramProjectsIs(String programProjectsList) throws Exception {
        String[] trimmedProgramProjectsList = programProjectsList.replaceAll("\\s*,\\s*", ",").trim().split(",");
        for (int i = 0; i < (trimmedProgramProjectsList.length - 1); i++) {
            assertTrue("The project: " + trimmedProgramProjectsList[i + 1] + " is not under the project: " + trimmedProgramProjectsList[i], findElementsById("project_"+HelperUtils.nameToIdentifier(trimmedProgramProjectsList[i].trim())).size()>0);
        }
    }

    @com.thoughtworks.gauge.Step("Assert that cannot delete program")
    public void assertThatCannotDeleteProgram() throws Exception {
        assertFalse("Delete link for plan DOES EXIST!", findElementsByLinkText("Delete").size()>0);
    }
}


