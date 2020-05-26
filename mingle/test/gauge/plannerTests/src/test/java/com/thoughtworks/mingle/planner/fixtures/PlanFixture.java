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

import com.thoughtworks.mingle.planner.smokeTest.utils.*;
import org.openqa.selenium.By;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.interactions.Actions;
import org.openqa.selenium.support.ui.Select;


public class PlanFixture extends Assertions {

    private final DateFormatter dateFormats;
    private final JRubyScriptRunner scriptRunner;

    public PlanFixture() {
        super();
        this.dateFormats = new DateFormatter();
        this.scriptRunner = DriverFactory.getScriptRunner();
    }

    @com.thoughtworks.gauge.Step("Open plan <planName>")
    public void openPlan(String planName) throws Exception {
        this.driver.get(pathTo("programs"));
        waitForAjaxCallFinished();
        planLink(planName).click();
    }

    @com.thoughtworks.gauge.Step("Open plan <planName> in days view")
    public void openPlanInDaysView(String planName) throws Exception {
        openPlan(planName);
        switchToView("days");
    }

    // Public assertions
    private WebElement planLink(String planName) throws InterruptedException {
        scrollInToViewById(HelperUtils.nameToIdentifier(planName) + "_plan_link");
        return this.driver.findElement(By.id(HelperUtils.nameToIdentifier(planName) + "_plan_link"));
    }

    @com.thoughtworks.gauge.Step("Open <pageName> page")
    public void openPage(String pageName) throws InterruptedException {
        waitForElement(By.xpath("//a[text()=\"" + pageName.trim() + "\"]"));
        findElementByXpath("//a[text()=\"" + pageName.trim() + "\"]").click();
    }

    @com.thoughtworks.gauge.Step("Associate projects <projectNames> with program")
    public void associateProjectsWithProgram(String projectNames) throws Exception {
        waitForElement(By.id("new_program_project_id"));
        for (String projectName : projectNames.split(",")) {
            selectByText("new_program_project_id", projectName.trim());
            findElementById("new_program_project_submit").click();
        }
    }

    @com.thoughtworks.gauge.Step("Open plan <planName> via url")
    public void openPlanViaUrl(String planName) throws Exception {
        this.driver.get(this.getPlannerBaseUrl() + "/programs/" + HelperUtils.nameToIdentifier(planName) + "/plan");
    }

    @com.thoughtworks.gauge.Step("Open Project page in <programName>")
    public void openProjectViaUrl(String programName){
        this.driver.get(this.getPlannerBaseUrl() + "/programs/" + HelperUtils.nameToIdentifier(programName) + "/projects");
    }

    @com.thoughtworks.gauge.Step("Assert spinner on <objectiveName> objective")
    public void assertSpinnerOnObjective(String objectiveName) throws Exception {
        waitForElement(By.xpath("//img[@class=\"spinner\"]"));
        assertTrue(findElementsByXpath("//img[@class=\"spinner\"]").size() > 0);
    }

    @com.thoughtworks.gauge.Step("Assert spinner is not present on <objectiveName> objective")
    public void assertSpinnerIsNotPresentOnObjective(String objectiveName) throws Exception {
        Thread.sleep(2000);
        assertTrue(findElementsByXpath("//img[@class=\"spinner\"]").size() == 0);
    }

    @com.thoughtworks.gauge.Step("Assert that cards <cardNames> are present in view work table")
    public void assertThatCardsArePresentInViewWorkTable(String cardNames) throws Exception {
        for (String cardName : cardNames.split(",")) {
            assertTrue("Card not present", findElementsByXpath("//*[@class=\"card_link\" and text()=\"" + cardName.trim() + "\"]").size() > 0);
        }
    }

    @com.thoughtworks.gauge.Step("Assert that current page is page <pageNumber>")
    public void assertThatCurrentPageIsPage(String pageNumber) throws Exception {
        assertTrue("THE CURRENT PAGE IS NOT PAGE: " + pageNumber, findElementByXpath("//*[@class=\"current\"]").getText().trim().equals(pageNumber));
    }

    @com.thoughtworks.gauge.Step("Assert that cannot access the requested resource")
    public void assertThatCannotAccessTheRequestedResource() throws Exception {
        assertTrue("403 message is not displayed. ", findElementById("error").getText().trim().equals("Either the resource you requested does not exist or you do not have access rights to that resource."));
    }

    @com.thoughtworks.gauge.Step("Assert that cannot access the requested resource - plan")
    public void assertThatCannotAccessTheRequestedResourcePlan() throws Exception {
        assertTrue("403 message is not displayed. ", findElementByCssSelector(".error-box").getText().trim().equals("Either the resource you requested does not exist or you do not have access rights to that resource"));
    }

    @com.thoughtworks.gauge.Step("Open define done status page of project <projectName>")
    public void openDefineDoneStatusPageOfProject(String projectName) throws InterruptedException {
        waitForAjaxCallFinished();
        findElementByXpath("//*[text()=\"" + projectName + "\"]/../..//*[text()=\"define done status\"]").click();
        waitForElement(By.xpath("//*[text()=\"Define what done means for "+projectName.trim()+"\"]"));
    }

    @com.thoughtworks.gauge.Step("Map property <propertyName> value <propertyValue> to plan done status")
    public void mapPropertyValueToPlanDoneStatus(String propertyName, String propertyValue) throws Exception {
        selectByText("program_project_status_property_name", propertyName);
        waitForAjaxCallFinished();
        try {
            selectByText("program_project_done_status", propertyValue);
        }catch (Exception e){
            excecuteJs("window.location.reload();");
            selectByText("program_project_done_status", propertyValue);
        }
        findElementById("program_project_submit").click();
    }

    @com.thoughtworks.gauge.Step("Create objective <objectName> on <programName> starts on <startDateString> and ends on <endDateString> in days view")
    public void createObjectiveStartsOnAndEndsOnInDaysView(String objectName, String programName, String startDateString, String endDateString) throws Exception {
        String[] names = objectName.split(",");
        for (int i = 0; i < names.length; i++) {
            createObjectiveWithThetimeLine(programName, names[i].trim(), startDateString, endDateString, i);
            refreshPlanPage();
        }
    }

    //private method to create objective of the given time line
    private void createObjectiveWithThetimeLine(final String programName, final String objectiveName, String startDate, String EndDate, final int index) throws Exception {
        if ((objectiveName == null) || "".equals(objectiveName)) {
            throw new RuntimeException("Tried to create an objective with blank name");
        }
        scriptRunner.executeWithTestHelpers(new JRubyScriptRunner.ScriptBuilder() {
            public void build(JRubyScriptRunner.ScriptWriter scriptWriter) {
                scriptWriter.println("create_planned_objective(Program.find_by_name('" + programName + "'), :name => '" + objectiveName + "', :start_at => '" + startDate + "', :end_at => '" + EndDate + "', :vertical_position => " + index + ")");
            }
        });
    }

    @com.thoughtworks.gauge.Step("Assert that the timeline is centered on today")
    public void assertThatTheTimelineIsCenteredOnToday() throws Exception {
        //Needs additional wait for the timeline to appear. - hack
        waitForPageLoad(5000);
        int expectedPosition = findTodayPositionOnTimeline();
        int actualtodayPosition = excecuteJsWithindexreturn("return $('today_marker').positionedOffset()[0]");
        assertEquals("Timeline view is not centered as of today", expectedPosition, actualtodayPosition);
    }

    private int findTodayPositionOnTimeline() throws InterruptedException {
        int todayPosition = excecuteJsWithindexreturn("return timeline.mainViewContent.findTodayLocationOnTimeline()");
        return todayPosition;
    }

    @com.thoughtworks.gauge.Step("Switch to <viewName> view")
    public void switchToView(String viewName) throws Exception {
        super.switchToView(viewName);
    }

    @com.thoughtworks.gauge.Step("Assert granularity <granularity> highlighted")
    public void assertGranularityHighlighted(String granularity) throws Exception {
        try {
            refreshThePage();
            waitForPageLoad(3000);
            waitForElement(By.id(granularity.trim() + "_selector"));
            assertEquals("selected", findElementById(granularity.trim() + "_selector").getAttribute("class"));
        }catch (Exception e){
            refreshThePage();
            Thread.sleep(2000);
            assertEquals("selected", findElementById(granularity.trim() + "_selector").getAttribute("class"));
        }
    }

    @com.thoughtworks.gauge.Step("Click cancel button")
    public void clickCancelButton() throws Exception {
        waitForElement(By.xpath("//*[@value=\"Cancel\"]"));
        findElementByXpath(" //*[@value=\"Cancel\"]").click();
        waitForAjaxCallFinished();
    }

    @com.thoughtworks.gauge.Step("Remove project <projectName>")
    public void removeProject(String projectName) throws Exception {
        findElementByCssSelector("a[href*=\"" + projectName.toLowerCase().trim() + "/confirm_delete\"]").click();
    }

    @com.thoughtworks.gauge.Step("Click remove button")
    public void clickRemoveButton() throws Exception {
        findElementByXpath("//*[@value=\"Remove\"]").click();
    }

    @com.thoughtworks.gauge.Step("Assert that objective <objectiveName> starts on <objectiveStartDate> and ends on <objectiveEndDate> in days view")
    public void assertThatObjectiveStartsOnAndEndsOnInDaysView(final String objectiveName, String objectiveStartDate, String objectiveEndDate) throws Exception {
        waitForTimeLineStatusIsReady();
        WebElement objective = findElementById("objective_" + HelperUtils.nameToIdentifier(objectiveName));
        assertObjectiveBoundaries(objectiveStartDate, objectiveEndDate, objective);
    }

    private void assertObjectiveBoundaries(String startDate, String endDate, WebElement objective) throws Exception {
        String start = dateFormats.toHumanFormat(startDate);
        String end = dateFormats.toHumanFormat(endDate);

        int startX = xPositionFor(start);
        int endX = xPositionFor(end);

        int objectiveStart = getX(objective);
        int objectiveEnd = objectiveStart + widthOf(objective) - snapGridWidth();

        String failMessage = "The objective " + objective + " does not start at date " + start + ". Expected position " + startX + ", actual: " + objectiveStart;
        assertEquals(failMessage, startX, objectiveStart);

        failMessage = "The objective " + objective + " does not end through date " + end + ". Expected position " + endX + ", actual: " + objectiveEnd;
        assertEquals(failMessage, endX, objectiveEnd);
    }

    private int xPositionFor(String startDate) throws Exception {
        String dateString = dateFormats.toHumanFormat(startDate);
        int columnIndex = excecuteJsWithindexreturn(" return timeline.mainViewContent.findViewColumnByDate(\"" + dateString + "\").index");
        return columnIndex * columnWidth();
    }

    private int snapGridWidth() throws InterruptedException {
        return excecuteJsWithindexreturn("return timeline.mainViewContent.getSnapGridWidth()");
    }

    private int getX(WebElement elementStub) throws InterruptedException {
        return excecuteJsWithindexreturn("return $(\"" + elementStub.getAttribute("id") + "\").positionedOffset()[0]");
    }

    private Integer widthOf(WebElement elementStub) throws InterruptedException {
        return excecuteJsWithindexreturn(" return $(\"" + elementStub.getAttribute("id") + "\").getWidth()");
    }

    private Integer widthOfRightHandle(String objectiveName) throws InterruptedException {
        return excecuteJsWithindexreturn("return $j(\"#objective_"+HelperUtils.nameToIdentifier(objectiveName)+" .right_handle\").width()");
    }

    private int columnWidth() throws InterruptedException {
        return excecuteJsWithindexreturn(" return Timeline.GRIDS_PER_COLUMN[timeline.mainViewContent.currentGranularity]") * snapGridWidth();
    }

    @com.thoughtworks.gauge.Step("Assert that objective <objectiveName> cross weeks that begins from <startDateOfThisWeek> and week begins from <startDateOfAnotherWeek>")
    public void assertThatObjectiveCrossWeeksThatBeginsFromAndWeekBeginsFrom(String objectiveName, String startDateOfThisWeek, String startDateOfAnotherWeek) throws Exception {
        WebElement objective = findElementById("objective_" + HelperUtils.nameToIdentifier(objectiveName));
        int xCordinateOfBeginningOfObjective = getX(objective);
        int xCordinateOfEndOfObjective = xCordinateOfBeginningOfObjective + widthOf(objective);
        int xCordinateOfStartDateOfThisWeek = getX(findElementByXpath("//li[text()=\"" + dateFormats.getWeeksViewFormat(startDateOfThisWeek) + "\"]"));
        int xCordinateOfStartDateOfAnotherWeek = getX(findElementByXpath("//li[text()=\"" + dateFormats.getWeeksViewFormat(startDateOfAnotherWeek) + "\"]"));
        assertTrue((xCordinateOfBeginningOfObjective >= xCordinateOfStartDateOfThisWeek) && (xCordinateOfEndOfObjective > xCordinateOfStartDateOfAnotherWeek));
    }

    @com.thoughtworks.gauge.Step("Assert links <linkNames> present for project <project>")
    public void assertLinksPresentForProject(String linkNames, String project) throws Exception {
        for (String link : linkNames.split(",")) {
            assertTrue("link" + link + " is not present for project " + project, findElementsByLinkText(link.trim()).size() > 0);
        }
    }

    @com.thoughtworks.gauge.Step("Assert that cannot see property <propertyName> in mapping dropdown list")
    public void assertThatCannotSeePropertyInMappingDropdownList(String propertyName) throws Exception {
        assertFalse(findElementsByXpath("//*[@value=\"" + propertyName + "\"]").size() > 0);
    }

    @com.thoughtworks.gauge.Step("Select property <propertyName> and assert values <propertyValues> in mapping dropdown list")
    public void selectPropertyAndAssertValuesInMappingDropdownList(String propertyName, String propertyValues) throws Exception {
        Select dropdown = new Select(driver.findElement(By.id("program_project_status_property_name")));
        //Hack to make the dropdown disabled
        dropdown.selectByValue(propertyName.trim());
        dropdown.selectByValue(propertyName);
        waitForPageLoad(3000);
        for (String value : propertyValues.split(",")) {
            assertTrue(findElementsByXpath("//*[@value=\"" + value.trim() + "\"]").size() > 0);
        }
    }

    @com.thoughtworks.gauge.Step("Assert save button disabled with message <message>")
    public void assertSaveButtonDisabledWithMessage(String message) throws Exception {
        waitForPageLoad(1000);
        assertEquals(findElementById("card_types").getText().trim(), message);
    }

    @com.thoughtworks.gauge.Step("Assert indication for empty timeline view does not appear")
    public void assertIndicationForEmptyTimelineViewDoesNotAppear() throws Exception {
        assertFalse("The indication message for empty timeline view found on page! ", findElementById("informing_message_box").isDisplayed());
    }

    @com.thoughtworks.gauge.Step("Assert indication for empty timeline view appears")
    public void assertIndicationForEmptyTimelineViewAppears() throws Exception {
        assertTrue("cannot find indication message for empty timeline view!", findElementsById("informing_message_box").size() > 0);
    }

    @com.thoughtworks.gauge.Step("Create objective <objectiveName> on <programName> starts on <startDate> and ends on <endDate> in months view")
    public void createObjectiveStartsOnAndEndsOnInMonthsView(String objectiveName, String programName, String startDate, String endDate) throws Exception {
        String[] names = objectiveName.split(",");
        for (int i = 0; i < names.length; i++) {
            createObjectiveWithThetimeLine(programName, names[i].trim(), startDate, endDate, i);
            refreshPlanPage();
        }
    }

    @com.thoughtworks.gauge.Step("Drag objective <objectiveName> from end date <objectiveEndDate> to <targetEndDate> in months view")
    public void dragObjectiveFromEndDateToInMonthsView(String objectiveName, String objectiveEndDate, String targetEndDate) throws Exception {
        int daysDifference = dateFormats.getDaysDifference(objectiveEndDate, targetEndDate);
        int targetXOffset = daysDifference * snapGridWidth();
        WebElement objectiveRightHandle = findElementById("objective_"+HelperUtils.nameToIdentifier(objectiveName)).findElement(By.xpath("//*[@class=\"right_handle\"]"));
        new Actions(this.driver)
                .dragAndDropBy(objectiveRightHandle,targetXOffset,0)
                .build()
                .perform();
        Thread.sleep(5000L);
    }

    @com.thoughtworks.gauge.Step("Move objective <objectiveName> from <objectiveStartDate> to start on <targetStartDate> in months view")
    public void moveObjectiveFromToStartOnInMonthsView(String objectiveName, String objectiveStartDate, String targetStartDate) throws Exception {
        WebElement objectiveLeftHandle = findElementById("objective_"+HelperUtils.nameToIdentifier(objectiveName)).findElement(By.xpath("//*[@class=\"left_handle\"]"));
        int daysDiff = dateFormats.getDaysDifference(objectiveStartDate, targetStartDate);
        int targetXOffset = daysDiff * snapGridWidth();
        new Actions(this.driver)
                .dragAndDropBy(objectiveLeftHandle,targetXOffset,0)
                .build()
                .perform();
        Thread.sleep(5000L);
    }

    @com.thoughtworks.gauge.Step("Refresh plan page")
    public void refreshPlanPage() throws Exception {
        findElementByLinkText("Plan").click();
    }

    @com.thoughtworks.gauge.Step("Assert that objective <objectiveName> starts on <startDate> and ends on <endDate> in months view")
    public void assertThatObjectiveStartsOnAndEndsOnInMonthsView(String objectiveName, String startDate, String endDate) throws Exception {
        int expectedObjectiveStartDateX = getXForObjectiveStartDateInMonthView(startDate);
        int expectedObjectiveEndDateX = getXForObjectiveEndDateInMonthView(endDate);
        WebElement objective=findElementById("objective_"+HelperUtils.nameToIdentifier(objectiveName));
        int actualObjectiveStartDateX = getX(objective);
        int actualObjectiveEndDateX = actualObjectiveStartDateX + widthOf(objective);
        String startDateFailMessage = "The objective " + objectiveName + " does not start at date " + startDate + ". Expected position " + expectedObjectiveStartDateX + ", actual: " + actualObjectiveStartDateX;
        String endDateFailMessage = "The objective " + objectiveName + " does not end at date " + endDate + ". Expected position " + expectedObjectiveEndDateX + ", actual: " + actualObjectiveEndDateX;
        waitForTimeLineStatusIsReady();
        assertEquals(endDateFailMessage, expectedObjectiveEndDateX, actualObjectiveEndDateX);
        assertEquals(startDateFailMessage, expectedObjectiveStartDateX, actualObjectiveStartDateX);
    }

    private int getXForObjectiveStartDateInMonthView(String date) throws Exception {
        waitForElement(By.xpath("//*[text()=\""+dateFormats.getMonthViewFormat(date)+"\"]"));
        int objectiveStartX = getX(findElementByXpath("//*[text()=\""+dateFormats.getMonthViewFormat(date)+"\"]")) + ((dateFormats.getDayOfMonth(date) - 1) * snapGridWidth());
        return objectiveStartX;
    }

    private int getXForObjectiveEndDateInMonthView(String date) throws Exception {
        //hack
        int objectiveEndX = getX(findElementByXpath("//*[text()=\""+dateFormats.getMonthViewFormat(date)+"\"]")) + ((dateFormats.getDayOfMonth(date))  * snapGridWidth());
        return objectiveEndX;
    }

    @com.thoughtworks.gauge.Step("Drag the <handle> of objective <objective> to day <day> of the month to <direction> begins from <date>")
    public void dragTheOfObjectiveToDayOfTheMonthBeginsFrom(String handle, String objective, Integer day, String direction ,String date) throws Exception {
        waitForTimeLineStatusIsReady();
        String startMonth = dateFormats.getMonthViewFormat(date);
        int destY = getY(findElementById("objective_"+HelperUtils.nameToIdentifier(objective)));
        if (handle.equals("end date")) {
            int destX = getX(findElementByXpath("//*[text()=\""+startMonth+"\"]")) + xOffSetForTheDayInMonth(day+2);
            if (direction.equals("left")){
                dragDropObjectiveRightHandle(objective, -destX, destY);
            }else if(direction.equals("right")){
                dragDropObjectiveRightHandle(objective, destX, destY);
            }
        } else if (handle.equals("start date")) {
            //day -1
            int destX = getX(findElementByXpath("//*[text()=\""+startMonth+"\"]")) + xOffSetForTheDayInMonth(day);
            if(direction.equals("left")){
                dragDropObjectiveLeftHandle(objective, -destX, destY);
            }else if(direction.equals("right")){
                dragDropObjectiveLeftHandle(objective, destX, destY);
            }
        }
    }

    private int getY(WebElement elementStub) throws InterruptedException {
        return excecuteJsWithindexreturn("return $(\"" + elementStub.getAttribute("id") + "\").positionedOffset()[1]");

    }

    public int xOffSetForTheDayInMonth(int dayInThisMonth) throws InterruptedException {
        int borderOffset = 1;
        return (monthDayWidth() * dayInThisMonth) - borderOffset;
    }

    private int monthDayWidth() throws InterruptedException {
        return excecuteJsWithindexreturn(" return Timeline.GRID_SIZE['months']");
    }

    private void dragDropObjectiveRightHandle(String objectiveName, int objectiveToX, int objectiveToY) throws InterruptedException {
        WebElement objective = findElementById("objective_" + HelperUtils.nameToIdentifier(objectiveName));
        int objectiveStart = getX(objective);
        int objectiveEnd = objectiveStart + widthOf(objective) - snapGridWidth();
        objectiveToX = objectiveToX - (objectiveEnd +widthOfRightHandle(objectiveName));
        WebElement objectiveRightHandle = rightHandleOfObjective(objectiveName);
        new Actions(this.driver)
                .dragAndDropBy(objectiveRightHandle,objectiveToX,objectiveToY)
                .build()
                .perform();
        Thread.sleep(5000L);
    }

    private void dragDropObjectiveLeftHandle(String objectiveName, int objectiveToX, int objectiveToY) throws InterruptedException {
        WebElement leftHandleOfObjective = leftHandleOfObjective(objectiveName);
        new Actions(this.driver)
                .dragAndDropBy(leftHandleOfObjective,objectiveToX,objectiveToY)
                .build()
                .perform();
        Thread.sleep(5000L);
    }

    private WebElement rightHandleOfObjective(String objectiveName) {
        return findElementByXpath("//*[@id=\"objective_"+HelperUtils.nameToIdentifier(objectiveName)+"\"]/span[4]");
    }

    private WebElement leftHandleOfObjective(String objectiveName) {
        return findElementByXpath("//*[@id=\"objective_"+HelperUtils.nameToIdentifier(objectiveName)+"\"]/span[1]");
    }

    @com.thoughtworks.gauge.Step("Click mingle logo")
    public void clickMingleLogo() throws Exception {
        findElementById("logo_link").click();
    }

    @com.thoughtworks.gauge.Step("Verify alert is not displayed in <objectiveName> objective")
    public void verifyAlertIsNotDisplayedInObjective(String objectiveName) throws Exception {
        WebElement objectiveElement = findElementById("objective_"+HelperUtils.nameToIdentifier(objectiveName));
        assertTrue("Alert is present", objectiveElement.findElements(By.className("late")).size() == 0);
    }

    @com.thoughtworks.gauge.Step("Verify alert is displayed in <objectiveName> objective")
    public void verifyAlertIsDisplayedInObjective(String objectiveName) throws Exception {
        waitForPageLoad(2000);
        WebElement objectiveElement = findElementById("objective_"+HelperUtils.nameToIdentifier(objectiveName));
        assertTrue("Alert is not present", objectiveElement.findElements(By.className("late")).size() > 0);
    }

    @com.thoughtworks.gauge.Step("Assert links not present in objective popup <links>")
    public void assertLinksNotPresentInObjectivePopup(String links) throws Exception {
        for (String link : links.split(",")) {
            assertTrue("link" + link + " is present on popup", findElementById("objective_details_contents").findElements(By.xpath("//a[text()=\""+link.trim()+"\"]")).size() == 0);
        }
    }

    @com.thoughtworks.gauge.Step("Edit done status from <fromValue> for project <projectName>")
    public void editDoneStatusFromForProject(String fromValue, String projectName) throws Exception {
        findElementByXpath("//a[text()=\"Status >= "+fromValue+"\"]").click();
    }

    @com.thoughtworks.gauge.Step("Assert that cannot see planner info on card")
    public void assertThatCannotSeePlannerInfoOnCard() throws Exception {
        assertFalse(findElementsById("programs-container").size() > 0);
    }

    @com.thoughtworks.gauge.Step("The rounded default plan start date and and end dates are <startDate> <endDate>")
    public void theRoundedDefaultPlanStartDateAndAndEndDatesAre(String startDate, String endDate) throws Exception {
        openPlan("New Program");
        openPlanSettingsPopup();
        waitForElement(By.id("edit_plan_form"));
        assertEquals(startDate, findElementByXpath("//*[@name=\"plan[start_at]\"]").getAttribute("value"));
        assertEquals(endDate, findElementByXpath("//*[@name=\"plan[end_at]\"]").getAttribute("value"));
    }

    @com.thoughtworks.gauge.Step("Open plan settings popup")
    public void openPlanSettingsPopup() throws InterruptedException {
        openPage("Plan");
        findElementById("plan_edit").click();
    }

    @com.thoughtworks.gauge.Step("Click cancel link")
    public void clickCancelLink() throws InterruptedException {
        waitForElement(By.id("edit_plan_form"));
        findElementById("dismiss_lightbox_button").click();
    }

    @com.thoughtworks.gauge.Step("Open <tabName> tab")
    public void openTab(String tabName) throws Exception {
        findElementByXpath("//*[text()=\""+tabName+"\"]").click();
    }

    @com.thoughtworks.gauge.Step("Assert that objective <objectiveName> is present")
    public void assertThatObjectiveIsPresent(String objectiveName) throws InterruptedException {
        assertTrue("Feature " + objectiveName + " is not found on current page!", findElementsById("objective_"+HelperUtils.nameToIdentifier(objectiveName)).size()>0);
    }

    @com.thoughtworks.gauge.Step("Assert link url of <linkText> is <linkUrl>")
    public void assertLinkUrlOfIs(String linkText, String linkUrl) throws Exception {
        String actualUrl = findElementByLinkText(linkText).getAttribute("href");
        String expectedUrl = this.getPlannerBaseUrl() + linkUrl;
        assertEquals("Link does not have correct url", expectedUrl, actualUrl);
    }

    @com.thoughtworks.gauge.Step("Assert work not done filter set for objective <objectiveName> for property <expectdProperty>")
    public void assertWorkNotDoneFilterSetForObjectiveForProperty(String objectiveName, String expectdProperty) throws Exception {
        waitForElement(By.id("filter_widget_cards_filter_0_values_drop_link"));
        String actualOperator = findElementById("filter_widget_cards_filter_0_operators_drop_link").getText();
        String actualValue=findElementById("filter_widget_cards_filter_0_values_drop_link").getText();
        assertEquals("Filter does not have expected operator", "is not", actualOperator);
        assertEquals("Filter does not have expected value", "Done", actualValue);
    }
    @com.thoughtworks.gauge.Step("Assert <linkMessage> link is present for <cardNames>")
    public void assertLinkIsPresentFor(String linkMessage, String cardNames) throws Exception {
        for (String cardName : cardNames.split(",")) {
            assertEquals(linkMessage,findElementByXpath("//*[text()=\""+cardName.trim()+"\"]/../..//*[@class=\"status\"]//a").getText());
        }
    }

    @com.thoughtworks.gauge.Step("Click on <linkMessage> link for card <cardName>")
    public void clickOnLinkForCard(String linkMessage, String cardName) throws Exception {
        findElementByXpath("//*[text()=\""+cardName.trim()+"\"]/../..//*[@class=\"status\"]//a").click();
    }

    @com.thoughtworks.gauge.Step("Assert no work items in view work page")
    public void assertNoWorkItemsInViewWorkPage() throws Exception {
        assertTrue("Work items are mapped", findElementsByXpath("//*[contains(text(),\"There are no work items that match the current filter –\")]").size()>0);
    }

    @com.thoughtworks.gauge.Step("Assert that objective <objectiveName> is within the week of <startDateOfThisWeek>")
    public void assertThatObjectiveIsWithinTheWeekOf(String objectiveName, String startDateOfThisWeek) throws Exception {
        refreshPlanPage();
        WebElement objective = findElementById("objective_"+HelperUtils.nameToIdentifier(objectiveName));
        String startDate = dateFormats.getWeeksViewFormat(startDateOfThisWeek);

        int objectiveStart = getX(objective);
        int objectiveEnd = objectiveStart + widthOf(objective);
        int weekStart = getX(findElementByXpath("//li[contains(text(),\""+startDate+"\")]"));
        int weekEnd = weekStart + columnWidth();

        boolean startsOnOrAfter = objectiveStart >= weekStart;
        boolean endsOnOrBefore = objectiveEnd <= weekEnd;

        String failStart = "Feature " + objectiveName + " does not start on or after date: " + startDateOfThisWeek + ". objectiveStart: " + objectiveStart + ", weekStart: " + weekStart;
        String failEnd = "Feature " + objectiveName + " does not end on or before end of week. objectiveEnd: " + objectiveEnd + ", weekEnd: " + weekEnd;

        assertTrue(failStart, startsOnOrAfter);
        assertTrue(failEnd, endsOnOrBefore);
    }

    @com.thoughtworks.gauge.Step("Assert that objective <objectiveName1> is longer than objective <objectiveName2>")
    public void assertThatObjectiveIsLongerThanObjective(String objectiveName1, String objectiveName2) throws Exception {
        assertTrue(widthOf(findElementById("objective_"+HelperUtils.nameToIdentifier(objectiveName1))) > widthOf(findElementById("objective_"+HelperUtils.nameToIdentifier(objectiveName2))));
    }

    @com.thoughtworks.gauge.Step("Assert that objective <objectiveName> only spans entire week of <startDateOfThisWeek>")
    public void assertThatObjectiveOnlySpansEntireWeekOf(String objectiveName, String startDateOfThisWeek) throws Exception {
        WebElement objective = findElementById("objective_"+HelperUtils.nameToIdentifier(objectiveName));
        String startDate = dateFormats.getWeeksViewFormat(startDateOfThisWeek);

        int objectiveStart = getX(objective);
        int objectiveWidth = widthOf(objective);
        int weekStart = getX(findElementByXpath("//li[contains(text(),\""+startDate+"\")]"));

        String failStart = "Feature " + objectiveName + " does not start on or after date: " + startDateOfThisWeek + ". objectiveStart: " + objectiveStart + ", weekStart: " + weekStart;
        String failDuration = "Feature " + objectiveName + " does not span a full week. weekLengthInPixels: " + columnWidth() + ", objectiveLength: " + objectiveWidth;

        assertEquals(failStart, weekStart, objectiveStart);
        assertEquals(failDuration, columnWidth(), objectiveWidth);
    }

    @com.thoughtworks.gauge.Step("Drag the end date of objective <objectiveName> to day <dayInThisWeek> of the week begins from <startDateOfStartWeek>")
    public void dragTheEndDateOfObjectiveToDayOfTheWeekBeginsFrom(String objectiveName, Integer dayInThisWeek, String startDateOfStartWeek) throws Exception {
        waitForTimeLineStatusIsReady();
        String startWeek = dateFormats.getWeeksViewFormat(startDateOfStartWeek);
        int destX = getX(findElementByXpath("//li[contains(text(),\""+startWeek+"\")]")) + xOffSetForTheDayInWeek(dayInThisWeek);
        int destY = getY(findElementById("objective_"+HelperUtils.nameToIdentifier(objectiveName)));
        dragDropObjectiveRightHandle(objectiveName, destX, destY);
    }

    public int xOffSetForTheDayInWeek(int dayInThisWeek) throws InterruptedException {
        int borderOffset = 1;
        return (weekDayWidth() * dayInThisWeek) - borderOffset;
    }

    private int weekDayWidth() throws InterruptedException {
        return excecuteJsWithindexreturn("return Timeline.GRID_SIZE['weeks']");
    }

    @com.thoughtworks.gauge.Step("Drag the start date of objective <objectiveName> to day <dayInThisWeek> of the week begins from <startDateOfStartWeek>")
    public void dragTheStartDateOfObjectiveToDayOfTheWeekBeginsFrom(String objectiveName, Integer dayInThisWeek, String startDateOfStartWeek) throws Exception {
        waitForTimeLineStatusIsReady();
        String startWeek = dateFormats.getWeeksViewFormat(startDateOfStartWeek);
        int destX = getX(findElementByXpath("//li[contains(text(),\""+startWeek+"\")]")) + xOffSetForTheDayInWeek(dayInThisWeek);
        int destY = getY(findElementById("objective_"+HelperUtils.nameToIdentifier(objectiveName)));
        dragDropObjectiveLeftHandle(objectiveName, destX, destY);
    }

    @com.thoughtworks.gauge.Step("Move objective <objectiveName> to start on the day <dayInThisWeek> of the week begin from <newStartDate>")
    public void moveObjectiveToStartOnTheDayOfTheWeekBeginFrom(final String objectiveName, Integer dayInThisWeek, String newStartDate) throws Exception {
        waitForTimeLineStatusIsReady();
        String startWeek = dateFormats.getWeeksViewFormat(newStartDate);
        WebElement objective = findElementById("objective_"+HelperUtils.nameToIdentifier(objectiveName));
        int originX = getX(objective);
        int destX = getX(findElementByXpath("//li[contains(text(),\""+startWeek+"\")]")) + xOffSetForTheDayInWeek(dayInThisWeek);
        int moveBy = destX - originX;
        dragDropObjectiveLeftHandle(objectiveName,moveBy,getY(objective));
    }

    @com.thoughtworks.gauge.Step("Assert that the text present in page navigator is <expectedText>")
    public void assertThatTheTextPresentInPageNavigatorIs(String expectedText) throws Exception {
        assertTrue("Cannot find the expected text: " + expectedText + " in page navigation bar!", findElementById("page_navigator").getText().contains(expectedText));
    }

    @com.thoughtworks.gauge.Step("Assert objective popup is present")
    public void assertObjectivePopupIsPresent() throws Exception {
        assertTrue("Feature popup not present", findElementsById("objective_popup_details").size()>0);
    }

    @com.thoughtworks.gauge.Step("Click on objective name <objectiveName> on popup")
    public void clickOnObjectiveNameOnPopup(String objectiveName) throws Exception {
        waitForPageLoad(1000);
        excecuteJs("(document.evaluate(\"//*[@id='objective_date']/..//a\",document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue) .click()");
    }

    @com.thoughtworks.gauge.Step("Assert value statement <valueStatement> on popup")
    public void assertValueStatementOnPopup(String valueStatement) throws Exception {
        waitForPageLoad(2000);
        assertTrue(excecuteJsWithStringretun("return ((document.getElementsByClassName('objective_value_statement')[0]).innerHTML)").trim().contains(valueStatement));
        findElementById("cancel_delete").click();
    }

    @com.thoughtworks.gauge.Step("Assert that the first month on timeline page is <monthName>")
    public void assertThatTheFirstMonthOnTimelinePageIs(String monthName) throws Exception {
        String failMessage = "The first month on Timeline page is: " + findElementById("0_column").getText() + ", Not: " + monthName;
        assertEquals(failMessage, findElementById("0_column").getText(), monthName);
    }

    @com.thoughtworks.gauge.Step("Assert that the first week on timeline page is <weekName>")
    public void assertThatTheFirstWeekOnTimelinePageIs(String weekName) throws Exception {
        String failMessage = "The first week on Timeline page is: " + findElementById("0_column").getText() + ", Not: " + weekName;
        assertEquals(failMessage, findElementById("0_column").getText(), weekName);
    }

    @com.thoughtworks.gauge.Step("Assert that objective <objectiveName> starts on <expectedStartDate> and ends on <expectedEndDate> in weeks view")
    public void assertThatObjectiveStartsOnAndEndsOnInWeeksView(String objectiveName, String expectedStartDate, String expectedEndDate) throws Exception {
        WebElement objective = findElementById("objective_"+HelperUtils.nameToIdentifier(objectiveName));
        int actualObjectiveStartPosition = getX(objective);
        int actualObjectiveEndPosition = actualObjectiveStartPosition + widthOf(objective);
        String expectedStartDateWeeksFormat = dateFormats.getWeeksViewFormat(expectedStartDate);
        int expectedObjectiveStartPosition = getX(findElementByXpath("//li[contains(text(),\""+expectedStartDateWeeksFormat+"\")]")) + (snapGridWidth() * (dateFormats.getDayOfWeek(expectedStartDate) - 1));

        String expectedEndDateWeeksFormat = dateFormats.getWeeksViewFormat(expectedEndDate);
        int expectedObjectiveEndPosition = getX(findElementByXpath("//li[contains(text(),\""+expectedEndDateWeeksFormat+"\")]")) + (snapGridWidth() * dateFormats.getDayOfWeek(expectedEndDate));

        assertEquals("The objective does NOT start at: " + expectedStartDate, expectedObjectiveStartPosition, actualObjectiveStartPosition);
        assertEquals("The objective does NOT end at: " + expectedEndDate, expectedObjectiveEndPosition, actualObjectiveEndPosition);
    }

    @com.thoughtworks.gauge.Step("Scroll to the end of the plan")
    public void scrollToTheEndOfThePlan() throws Exception {
        waitForTimeLineStatusIsReady();
        WebElement viewSelected = findElementByXpath("//*[@class='viewport selected']");
        int widthOfSlider = excecuteJsWithindexreturn("return (document.getElementsByClassName('viewport selected')[0]).getWidth()");
        int widthOfView = excecuteJsWithindexreturn("return (document.getElementsByClassName('overview')[0]).getWidth()");
        int yOffSet = excecuteJsWithindexreturn("return (document.getElementsByClassName('overview')[0]).positionedOffset()[1]");
        int targetX = widthOfView - widthOfSlider ;
        new Actions(this.driver)
                .dragAndDropBy(viewSelected,targetX,yOffSet)
                .build()
                .perform();
        Thread.sleep(5000L);
        waitForTimeLineStatusIsReady();
    }

    @com.thoughtworks.gauge.Step("Assert that the last month on timeline page is <monthName>")
    public void assertThatTheLastMonthOnTimelinePageIs(String monthName) throws Exception {
        String lastMonthOnTimeline = excecuteJsWithStringretun("return $$('#date_header li').last().getText()");
        String failMessage = "Ths last month on Timeline page is: " + lastMonthOnTimeline + " , is NOT: " + monthName;
        assertEquals(failMessage, monthName, lastMonthOnTimeline);
    }

    @com.thoughtworks.gauge.Step("Assert that the last week on timeline page is <weekName>")
    public void assertThatTheLastWeekOnTimelinePageIs(String weekName) throws Exception {
        String lastWeekOnTimelinePage = excecuteJsWithStringretun("return $$('#date_header li').last().getText()");
        String failMessage = "The last month on Timeline page is: " + lastWeekOnTimelinePage + ", is NOT: " + weekName;
        assertEquals(failMessage, weekName, lastWeekOnTimelinePage);
    }

    @com.thoughtworks.gauge.Step("Drag objective <objectiveName> from start date <objectiveStartDate> to <targetStartDate> in months view")
    public void dragObjectiveFromStartDateToInMonthsView(String objectiveName, String objectiveStartDate, String targetStartDate) throws Exception {
        int daysDifference = dateFormats.getDaysDifference(objectiveStartDate, targetStartDate);
        int targetXOffset = daysDifference * snapGridWidth();
        WebElement objectiveLeftHandle = findElementById("objective_"+HelperUtils.nameToIdentifier(objectiveName)).findElement(By.xpath("//*[@class=\"left_handle\"]"));
        new Actions(this.driver)
                .dragAndDropBy(objectiveLeftHandle,targetXOffset,0)
                .build()
                .perform();
        Thread.sleep(5000L);
        waitForAjaxCallFinished();
    }

    @com.thoughtworks.gauge.Step("Create objective <objectName> on <programName> starts on <startDateString> and ends on <endDateString> in days view at position <verticalPosition>")
    public void createObjectiveStartsOnAndEndsOnInDaysViewAtPosition(String objectName, String programName, String startDateString, String endDateString, final int verticalPosition ) throws Exception {
        String[] names = objectName.split(",");
        for (int i = 0; i < names.length; i++) {
            createObjectiveWithThetimeLine(programName, names[i].trim(), startDateString, endDateString, verticalPosition + i);
            refreshPlanPage();
        }
    }
}
