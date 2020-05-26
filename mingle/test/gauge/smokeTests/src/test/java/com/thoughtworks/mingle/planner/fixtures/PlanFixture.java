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

import static java.lang.Integer.parseInt;
import static junit.framework.Assert.assertEquals;
import static junit.framework.Assert.assertTrue;
import static org.junit.Assert.assertFalse;
import net.sf.sahi.client.Browser;
import net.sf.sahi.client.ElementStub;

import com.thoughtworks.mingle.planner.smokeTest.util.Assertions;
import com.thoughtworks.mingle.planner.smokeTest.util.DateFormatter;
import com.thoughtworks.mingle.planner.smokeTest.util.HelperUtils;

public class PlanFixture extends Assertions {

    private final DateFormatter dateFormats;

    public PlanFixture(Browser browser) {
        super(browser);
        this.dateFormats = new DateFormatter();
    }

    public void editPlanName(String newplanName) throws Exception {
        browser.textbox("plan_name").setValue(newplanName);
    }

    @com.thoughtworks.gauge.Step("Open plan <planName>")
	public void openPlan(String planName) throws Exception {
        browser.navigateTo(this.pathTo("programs"), true);
        planLink(planName).click();
    }

    @com.thoughtworks.gauge.Step("Open plan <planName> in days view")
	public void openPlanInDaysView(String planName) throws Exception {
        openPlan(planName);
        switchToView("days");
    }

    @com.thoughtworks.gauge.Step("Open plan <planName> via url")
	public void openPlanViaUrl(String planName) throws Exception {
        browser.navigateTo(this.getPlannerBaseUrl() + "/programs/" + HelperUtils.nameToIdentifier(planName) + "/plan");
    }

    @com.thoughtworks.gauge.Step("Associate projects <projectNames> with program")
	public void associateProjectsWithProgram(String projectNames) throws Exception {
        for (String projectName : projectNames.split(",")) {
            browser.select("new_program_project_id").choose(projectName);
            browser.submit("Add").click();
        }
    }

    public void clickAddProjectsLink() {
        browser.click(browser.link("add projects"));
    }

    @com.thoughtworks.gauge.Step("Map property <propertyName> value <propertyValue> to plan done status")
	public void mapPropertyValueToPlanDoneStatus(String propertyName, String propertyValue) throws Exception {
        browser.select("program_project[status_property_name]").choose(propertyName);
        waitForAjaxCallFinished();
        browser.select("program_project[done_status]").choose(propertyValue);
        browser.submit("Save").click();
    }

    public void clickPlanNameNextToMingleLogo(String planName) throws Exception {
        browser.click(browser.link("header_plan_name"));
        waitForAjaxCallFinished();
    }

    @com.thoughtworks.gauge.Step("Open <pageName> page")
	public void openPage(String pageName) {
        browser.link(pageName).click();
    }

    @com.thoughtworks.gauge.Step("Open plan settings popup")
	public void openPlanSettingsPopup() {
        openPage("Plan");
        browser.link("plan_edit").click();
    }

    @com.thoughtworks.gauge.Step("Open <tabName> tab")
	public void openTab(String tabName) throws Exception {
        browser.link(tabName).click();
    }

    @com.thoughtworks.gauge.Step("Open define done status page of project <projectName>")
	public void openDefineDoneStatusPageOfProject(String projectName) {
        browser.link("define done status").near(browser.cell(projectName)).click();
    }

    @com.thoughtworks.gauge.Step("Click remove button")
	public void clickRemoveButton() throws Exception {
        browser.submit("Remove").click();
    }

    @com.thoughtworks.gauge.Step("Click cancel button")
	public void clickCancelButton() throws Exception {
        browser.button("Cancel").click();
        waitForAjaxCallFinished();
    }

    @com.thoughtworks.gauge.Step("Click cancel link")
	public void clickCancelLink() {
        browser.link(HelperUtils.returnLinkText(browser, "Cancel")).click();
    }

    public void clickEdit() {
        browser.click(browser.link("Edit"));
    }

    public void clickPreview() {
        browser.click(browser.link("Preview"));
    }

    public void clickSaveButton() throws Exception {
        browser.submit("Save").click();
    }

    @com.thoughtworks.gauge.Step("Click mingle logo")
	public void clickMingleLogo() throws Exception {
        browser.link("logo_link").click();
    }

    @com.thoughtworks.gauge.Step("Remove project <projectName>")
	public void removeProject(String projectName) throws Exception {
        browser.link("Remove").near(browser.cell(projectName)).click();
    }

    public void navigateToWorkPageWithFilter(String planName, String filter) throws Exception {
        browser.navigateTo(this.getPlannerBaseUrl() + "/plans/" + HelperUtils.nameToIdentifier(planName) + "/work?filters=" + filter);
    }

    // Public assertions

    private ElementStub planLink(String planName) {
        return browser.link("Plan").near(browser.heading2(planName));
    }

    @com.thoughtworks.gauge.Step("Assert that the plan begins on <expectedStartDate> and ends on <expectedEndDate>")
	public void assertThatThePlanBeginsOnAndEndsOn(String expectedStartDate, String expectedEndDate) throws Exception {
        assertTrue(browser.accessor("$$('#date_header li').first()").containsText(dateFormats.toHumanFormat(expectedStartDate)));
        assertTrue(browser.accessor("$$('#date_header li').last()").containsText(dateFormats.toHumanFormat(expectedEndDate)));
    }

    @com.thoughtworks.gauge.Step("Assert that cannot see property <propertyName> in mapping dropdown list")
	public void assertThatCannotSeePropertyInMappingDropdownList(String propertyName) throws Exception {
        assertFalse(browser.option(propertyName).exists());
    }

    @com.thoughtworks.gauge.Step("Assert that cannot see planner info on card")
	public void assertThatCannotSeePlannerInfoOnCard() throws Exception {
        assertFalse(browser.div("programs-container").isVisible());

    }

    @com.thoughtworks.gauge.Step("Assert that cannot access the requested resource")
	public void assertThatCannotAccessTheRequestedResource() throws Exception {
        assertTrue("403 message is not displayed. ", browser.div("error-box").text().contains("Either the resource you requested does not exist or you do not have access rights to that resource"));
    }

    @com.thoughtworks.gauge.Step("Assert that the text present in page navigator is <expectedText>")
	public void assertThatTheTextPresentInPageNavigatorIs(String expectedText) throws Exception {
        assertTrue("Cannot find the expected text: " + expectedText + " in page navigation bar!", browser.byId("page_navigator").containsText(expectedText));
    }

    @com.thoughtworks.gauge.Step("Assert indication for empty timeline view appears")
	public void assertIndicationForEmptyTimelineViewAppears() throws Exception {
        assertTrue("cannot find indication message for empty timeline view!", browser.div("informing_message_box").isVisible());
    }

    @com.thoughtworks.gauge.Step("Assert indication for empty timeline view does not appear")
	public void assertIndicationForEmptyTimelineViewDoesNotAppear() throws Exception {
        assertFalse("The indication message for empty timeline view found on page! ", browser.div("informing_message_box").isVisible());
    }

    public void assertRowInEventsListHasText(Integer rowNumber, String project, String cardNumber, String cardName, String eventDescription) throws Exception {
        assertEquals("#" + cardNumber + " " + cardName, getTextWithCssLocator(".event .card_link", rowNumber - 1));
        assertEquals(eventDescription, getTextWithCssLocator(".event .event_changes", rowNumber - 1));
    }

    public void assertOnDashboardTheHighchartForProjectHasWorkItemsAndItsXAxisOrderIs(String projectName, String workIteamsCount, Integer orderFromUI) throws Exception {
        int xAxisOrder = orderFromUI - 1; // the X-axis order starts from 0
        assertEquals(projectName, browser.fetch("$A(window.chart.series.first().data)[" + xAxisOrder + "].category"));
        assertEquals(workIteamsCount, browser.fetch("$A(window.chart.series.first().data)[" + xAxisOrder + "].y"));
    }

    public void assertThatPageContentContainsWorkByProjectCharts(String expectedChartCount) throws Exception {
        String actualCount = browser.fetch("$$('.work_by_project').length");
        assertEquals(expectedChartCount, actualCount);
    }

    @com.thoughtworks.gauge.Step("Assert that current page is page <pageNumber>")
	public void assertThatCurrentPageIsPage(String pageNumber) throws Exception {
        assertTrue("THE CURRENT PAGE IS NOT PAGE: " + pageNumber, browser.span("current").in(browser.div("pagination")).getText().equals(pageNumber));
    }

    @com.thoughtworks.gauge.Step("Assert work not done filter set for objective <objectiveName> for property <expectdProperty>")
	public void assertWorkNotDoneFilterSetForObjectiveForProperty(String objectiveName, String expectdProperty) throws Exception {
        String actualOperator = browser.link(0).in(browser.div("operator")).near(browser.link(expectdProperty)).getText();
        String actualValue = browser.link(0).in(browser.div("second-operand")).near(browser.link(expectdProperty)).getText();

        assertEquals("Filter does not have expected operator", "is not", actualOperator);
        assertEquals("Filter does not have expected value", "Done", actualValue);
    }

    @com.thoughtworks.gauge.Step("Assert that cards <cardNames> are present in view work table")
	public void assertThatCardsArePresentInViewWorkTable(String cardNames) throws Exception {

        for (String cardName : cardNames.split(",")) {
            assertTrue("Card not present", browser.cell(cardName).exists());

        }

    }

    @com.thoughtworks.gauge.Step("Assert no work items in view work page")
	public void assertNoWorkItemsInViewWorkPage() throws Exception {

        assertTextPresent("There are no work items that match the current filter");

    }

    @com.thoughtworks.gauge.Step("Select property <propertyName> and assert values <propertyValues> in mapping dropdown list")
	public void selectPropertyAndAssertValuesInMappingDropdownList(String propertyName, String propertyValues) throws Exception {
        browser.select("program_project[status_property_name]").choose(propertyName);
        waitFor("$('program_project_done_status').options.length > 0");
        for (String value : propertyValues.split(",")) {
            assertTrue(browser.option(value).exists());
        }
    }

    @com.thoughtworks.gauge.Step("Assert save button disabled with message <message>")
	public void assertSaveButtonDisabledWithMessage(String message) throws Exception {
        assertEquals(browser.fetch("$('program_project_submit').disabled"), "true");
        assertEquals(browser.byId("card_types").text(), message);
    }

    @com.thoughtworks.gauge.Step("Edit done status from <fromValue> for project <projectName>")
	public void editDoneStatusFromForProject(String fromValue, String projectName) throws Exception {
        browser.link("Status >= " + fromValue).near(browser.cell(projectName)).click();

    }

    @com.thoughtworks.gauge.Step("Assert <linkMessage> link is present for <cardNames>")
	public void assertLinkIsPresentFor(String linkMessage, String cardNames) throws Exception {
        for (String cardName : cardNames.split(",")) {
            assertTrue(browser.link(linkMessage).near(browser.link(cardName)).isVisible());

        }

    }

    @com.thoughtworks.gauge.Step("Click on <linkMessage> link for card <cardName>")
	public void clickOnLinkForCard(String linkMessage, String cardName) throws Exception {
        browser.link(linkMessage).near(browser.link(cardName)).click();
    }

    public void clickOnCreateNewPlan() throws Exception {
        browser.navigateTo(pathTo("admin", "plans", "new"));
    }

    @com.thoughtworks.gauge.Step("The rounded default plan start date and and end dates are <startDate> <endDate>")
	public void theRoundedDefaultPlanStartDateAndAndEndDatesAre(String startDate, String endDate) throws Exception {
        openPlan("New Program");
        openPlanSettingsPopup();
        assertEquals(startDate, browser.textbox("plan[start_at]").getValue());
        assertEquals(endDate, browser.textbox("plan[end_at]").getValue());
    }

    @com.thoughtworks.gauge.Step("Edit plan <planName> with start as <startDate> and end date as <endDate>")
	public void editPlanWithStartAsAndEndDateAs(String planName, String startDate, String endDate) throws Exception {
        openPlan(planName);
        openPlanSettingsPopup();
        browser.execute("$('plan_start_at').value = '" + startDate + "';");
        browser.execute("$('plan_end_at').value = '" + endDate + "';");
        browser.submit("Save").click();
    }

    public void clickBrowserBack() throws Exception {
        browser.execute("$(history.back())");
        waitForAjaxCallFinished();
    }

    @com.thoughtworks.gauge.Step("Assert links <linkNames> present for project <project>")
	public void assertLinksPresentForProject(String linkNames, String project) throws Exception {
        for (String link : linkNames.split(",")) {
            assertTrue("link" + link + " is not present for project " + project, browser.link(link).in(browser.byId("project_" + HelperUtils.nameToIdentifier(project))).isVisible());
        }
    }

    @com.thoughtworks.gauge.Step("Assert links not present in objective popup <links>")
	public void assertLinksNotPresentInObjectivePopup(String links) throws Exception {
        for (String link : links.split(",")) {
            assertTrue("link" + link + " is present on popup", !browser.link(link).in(browser.byId("objective_details_contents")).isVisible());
        }

    }

    @com.thoughtworks.gauge.Step("Assert link url of <linkText> is <linkUrl>")
	public void assertLinkUrlOfIs(String linkText, String linkUrl) throws Exception {
        String actualUrl = browser.link(linkText).fetch("href");
        String expectedUrl = this.getPlannerBaseUrl() + linkUrl;
        assertEquals("Link does not have correct url", expectedUrl, actualUrl);

    }

    @com.thoughtworks.gauge.Step("Create objective <objectiveName>")
	public void createObjective(String objectiveName) throws Exception {
        pointInObjectiveContainer(halfOfTheColumnWidth(), determineYOffsetOfNewObjectiveBasedOnExistingObjectives()).click();
        browser.textbox("objective[name]").setValue(objectiveName);
        browser.submit("Create").click();
    }

    public void openObjectiveCreationPopup() throws Exception {
        pointInObjectiveContainer(halfOfTheColumnWidth(), determineYOffsetOfNewObjectiveBasedOnExistingObjectives()).click();
    }

    public void modifyObjectiveToEndThrough(String objectiveName, String newEndDate) throws Exception {
        waitForTimeLineStatusIsReady();
        String nextDay = dateFormats.getFutureDateAsStringAfterInHumanFormat(newEndDate, 1);
        browser.dragDrop(rightHandleOfObjective(objectiveName), newObjectiveXCoordinate(objectiveName, nextDay));
        waitForAjaxCallFinished();
    }

    @com.thoughtworks.gauge.Step("Create objective <name> starts on <startDateString> and ends on <endDateString> in days view")
	public void createObjectiveStartsOnAndEndsOnInDaysView(String name, String startDateString, String endDateString) throws Exception {
        createObjectiveStartingOnAndEndingOnWithYOffset(name, startDateString, endDateString, determineYOffsetOfNewObjectiveBasedOnExistingObjectives());
    }

    public void createObjectiveStartsOnAndEndsOnStepsBelowObjective(String name, String startDateString, String endDateString, Integer numberOfSteps, String referenceObjective) throws Exception {
        int yOffsetWithRespectToReferenceObjective = determineYOffsetOfNewObjectiveBasedOn(referenceObjective, numberOfSteps);
        int yOffsetOfReferenceObjective = getY(browser.div(convertToHtmlId(referenceObjective)));

        int overallYOffset = yOffsetOfReferenceObjective + yOffsetWithRespectToReferenceObjective;
        this.createObjectiveStartingOnAndEndingOnWithYOffset(name, startDateString, endDateString, overallYOffset);
    }

    @com.thoughtworks.gauge.Step("Create objective <name> starts on the week begins from <startWeek> and ends on the week begins from <endWeek> in weeks view")
	public void createObjectiveStartsOnTheWeekBeginsFromAndEndsOnTheWeekBeginsFromInWeeksView(String name, String startWeek, String endWeek) throws Exception {
        createObjectiveStartingOnAndEndingOnWithYOffsetOnWeeksView(name, startWeek, endWeek, determineYOffsetOfNewObjectiveBasedOnExistingObjectives());
        waitForTimeLineStatusIsReady();
    }

    public void moveObjectiveToStartOn(final String objectiveName, String newStartDate) throws Exception {
        ElementStub objective = browser.div(convertToHtmlId(objectiveName));
        int objectiveLeft = getX(objective);
        int columnLeft = xPositionFor(newStartDate);
        int moveBy = columnLeft - objectiveLeft;
        browser.execute("_sahi._dragDropXY(" + objective + ", " + moveBy + ", " + getY(objective) + ", true)");
    }

    public void modifyObjectiveToStartOn(String objectiveName, String newStartDate) throws Exception {
        waitForTimeLineStatusIsReady();
        int x = xPositionFor(newStartDate);
        int y = getY(browser.div(convertToHtmlId(objectiveName)));
        dragDropObjectiveLeftHandle(objectiveName, x, y);
    }

    @com.thoughtworks.gauge.Step("Drag the end date of objective <objectiveName> to day <dayInThisWeek> of the week begins from <startDateOfStartWeek>")
	public void dragTheEndDateOfObjectiveToDayOfTheWeekBeginsFrom(String objectiveName, Integer dayInThisWeek, String startDateOfStartWeek) throws Exception {
        waitForTimeLineStatusIsReady();
        String startWeek = dateFormats.getWeeksViewFormat(startDateOfStartWeek);
        int destX = getX(browser.listItem(startWeek)) + xOffSetForTheDayInWeek(dayInThisWeek);
        int destY = getY(browser.div(convertToHtmlId(objectiveName)));
        dragDropObjectiveRightHandle(objectiveName, destX, destY);
    }

    @com.thoughtworks.gauge.Step("Drag the start date of objective <objectiveName> to day <dayInThisWeek> of the week begins from <startDateOfStartWeek>")
	public void dragTheStartDateOfObjectiveToDayOfTheWeekBeginsFrom(String objectiveName, Integer dayInThisWeek, String startDateOfStartWeek) throws Exception {
        waitForTimeLineStatusIsReady();
        String startWeek = dateFormats.getWeeksViewFormat(startDateOfStartWeek);
        int destX = getX(browser.listItem(startWeek)) + xOffSetForTheDayInWeek(dayInThisWeek);
        int destY = getY(browser.div(convertToHtmlId(objectiveName)));
        dragDropObjectiveLeftHandle(objectiveName, destX, destY);
    }

    @com.thoughtworks.gauge.Step("Move objective <objectiveName> to start on the day <dayInThisWeek> of the week begin from <newStartDate>")
	public void moveObjectiveToStartOnTheDayOfTheWeekBeginFrom(final String objectiveName, Integer dayInThisWeek, String newStartDate) throws Exception {
        waitForTimeLineStatusIsReady();
        String startWeek = dateFormats.getWeeksViewFormat(newStartDate);
        ElementStub objective = browser.div(convertToHtmlId(objectiveName));
        int originX = getX(objective);
        int destX = getX(browser.listItem(startWeek)) + xOffSetForTheDayInWeek(dayInThisWeek);
        int moveBy = destX - originX;
        browser.execute("_sahi._dragDropXY(" + objective + ", " + moveBy + ", " + getY(objective) + ", true)");
    }

    public int xOffSetForTheDayInWeek(int dayInThisWeek) {
        int borderOffset = 1;
        return (weekDayWidth() * dayInThisWeek) - borderOffset;
    }

    public void assertThatObjectiveIsStepsBelowObjective(String lowerObjective, int expectedNumberOfSteps, String upperObjective) throws Exception {
        Integer spaceBetweenObjectives = getY(browser.div(convertToHtmlId(lowerObjective))) - getY(browser.div(convertToHtmlId(upperObjective)));
        int actual = spaceBetweenObjectives / heightOf(upperObjective);
        assertEquals("Expected number of steps to be: " + expectedNumberOfSteps + ", but got: " + actual, expectedNumberOfSteps, actual);
    }

    @com.thoughtworks.gauge.Step("Assert that objective <objectiveName> is within the week of <startDateOfThisWeek>")
	public void assertThatObjectiveIsWithinTheWeekOf(String objectiveName, String startDateOfThisWeek) throws Exception {
        ElementStub objective = browser.div(convertToHtmlId(objectiveName));
        String startDate = dateFormats.getWeeksViewFormat(startDateOfThisWeek);

        int objectiveStart = getX(objective);
        int objectiveEnd = objectiveStart + widthOf(objective);
        int weekStart = getX(browser.listItem(startDate));
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
        assertTrue(widthOf(browser.div(convertToHtmlId(objectiveName1))) > widthOf(browser.div(convertToHtmlId(objectiveName2))));
    }

    @com.thoughtworks.gauge.Step("Assert that objective <objectiveName> only spans entire week of <startDateOfThisWeek>")
	public void assertThatObjectiveOnlySpansEntireWeekOf(String objectiveName, String startDateOfThisWeek) throws Exception {
        ElementStub objective = browser.div(convertToHtmlId(objectiveName));
        String startDate = dateFormats.getWeeksViewFormat(startDateOfThisWeek);

        int objectiveStart = getX(objective);
        int objectiveWidth = widthOf(objective);
        int weekStart = getX(browser.listItem(startDate));

        String failStart = "Feature " + objectiveName + " does not start on or after date: " + startDateOfThisWeek + ". objectiveStart: " + objectiveStart + ", weekStart: " + weekStart;
        String failDuration = "Feature " + objectiveName + " does not span a full week. weekLengthInPixels: " + columnWidth() + ", objectiveLength: " + objectiveWidth;

        assertEquals(failStart, weekStart, objectiveStart);
        assertEquals(failDuration, columnWidth(), objectiveWidth);
    }

    @com.thoughtworks.gauge.Step("Assert that objective <objectiveName> cross weeks that begins from <startDateOfThisWeek> and week begins from <startDateOfAnotherWeek>")
	public void assertThatObjectiveCrossWeeksThatBeginsFromAndWeekBeginsFrom(String objectiveName, String startDateOfThisWeek, String startDateOfAnotherWeek) throws Exception {
        ElementStub objective = browser.div(convertToHtmlId(objectiveName));
        int xCordinateOfBeginningOfObjective = getX(objective);
        int xCordinateOfEndOfObjective = xCordinateOfBeginningOfObjective + widthOf(objective);

        int xCordinateOfStartDateOfThisWeek = getX(browser.listItem(dateFormats.getWeeksViewFormat(startDateOfThisWeek)));
        int xCordinateOfStartDateOfAnotherWeek = getX(browser.listItem(dateFormats.getWeeksViewFormat(startDateOfAnotherWeek)));
        assertTrue((xCordinateOfBeginningOfObjective >= xCordinateOfStartDateOfThisWeek) && (xCordinateOfEndOfObjective > xCordinateOfStartDateOfAnotherWeek));
    }

    @com.thoughtworks.gauge.Step("Assert that objective <objectiveName> starts on <objectiveStartDate> and ends on <objectiveEndDate> in days view")
	public void assertThatObjectiveStartsOnAndEndsOnInDaysView(final String objectiveName, String objectiveStartDate, String objectiveEndDate) throws Exception {
        waitForTimeLineStatusIsReady();
        ElementStub objective = browser.div(convertToHtmlId(objectiveName));

        assertObjectiveBoundaries(objectiveStartDate, objectiveEndDate, objective);
    }

    public void assertThatTheOverviewScrollerIsPresent() throws Exception {
        assertTrue(browser.div("viewport selected").isVisible());
    }

    @com.thoughtworks.gauge.Step("Assert that objective <objectiveName> is present")
	public void assertThatObjectiveIsPresent(String objectiveName) {
        assertTrue("Feature " + objectiveName + " is not found on current page!", browser.div(convertToHtmlId(objectiveName)).isVisible());
    }

    @com.thoughtworks.gauge.Step("Assert objective popup is present")
	public void assertObjectivePopupIsPresent() throws Exception {
        assertTrue("Feature popup not present", browser.byId("objective_popup_details").isVisible());

    }

    @com.thoughtworks.gauge.Step("Assert that objective <objectiveName> is not present")
	public void assertThatObjectiveIsNotPresent(String objectiveName) {
        boolean exists = browser.byId(convertToHtmlId(objectiveName)).exists();
        assertFalse("Feature " + objectiveName + " found on current page!", exists);
    }

    public void assertThatTheOverviewScrollerScrolls() throws Exception {
        ElementStub viewPort = browser.div("viewport selected");
        int originalPosition = getX(viewPort);
        browser.dragDrop(viewPort, browser.accessor("$$('#date_header li').last()"));
        assertTrue(originalPosition < getX(viewPort));
    }

    @com.thoughtworks.gauge.Step("Assert that no objective on current page")
	public void assertThatNoObjectiveOnCurrentPage() {
        assertTrue(numberOfObjectives() == 0);
    }

    @com.thoughtworks.gauge.Step("Create objective <objectiveName> starts on <startDate> and ends on <endDate> in months view")
	public void createObjectiveStartsOnAndEndsOnInMonthsView(String objectiveName, String startDate, String endDate) throws Exception {
        String startMonth = dateFormats.getMonthViewFormat(startDate);
        String endMonth = dateFormats.getMonthViewFormat(endDate);
        int startDateDayOfMonth = dateFormats.getDayOfMonth(startDate);
        int startX = (getX(browser.listItem(startMonth)) + ((startDateDayOfMonth - 1) * snapGridWidth())) - 1;
        int endDateDayOfMonth = dateFormats.getDayOfMonth(endDate);
        int endX = (getX(browser.listItem(endMonth)) + (endDateDayOfMonth * snapGridWidth())) - 1;
        pointInObjectiveContainer(startX, determineYOffsetOfNewObjectiveBasedOnExistingObjectives()).click();
        browser.textbox("objective[name]").setValue(objectiveName);
        browser.submit("submit_button").click();

        waitForTimeLineStatusIsReady();
        dragDropObjectiveLeftHandle(objectiveName, startX, determineYOffsetOfNewObjectiveBasedOnExistingObjectives());

        waitForTimeLineStatusIsReady();
        this.dragDropObjectiveRightHandle(objectiveName, endX, determineYOffsetOfNewObjectiveBasedOnExistingObjectives());
        // waitForTimeLineStatusIsReady();
    }

    @com.thoughtworks.gauge.Step("Assert that objective <objectiveName> starts on <startDate> and ends on <endDate> in months view")
	public void assertThatObjectiveStartsOnAndEndsOnInMonthsView(String objectiveName, String startDate, String endDate) throws Exception {
        int expectedObjectiveStartDateX = getXForObjectiveStartDateInMonthView(startDate);
        int expectedObjectiveEndDateX = getXForObjectiveEndDateInMonthView(endDate);
        ElementStub objective = browser.div(convertToHtmlId(objectiveName));
        int actualObjectiveStartDateX = getX(objective);
        int actualObjectiveEndDateX = actualObjectiveStartDateX + widthOf(objective);
        String startDateFailMessage = "The objective " + objectiveName + " does not start at date " + startDate + ". Expected position " + expectedObjectiveStartDateX + ", actual: " + actualObjectiveStartDateX;
        String endDateFailMessage = "The objective " + objectiveName + " does not end at date " + endDate + ". Expected position " + expectedObjectiveEndDateX + ", actual: " + actualObjectiveEndDateX;
        waitForTimeLineStatusIsReady();
        assertEquals(endDateFailMessage, expectedObjectiveEndDateX, actualObjectiveEndDateX);
        assertEquals(startDateFailMessage, expectedObjectiveStartDateX, actualObjectiveStartDateX);
    }

    public void openObjectiveInANastyWay(String objectiveName) throws Exception {
        Thread.sleep(5000);
        ElementStub objective = browser.div(convertToHtmlId(objectiveName));
        browser.xy(browser.link(objectiveName).in(objective)).click();
    }

    @com.thoughtworks.gauge.Step("Move objective <objectiveName> from <objectiveStartDate> to start on <targetStartDate> in months view")
	public void moveObjectiveFromToStartOnInMonthsView(String objectiveName, String objectiveStartDate, String targetStartDate) throws Exception {
        ElementStub objective = browser.div(convertToHtmlId(objectiveName));
        int daysDiff = dateFormats.getDaysDifference(objectiveStartDate, targetStartDate);
        int targetXOffset = daysDiff * snapGridWidth();
        browser.execute("_sahi._dragDropXY(" + objective + "," + targetXOffset + ", 0, true)");
    }

    @com.thoughtworks.gauge.Step("Drag objective <objectiveName> from start date <objectiveStartDate> to <targetStartDate> in months view")
	public void dragObjectiveFromStartDateToInMonthsView(String objectiveName, String objectiveStartDate, String targetStartDate) throws Exception {
        int daysDifference = dateFormats.getDaysDifference(objectiveStartDate, targetStartDate);
        int targetXOffset = daysDifference * snapGridWidth();
        ElementStub objectiveLeftHandle = browser.span("left_handle").in(browser.div(convertToHtmlId(objectiveName)));
        browser.execute("_sahi._dragDropXY(" + objectiveLeftHandle + "," + targetXOffset + ", 0, true)");
        waitForAjaxCallFinished();
    }

    @com.thoughtworks.gauge.Step("Drag objective <objectiveName> from end date <objectiveEndDate> to <targetEndDate> in months view")
	public void dragObjectiveFromEndDateToInMonthsView(String objectiveName, String objectiveEndDate, String targetEndDate) throws Exception {
        int daysDifference = dateFormats.getDaysDifference(objectiveEndDate, targetEndDate);
        int targetXOffset = daysDifference * snapGridWidth();
        ElementStub objectiveRightHandle = browser.span("right_handle").in(browser.div(convertToHtmlId(objectiveName)));
        browser.execute("_sahi._dragDropXY(" + objectiveRightHandle + "," + targetXOffset + ", 0, true)");
    }

    @com.thoughtworks.gauge.Step("Drag the <handle> of objective <objective> to day <day> of the month begins from <date>")
	public void dragTheOfObjectiveToDayOfTheMonthBeginsFrom(String handle, String objective, Integer day, String date) throws Exception {
        waitForTimeLineStatusIsReady();
        String startMonth = dateFormats.getMonthViewFormat(date);
        int destY = getY(browser.div(convertToHtmlId(objective)));
        if (handle.equals("end date")) {
            int destX = getX(browser.listItem(startMonth)) + xOffSetForTheDayInMonth(day);
            dragDropObjectiveRightHandle(objective, destX, destY);
        } else if (handle.equals("start date")) {
            int destX = getX(browser.listItem(startMonth)) + xOffSetForTheDayInMonth(day - 1);
            dragDropObjectiveLeftHandle(objective, destX, destY);
        }
    }

    public int xOffSetForTheDayInMonth(int dayInThisMonth) throws InterruptedException {
        int borderOffset = 1;
        return (monthDayWidth() * dayInThisMonth) - borderOffset;
    }

    @com.thoughtworks.gauge.Step("Assert that the first month on timeline page is <monthName>")
	public void assertThatTheFirstMonthOnTimelinePageIs(String monthName) throws Exception {
        String failMessage = "The first month on Timeline page is: " + browser.listItem("0_column").getText() + ", Not: " + monthName;
        assertEquals(failMessage, browser.listItem("0_column").getText(), monthName);
    }

    @com.thoughtworks.gauge.Step("Assert that the first week on timeline page is <weekName>")
	public void assertThatTheFirstWeekOnTimelinePageIs(String weekName) throws Exception {
        String failMessage = "The first week on Timeline page is: " + browser.listItem("0_column").getText() + ", Not: " + weekName;
        assertEquals(failMessage, browser.listItem("0_column").getText(), weekName);
    }

    @com.thoughtworks.gauge.Step("Assert that objective <objectiveName> starts on <expectedStartDate> and ends on <expectedEndDate> in weeks view")
	public void assertThatObjectiveStartsOnAndEndsOnInWeeksView(String objectiveName, String expectedStartDate, String expectedEndDate) throws Exception {
        ElementStub objective = browser.div(convertToHtmlId(objectiveName));
        int actualObjectiveStartPosition = getX(objective);
        int actualObjectiveEndPosition = actualObjectiveStartPosition + widthOf(objective);
        String expectedStartDateWeeksFormat = dateFormats.getWeeksViewFormat(expectedStartDate);
        int expectedObjectiveStartPosition = getX(browser.listItem(expectedStartDateWeeksFormat)) + (snapGridWidth() * (dateFormats.getDayOfWeek(expectedStartDate) - 1));

        String expectedEndDateWeeksFormat = dateFormats.getWeeksViewFormat(expectedEndDate);
        int expectedObjectiveEndPosition = getX(browser.listItem(expectedEndDateWeeksFormat)) + (snapGridWidth() * dateFormats.getDayOfWeek(expectedEndDate));

        assertEquals("The objective does NOT start at: " + expectedStartDate, expectedObjectiveStartPosition, actualObjectiveStartPosition);
        assertEquals("The objective does NOT end at: " + expectedEndDate, expectedObjectiveEndPosition, actualObjectiveEndPosition);
    }

    @com.thoughtworks.gauge.Step("Scroll to the end of the plan")
	public void scrollToTheEndOfThePlan() throws Exception {
        waitForTimeLineStatusIsReady();
        int targetX = widthOf(browser.div("overview")) - widthOf(browser.div("viewport selected"));
        browser.execute("_sahi._dragDropXY(" + browser.div("viewport selected") + ", " + targetX + ", " + getY(browser.div("viewport selected")) + ", true)");
        waitForTimeLineStatusIsReady();
    }

    @com.thoughtworks.gauge.Step("Assert that the last month on timeline page is <monthName>")
	public void assertThatTheLastMonthOnTimelinePageIs(String monthName) throws Exception {
        String lastMonthOnTimeline = browser.accessor("$$('#date_header li').last()").getText();
        String failMessage = "Ths last month on Timeline page is: " + lastMonthOnTimeline + " , is NOT: " + monthName;
        assertEquals(failMessage, monthName, lastMonthOnTimeline);
    }

    @com.thoughtworks.gauge.Step("Assert that the last week on timeline page is <weekName>")
	public void assertThatTheLastWeekOnTimelinePageIs(String weekName) throws Exception {
        String lastWeekOnTimelinePage = browser.accessor("$$('#date_header li').last()").getText();
        String failMessage = "The last month on Timeline page is: " + lastWeekOnTimelinePage + ", is NOT: " + weekName;
        assertEquals(failMessage, weekName, lastWeekOnTimelinePage);
    }

    public void createObjectiveStartsOnAndEndsOnInWeeksView(String objectiveName, String objectiveStartDate, String objectiveEndDate) throws Exception {
        String startDateWeek = dateFormats.getWeeksViewFormat(objectiveStartDate);
        String endDateWeek = dateFormats.getWeeksViewFormat(objectiveEndDate);
        int startDateDayInWeek = dateFormats.getDayOfWeek(objectiveStartDate);
        int startX = getX(browser.listItem(startDateWeek)) + ((startDateDayInWeek - 1) * snapGridWidth());
        int endDateDayInWeek = dateFormats.getDayOfWeek(objectiveEndDate);
        int endX = getX(browser.listItem(endDateWeek)) + (endDateDayInWeek * snapGridWidth());

        pointInObjectiveContainer(startX, determineYOffsetOfNewObjectiveBasedOnExistingObjectives()).click();
        browser.textbox("objective[name]").setValue(objectiveName);
        browser.submit("submit_button").click();

        waitForTimeLineStatusIsReady();
        dragDropObjectiveLeftHandle(objectiveName, startX, determineYOffsetOfNewObjectiveBasedOnExistingObjectives());

        waitForTimeLineStatusIsReady();
        this.dragDropObjectiveRightHandle(objectiveName, endX, determineYOffsetOfNewObjectiveBasedOnExistingObjectives());
    }

    @com.thoughtworks.gauge.Step("Switch to <viewName> view")
	public void switchToView(String viewName) throws Exception {
        super.switchToView(viewName);
    }

    private void createObjectiveStartingOnAndEndingOnWithYOffset(String objectiveName, String startDate, String endDate, int objectiveYPosition) throws Exception {
        int startX = xPositionFor(startDate);
        int destX = xPositionFor(endDate);
        ElementStub objective = browser.div(convertToHtmlId(objectiveName));
        pointInObjectiveContainer(startX, objectiveYPosition).click();
        browser.textbox("objective[name]").setValue(objectiveName);
        browser.submit("submit_button").click();

        waitForTimeLineStatusIsReady();
        destX = destX - startX;
        dragDropObjectiveRightHandleRelative(objectiveName, destX, getY(objective));
    }

    private void createObjectiveStartingOnAndEndingOnWithYOffsetOnWeeksView(String objectiveName, String startDateOfStartWeek, String startDateOfEndWeek, int objectiveYPosition) throws Exception {
        String startWeek = dateFormats.getWeeksViewFormat(startDateOfStartWeek);
        String endWeek = dateFormats.getWeeksViewFormat(startDateOfEndWeek);

        int startX = getX(browser.listItem(startWeek));
        int destX = getX(browser.listItem(endWeek)) + columnWidth(); // Position
                                                                     // through
                                                                     // end
                                                                     // week

        pointInObjectiveContainer(startX, objectiveYPosition).click();
        browser.textbox("objective[name]").setValue(objectiveName);
        browser.submit("submit_button").click();

        waitForTimeLineStatusIsReady();

        dragDropObjectiveRightHandle(objectiveName, destX, objectiveYPosition);
    }

    private void dragDropObjectiveLeftHandle(String objectiveName, int objectiveToX, int objectiveToY) {
        ElementStub leftHandleOfObjective = leftHandleOfObjective(objectiveName);
        browser.execute("_sahi._dragDropXY(" + leftHandleOfObjective + ", " + objectiveToX + ", " + objectiveToY + ", false)");
    }

    private void dragDropObjectiveRightHandle(String objectiveName, int objectiveToX, int objectiveToY) {
        ElementStub rightHandleOfObjective = rightHandleOfObjective(objectiveName);
        objectiveToX = objectiveToX - widthOf(rightHandleOfObjective);
        browser.execute("_sahi._dragDropXY(" + rightHandleOfObjective + ", " + objectiveToX + ", " + objectiveToY + ", false)");
    }

    private void dragDropObjectiveRightHandleRelative(String objectiveName, int objectiveToX, int objectiveToY) {
        ElementStub rightHandleOfObjective = rightHandleOfObjective(objectiveName);
        objectiveToX = objectiveToX - widthOf(rightHandleOfObjective);
        browser.execute("_sahi._dragDropXY(" + rightHandleOfObjective + ", " + objectiveToX + ", " + objectiveToY + ", true)");

    }

    private ElementStub pointInObjectiveContainer(int x, int y) {
        return browser.xy(browser.div("objective_container"), x, y);
    }

    private Integer heightOf(String objectiveName) throws Exception {
        return heightOf(browser.div(convertToHtmlId(objectiveName)));
    }

    private int determineYOffsetOfNewObjectiveBasedOnExistingObjectives() {
        return numberOfObjectives() * rowHeight();
    }

    private int determineYOffsetOfNewObjectiveBasedOn(String referenceObjective, Integer numberOfSteps) throws Exception {
        Integer heightOfObjective = heightOf(referenceObjective);
        Integer smallMargin = heightOfObjective / 4; // quarter the height of an
                                                     // objective for a
                                                     // margin of
                                                     // error
        return (numberOfSteps * heightOfObjective) + smallMargin;
    }

    private int numberOfObjectives() {
        return Integer.parseInt(browser.fetch("$$('div.objective').size()"));
    }

    private int halfOfTheColumnWidth() throws Exception {
        return columnWidth() / 2;
    }

    private int columnWidth() {
        return Integer.parseInt(browser.fetch("Timeline.GRIDS_PER_COLUMN[timeline.mainViewContent.currentGranularity]")) * snapGridWidth();
    }

    private int snapGridWidth() {
        return Integer.parseInt(browser.fetch("timeline.mainViewContent.getSnapGridWidth()"));
    }

    private int rowHeight() {
        return Integer.parseInt(browser.fetch("timeline.mainViewContent.rowHeight"));
    }

    private int weekDayWidth() {
        return Integer.parseInt(browser.fetch("Timeline.GRID_SIZE['weeks']"));
    }

    private int monthDayWidth() {
        return Integer.parseInt(browser.fetch("Timeline.GRID_SIZE['months']"));
    }

    private ElementStub leftHandleOfObjective(String objectiveName) {
        return browser.span("left_handle").in(browser.div(convertToHtmlId(objectiveName)));
    }

    private ElementStub rightHandleOfObjective(String objectiveName) {
        return browser.span("right_handle").in(browser.div(convertToHtmlId(objectiveName)));
    }

    private int getX(ElementStub elementStub) {
        return parseInt(browser.fetch("$(" + elementStub + ").positionedOffset()[0]"));
    }

    private int getY(ElementStub elementStub) {
        int y = parseInt(browser.fetch("$(" + elementStub + ").positionedOffset()[1]"));
        return y;
    }

    private Integer heightOf(ElementStub elementStub) {
        return parseInt(browser.fetch("$(" + elementStub + ").getHeight()"));
    }

    private Integer widthOf(ElementStub elementStub) {
        return parseInt(browser.fetch("$(" + elementStub + ").getWidth()"));
    }

    private int xPositionFor(String startDate) throws Exception {
        String dateString = dateFormats.toHumanFormat(startDate);
        int columnIndex = parseInt(browser.fetch("timeline.mainViewContent.findViewColumnByDate(\"" + dateString + "\").index"));

        // System.out.println("startDate: " + startDate + " (" + dateString +
        // ") -> column " + columnIndex);
        return columnIndex * columnWidth();
    }

    private ElementStub newObjectiveXCoordinate(String objectiveName, String newEndDate) throws Exception {
        return pointInObjectiveContainer(xPositionFor(newEndDate), getY(browser.div(convertToHtmlId(objectiveName))));
    }

    private void assertObjectiveBoundaries(String startDate, String endDate, ElementStub objective) throws Exception {
        String start = dateFormats.toHumanFormat(startDate);
        String end = dateFormats.toHumanFormat(endDate);

        int startX = xPositionFor(start);
        int endX = xPositionFor(end) + snapGridWidth();

        int objectiveStart = getX(objective);
        int objectiveEnd = objectiveStart + widthOf(objective);

        String failMessage = "The objective " + objective + " does not start at date " + start + ". Expected position " + startX + ", actual: " + objectiveStart;
        assertEquals(failMessage, startX, objectiveStart);

        failMessage = "The objective " + objective + " does not end through date " + end + ". Expected position " + endX + ", actual: " + objectiveEnd;
        assertEquals(failMessage, endX, objectiveEnd);
    }

    private int getXForObjectiveEndDateInMonthView(String date) throws Exception {
        int objectiveEndX = getX(browser.listItem(dateFormats.getMonthViewFormat(date))) + (dateFormats.getDayOfMonth(date) * snapGridWidth());
        return objectiveEndX;
    }

    private int getXForObjectiveStartDateInMonthView(String date) throws Exception {
        int objectiveStartX = getX(browser.listItem(dateFormats.getMonthViewFormat(date))) + ((dateFormats.getDayOfMonth(date) - 1) * snapGridWidth());
        return objectiveStartX;
    }

    private int findTodayPositionOnTimeline() {

        int todayPosition = Integer.parseInt(browser.fetch("timeline.mainViewContent.findTodayLocationOnTimeline()"));
        return todayPosition;
    }

    public String convertToHtmlId(String objectiveName) {
        if (Character.isDigit(objectiveName.charAt(0))) {
            return "objective_objective_" + HelperUtils.nameToIdentifier(objectiveName);
        } else {
            return "objective_" + HelperUtils.nameToIdentifier(objectiveName);
        }
    }

    @com.thoughtworks.gauge.Step("Verify alert is displayed in <objectiveName> objective")
	public void verifyAlertIsDisplayedInObjective(String objectiveName) throws Exception {
        ElementStub objectiveElement = browser.byId(convertToHtmlId(objectiveName));
        assertEquals("Alert is not present", "true", browser.fetch("$(" + objectiveElement + ").getElementsByClassName('late').length == 1"));

    }

    @com.thoughtworks.gauge.Step("Verify alert is not displayed in <objectiveName> objective")
	public void verifyAlertIsNotDisplayedInObjective(String objectiveName) throws Exception {
        ElementStub objectiveElement = browser.byId(convertToHtmlId(objectiveName));
        assertEquals("Alert is present", "true", browser.fetch("$(" + objectiveElement + ").getElementsByClassName('late').length == 0"));

    }

    @com.thoughtworks.gauge.Step("Assert granularity <granularity> highlighted")
	public void assertGranularityHighlighted(String granularity) throws Exception {
        assertEquals("selected", browser.fetch("$('" + granularity + "_selector').readAttribute('class')"));
    }

    @com.thoughtworks.gauge.Step("Assert spinner on <objectiveName> objective")
	public void assertSpinnerOnObjective(String objectiveName) throws Exception {

        ElementStub objectiveElement = browser.byId(convertToHtmlId(objectiveName));
        assertEquals("Auto sync spinner is not present", "true", browser.fetch("$(" + objectiveElement + ").getElementsByClassName('spinner').length != 0"));

    }

    @com.thoughtworks.gauge.Step("Refresh plan page")
	public void refreshPlanPage() throws Exception {
        browser.link("Plan").click();
    }

    @com.thoughtworks.gauge.Step("Assert that the timeline is centered on today")
	public void assertThatTheTimelineIsCenteredOnToday() throws Exception {
        int expectedPosition = findTodayPositionOnTimeline();
        int actualtodayPosition = getX(browser.byId("today_marker"));
        System.out.println(expectedPosition + ": " + actualtodayPosition);
        assertEquals("Timeline view is not centered as of today", expectedPosition, actualtodayPosition);
    }

    @com.thoughtworks.gauge.Step("Assert spinner is not present on <objectiveName> objective")
	public void assertSpinnerIsNotPresentOnObjective(String objectiveName) throws Exception {
        ElementStub objectiveElement = browser.byId(convertToHtmlId(objectiveName));
        assertEquals("Auto sync spinner is  present", "true", browser.fetch("$(" + objectiveElement + ").getElementsByClassName('spinner').length == 0"));

    }

    public void assertObjectiveNotPresentAfterPlanDeletion(String objectiveName, String planName) throws Exception {
        browser.navigateTo(this.pathTo("programs"), true);
        browser.link("Plan").near(browser.heading2(planName)).click();
        switchToView("days");
        assertFalse(browser.byId("objective_" + HelperUtils.nameToIdentifier(objectiveName)).exists());

    }

    @com.thoughtworks.gauge.Step("Click on objective name <objectiveName> on popup")
	public void clickOnObjectiveNameOnPopup(String objectiveName) throws Exception {
        browser.link(objectiveName).click();
    }

    @com.thoughtworks.gauge.Step("Assert value statement <valueStatement> on popup")
	public void assertValueStatementOnPopup(String valueStatement) throws Exception {
        System.out.println(browser.fetch("document.getElementsByClassName('objective_value_statement')[0].innerHTML"));
        System.out.println(valueStatement);
        assertEquals(valueStatement, browser.fetch("document.getElementsByClassName('objective_value_statement')[0].innerHTML").trim());
    }
}
