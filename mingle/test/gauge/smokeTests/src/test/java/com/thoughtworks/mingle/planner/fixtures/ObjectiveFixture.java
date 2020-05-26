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

import java.util.ArrayList;
import java.util.List;

import junit.framework.ComparisonFailure;
import net.sf.sahi.client.Browser;
import net.sf.sahi.client.ElementStub;

import com.thoughtworks.mingle.planner.smokeTest.util.Assertions;
import com.thoughtworks.mingle.planner.smokeTest.util.DateFormatter;
import com.thoughtworks.mingle.planner.smokeTest.util.HelperUtils;
import com.thoughtworks.mingle.planner.smokeTest.util.JRubyScriptRunner;
import com.thoughtworks.mingle.planner.smokeTest.util.JRubyScriptRunner.ScriptBuilder;
import com.thoughtworks.mingle.planner.smokeTest.util.JRubyScriptRunner.ScriptWriter;

public class ObjectiveFixture extends Assertions {

    private final DateFormatter dateFormats;
    private final JRubyScriptRunner scriptRunner;

    public ObjectiveFixture(Browser browser, JRubyScriptRunner scriptRunner) {
        super(browser);
        this.scriptRunner = scriptRunner;
        this.dateFormats = new DateFormatter();
    }

    @com.thoughtworks.gauge.Step("Navigate to plan <planName> objective <objectiveName> assign work page")
	public void navigateToPlanObjectiveAssignWorkPage(String planName, String objectiveName) {
        this.navigateTo("programs", HelperUtils.nameToIdentifier(planName), "plan", "objectives", HelperUtils.nameToIdentifier(objectiveName), "work", "cards");
    }

    @com.thoughtworks.gauge.Step("Navigate to edit plan <planName> objective <objectiveName>")
	public void navigateToEditPlanObjective(String planName, String objectiveName) {
        this.navigateTo("programs", HelperUtils.nameToIdentifier(planName), "plan", "objectives", HelperUtils.nameToIdentifier(objectiveName), "edit");
    }

    @com.thoughtworks.gauge.Step("Navigate to wiki page <wikiName> of project <projectName>")
	public void navigateToWikiPageOfProject(String wikiName, String projectName) {
        this.navigateTo("projects", projectName.toLowerCase(), "wiki", wikiName.replaceAll(" ", "_"));

    }

    @com.thoughtworks.gauge.Step("Navigate to objective <objectiveName> of plan <planName>")
	public void navigateToObjectiveOfPlan(String objectiveName, String planName) {
        this.navigateTo("programs", HelperUtils.nameToIdentifier(planName), "plan");
        openObjectivePopup(objectiveName);
    }

    @com.thoughtworks.gauge.Step("Open objective <objectiveName> popup")
	public void openObjectivePopup(String objectiveName) {
        browser.execute("Timeline.Objective.Popup.PROGRESS_SCALE_DURATION = 0;");
        String id = convertToHtmlId(objectiveName.toLowerCase());
        ElementStub objectiveEle = browser.div(id);
        objectiveEle.fetch("fire('objective:show_popup', {x: " + getX(objectiveEle) + ", y: " + getX(objectiveEle) + "})");
        waitForTimeLineStatusIsReady();
    }

    private int getX(ElementStub elementStub) {
        return parseInt(browser.fetch("$(" + elementStub + ").positionedOffset()[0]"));
    }

    @com.thoughtworks.gauge.Step("Update objective to <objectiveName>")
	public void updateObjectiveTo(String objectiveName) {
        browser.textbox("objective_name").setValue(objectiveName);
        browser.submit("Save").click();
    }

    @com.thoughtworks.gauge.Step("Attempt to create objective named <objectiveName> and click cancel")
	public void attemptToCreateObjectiveNamedAndClickCancel(String objectiveName) {
        browser.div("objective_container").click();
        browser.textbox("objective[name]").setValue(objectiveName);
        browser.link("cancel_objective_creation").click();
    }

    @com.thoughtworks.gauge.Step("Choose to delete objective")
	public void chooseToDeleteObjective() {
        browser.link("Remove").click();
    }

    @com.thoughtworks.gauge.Step("Continue to delete objective")
	public void continueToDeleteObjective() {
        browser.submit("Delete").click();
    }

    @com.thoughtworks.gauge.Step("Edit objective with new name <objectiveName> new start date <startDate> new end date <endDate>")
	public void editObjectiveWithNewNameNewStartDateNewEndDate(String objectiveName, String startDate, String endDate) {
        browser.link("Edit").click();
        browser.textbox("objective_name").setValue(objectiveName);
        browser.textbox("objective_start_at").setValue(startDate);
        browser.textbox("objective_end_at").setValue(endDate);
    }

    @com.thoughtworks.gauge.Step("Update objective with new start date <startDate> new end date <endDate>")
	public void updateObjectiveWithNewStartDateNewEndDate(String startDate, String endDate) {
        browser.textbox("objective_start_at").setValue(startDate);
        browser.textbox("objective_end_at").setValue(endDate);
    }

    @com.thoughtworks.gauge.Step("Save objective edit")
	public void saveObjectiveEdit() {
        browser.submit("Save").click();
    }

    @com.thoughtworks.gauge.Step("Cancel objective editing")
	public void cancelObjectiveEditing() {
        browser.button("Cancel").click();
    }

    @com.thoughtworks.gauge.Step("Set filter number <filterNumber> with property <filterProperty> operator <filterOperator> and value <filterValue> on add work page")
	public void setFilterNumberWithPropertyOperatorAndValueOnAddWorkPage(Integer filterNumber, String filterProperty, String filterOperator, String filterValue) throws Exception {
        if (filterNumber == 0) {
            setFirstFilterWithPropertyOperatorAndValue(filterOperator, filterValue);
        } else {
            setFilterProperty(filterNumber, filterProperty);
            setFilterOperator(filterNumber, filterOperator);
            setFilterValue(filterNumber, filterValue);
        }
        waitForAjaxCallFinished();
    }

    @com.thoughtworks.gauge.Step("Set filter number <filterNumber> with property <filterProperty> operator <filterOperator> and value <filterValue> on work page")
	public void setFilterNumberWithPropertyOperatorAndValueOnWorkPage(Integer filterNumber, String filterProperty, String filterOperator, String filterValue) throws Exception {
        setFilterProperty(filterNumber, filterProperty);
        setFilterOperator(filterNumber, filterOperator);
        setFilterValue(filterNumber, filterValue);
    }

    @com.thoughtworks.gauge.Step("Select project <projectName>")
	public void selectProject(String projectName) throws Exception {
        browser.select("project_id").choose(projectName);
    }

    @com.thoughtworks.gauge.Step("Add another filter")
	public void addAnotherFilter() throws Exception {
        browser.link("Add a filter").click();
    }

    @com.thoughtworks.gauge.Step("Remove <filter> filter")
	public void removeFilter(String filter) throws Exception {
        browser.link("filter-delete-link").near(browser.link(filter)).click();
    }

    @com.thoughtworks.gauge.Step("Deselect cards <cardNames>")
	public void deselectCards(String cardNames) throws Exception {
        for (String cardName : cardNames.split(",")) {
            browser.checkbox(0).in(browser.cell(cardName).parentNode()).uncheck();
        }
    }

    @com.thoughtworks.gauge.Step("Select all cards")
	public void selectAllCards() throws Exception {
        browser.link("All").click();
    }

    @com.thoughtworks.gauge.Step("Clear cards selection")
	public void clearCardsSelection() throws Exception {
        browser.link("None").click();
    }

    @com.thoughtworks.gauge.Step("Select cards <cardNumbers> from project <projectName> on work page")
	public void selectCardsFromProjectOnWorkPage(String cardNumbers, String projectName) throws Exception {
        int numberOfCards = getNumberOfRowsInTable("view_work_list");

        for (String cardNumber : getCardNumbersFromRange(cardNumbers)) {
            selectCardFromProjectOnWorkPage(cardNumber, projectName, numberOfCards);
        }
    }

    private List<String> getCardNumbersFromRange(String cardNumbers) {
        List<String> card_numbers = new ArrayList<String>();
        for (String range : cardNumbers.replaceAll(" ", "").split(",")) {
            if (range.contains("..")) {
                String[] range_bounds = range.split("\\.\\.");
                int end = Integer.parseInt(range_bounds[1]);
                int start = Integer.parseInt(range_bounds[0]);
                for (int i = start; i <= end; i++) {
                    card_numbers.add(i + "");
                }
            } else {
                card_numbers.add(range);
            }
        }
        return card_numbers;
    }

    @com.thoughtworks.gauge.Step("Add selected cards to objective")
	public void addSelectedCardsToObjective() {
        browser.submit("Add").click();
    }

    public void clickButton(String buttonName) {
        browser.submit(buttonName).click();
    }

    public void updateObjectiveNameToOnObjectivePopup(String objectiveName) {
        browser.textbox("objective[name]").setValue(objectiveName);
        browser.submit("Create").click();
    }

    @com.thoughtworks.gauge.Step("Open add works page")
	public void openAddWorksPage() {
        browser.link("Add work").click();
    }

    @com.thoughtworks.gauge.Step("View work")
	public void viewWork() {
        browser.link("View work").click();
    }

    public void clickNextLink() {
        browser.link("Next").click();
    }

    @com.thoughtworks.gauge.Step("Click next link to open next page")
	public void clickNextLinkToOpenNextPage() throws Exception {
        browser.link("Next").click();
    }

    public void clickPreviousLinkToOpenPreviousPage() {
        browser.link("Previous").click();
    }

    @com.thoughtworks.gauge.Step("Click <linkText> link")
	public void clickLink(String linkText) {
        browser.link(linkText).click();
    }

    public void saveObjectiveWithName(String objectiveName) {
        browser.textbox("objective[name]").setValue(objectiveName);
        browser.submit("Create").click();
    }

    public void saveObjectiveEditionWithName(String objectiveName) {
        browser.textbox("objective[name]").setValue(objectiveName);
        browser.submit("Save").click();
    }

    @com.thoughtworks.gauge.Step("Assert that the order of projects in dropdown on objective detail page is <projectsList>")
	public void assertThatTheOrderOfProjectsInDropdownOnObjectiveDetailPageIs(String projectsList) {
        String trimmedProjectsList = projectsList.replaceAll("\\s*,\\s*", ",").trim();
        String actualProjectsList = projectDropdown().getText();
        assertEquals(trimmedProjectsList, actualProjectsList);
    }

    private ElementStub projectDropdown() {
        return browser.select("project_id");
    }

    public void assertThatErrorMessageDisplaysOnObjectivePopup(String errorMessage) {
        assertTrue(browser.label("objective_name_label").containsText(errorMessage));
    }

    public void assertThatPaginationExistsOnCurrentPage() {
        assertTrue((browser.link("Next").exists()) || (browser.link("Previous").isVisible()));
        assertTrue(browser.div("pagination-summary").isVisible());
    }

    public void assertObjectivePresentInObjectiveList(String objectiveName) {
        assertTrue("CANNOT FIND OBJECTIVE:" + objectiveName + " IN CURRENT OBJECTIVE LIST!!", browser.link(objectiveName).exists());
    }

    public void assertObjectiveNotPresentInObjectiveList(String objectiveName) {
        assertFalse("FOUND OBJECTIVE:" + objectiveName + " IN CURRENT OBJECTIVE LIST!!", browser.link(objectiveName).exists());
    }

    public void assertObjectiveStartDateIsAndEndDateIsOnObjectivesList(String objectiveName, String startDate, String endDate) {
        String expected_objective_format = objectiveName + " (" + dateFormats.toHumanFormat(startDate) + " - " + dateFormats.toHumanFormat(endDate) + ")"; // example: s02 (01
        // Jan 2011 - 14 Jan
        // 2011)
        assertTrue("The Start date and End date of objective: " + objectiveName + " found on page is not same as expected", browser.byId("content").containsText(expected_objective_format));
    }

    @com.thoughtworks.gauge.Step("Assert that objective name is on objective popup <objectiveName>")
	public void assertThatObjectiveNameIsOnObjectivePopup(String objectiveName) {
        String objectivePopupContainer = "objective_details_contents";
        assertTrue(browser.span(objectiveName).in(browser.div(objectivePopupContainer)).exists());
    }

    @com.thoughtworks.gauge.Step("Assert that popup <popupId> contains text <ExpectedText>")
	public void assertThatPopupContainsText(String popupId, String ExpectedText) {
        assertTrue(browser.byId(popupId).containsText(ExpectedText));
    }

    @com.thoughtworks.gauge.Step("Assert that cards <cardNames> of project <projectNameExpected> are present in work table")
	public void assertThatCardsOfProjectArePresentInWorkTable(String cardNames, String projectNameExpected) {
        for (String cardName : cardNames.split(",")) {
            String actualProjectName = browser.cell(0).near(browser.cell(cardName)).under(browser.tableHeader("Project")).getText();
            assertEquals(projectNameExpected, actualProjectName);
        }
    }

    @com.thoughtworks.gauge.Step("Assert that cards <cardNames> are present")
	public void assertThatCardsArePresent(String cardNames) {
        for (String cardName : cardNames.split(",")) {
            assertTrue("Cannot find card: '" + cardName + "' on current page!", browser.cell(cardName).isVisible());
        }

    }

    @com.thoughtworks.gauge.Step("Assert that the cards <cardNames> are enabled")
	public void assertThatTheCardsAreEnabled(String cardNames) {
        for (String cardName : cardNames.split(",")) {
            assertEquals("", browser.cell(cardName).parentNode().fetch("className"));
        }
    }

    @com.thoughtworks.gauge.Step("Assert that cards <cardNames> are disabled")
	public void assertThatCardsAreDisabled(String cardNames) {
        for (String cardName : cardNames.split(",")) {
            assertEquals("disabled", browser.cell(cardName).parentNode().fetch("className"));
        }
    }

    @com.thoughtworks.gauge.Step("Assert that cards are enabled <cardNames>")
	public void assertThatCardsAreEnabled(String cardNames) {
        for (String cardName : cardNames.split(",")) {
            String classs = browser.cell(cardName).parentNode().fetch("className");
            assertFalse(classs.contains("disabled"));
        }
    }

    @com.thoughtworks.gauge.Step("Assert that the status column for cards <cardNames> is <statusExpected>")
	public void assertThatTheStatusColumnForCardsIs(String cardNames, String statusExpected) {
        for (String cardName : cardNames.split(",")) {
            String actualStatus = browser.cell(0).near(browser.cell(cardName)).under(browser.tableHeader("Status")).getText();
            assertEquals(statusExpected, actualStatus);
        }
    }

    @com.thoughtworks.gauge.Step("Select cards <cardNames>")
	public void selectCards(String cardNames) {
        for (String cardName : cardNames.split(",")) {
            browser.checkbox(0).in(browser.cell(cardName).parentNode()).check();
        }
    }

    @com.thoughtworks.gauge.Step("Assert cards <cardNames> are not selected")
	public void assertCardsAreNotSelected(String cardNames) throws Exception {
        for (String cardName : cardNames.split(",")) {
            assertFalse(browser.checkbox(0).in(browser.cell(cardName).parentNode()).checked());
        }
    }

    @com.thoughtworks.gauge.Step("Assert that pagination exists")
	public void assertThatPaginationExists() {
        assertTrue((browser.link("Next").exists()) || (browser.link("Previous").isVisible()));
        assertTrue(browser.div("pagination-summary").isVisible());
    }

    // Private methods

    private void setFilterProperty(Integer filterNumber, String filterProperty) throws Exception {
        browser.link("filter_widget_cards_filter_" + filterNumber + "_properties_drop_link").click();
        browser.listItem("filter_widget_cards_filter_" + filterNumber + "_properties_option_" + filterProperty).click();
    }

    private void setFilterOperator(Integer filterNumber, String filterOperator) throws Exception {
        browser.link("filter_widget_cards_filter_" + filterNumber + "_operators_drop_link").click();
        browser.listItem("filter_widget_cards_filter_" + filterNumber + "_operators_option_" + filterOperator).click();
    }

    private void setFilterValue(Integer filterNumber, String filterValue) throws Exception {
        browser.link("filter_widget_cards_filter_" + filterNumber + "_values_drop_link").click();
        browser.listItem("filter_widget_cards_filter_" + filterNumber + "_values_option_" + filterValue).click();
    }

    private void setFirstFilterWithPropertyOperatorAndValue(String filterOperator, String filterValue) throws Exception {
        browser.link("filter_widget_cards_filter_0_operators_drop_link").click();
        browser.listItem("filter_widget_cards_filter_0_operators_option_" + filterOperator).click();
        browser.link("filter_widget_cards_filter_0_values_drop_link").click();
        browser.listItem("filter_widget_cards_filter_0_values_option_" + filterValue).click();
    }

    @com.thoughtworks.gauge.Step("Remove selected work items from objective")
	public void removeSelectedWorkItemsFromObjective() throws Exception {
        browser.submit("remove_works").click();
    }

    public void assertThatObjectiveListPageShowsWorkSummaryForObjective(String workSummary, String objectiveName) throws Exception {
        ElementStub objective = browser.link(objectiveName).parentNode().parentNode();
        assertTrue(objective.containsText(workSummary));
    }

    @com.thoughtworks.gauge.Step("Assert that cards <cardNumbers> of project <projectName> not present in work table")
	public void assertThatCardsOfProjectNotPresentInWorkTable(String cardNumbers, String projectName) throws Exception {
        for (String cardNumber : cardNumbers.split(",")) {
            Boolean findTheCard = cardIsPresentInWorkTable(cardNumber, projectName);
            assertFalse(findTheCard == true);
        }
    }

    // private methods

    private boolean cardIsPresentInWorkTable(String cardNumber, String projectName) throws Exception {
        Boolean matched = false;

        if (!browser.cell(cardNumber).under(browser.tableHeader("Number")).isVisible()) {
            return false;
        } else {

            int numberOfRowsInTable = getNumberOfRowsInTable("view_work_list");
            for (int i = 1; i < numberOfRowsInTable; i++) {
                String actualCardNumberInCurrentRow = browser.cell(3).in(browser.row(i)).getText();
                String actualProjectNameInCurrentRow = browser.cell(2).in(browser.row(i)).getText();

                if (actualCardNumberInCurrentRow.equals(cardNumber) && actualProjectNameInCurrentRow.equals(projectName)) { return true; }
            }
        }
        return matched;

    }

    private int getNumberOfRowsInTable(String tableId) throws Exception {
        int numberOfRows = 0;
        while (browser.row(numberOfRows).in(browser.table(tableId)).exists()) {
            numberOfRows++;
        }
        return numberOfRows;
    }

    private void selectCardFromProjectOnWorkPage(String cardNumber, String projectName, Integer numberOfRowsInTable) throws Exception {
        Boolean matched = false;
        for (int i = 1; i < numberOfRowsInTable; i++) {
            String actualCardNumber = browser.cell(0).in(browser.row(i)).under(browser.tableHeader("Number")).getText();
            String actualProjectName = browser.cell(0).in(browser.row(i)).under(browser.tableHeader("Project")).getText();
            if (actualCardNumber.equals(cardNumber) && actualProjectName.equals(projectName)) {
                matched = true;
                browser.checkbox(0).in(browser.row(i)).click();
                break;
            }
        }

        assertTrue("The card NUMBER: " + cardNumber + " in PROJECT: " + projectName + " doesn't appear on work page. ", matched.equals(true));
    }

    @com.thoughtworks.gauge.Step("Assert that objective popup shows <project> project has <completed> completed work items out of <total> total")
	public void assertThatObjectivePopupShowsProjectHasCompletedWorkItemsOutOfTotal(String project, Integer completed, Integer total) throws Exception {
        assertTheNumberOfWorkItemsCompletedInProjectIsOf(project, completed, total);
    }

    public void clickAddProjectsLink() throws Exception {
        browser.link(HelperUtils.returnLinkText(browser, "add projects")).click();
    }

    @com.thoughtworks.gauge.Step("Assert create objective popup is displayed")
	public void assertCreateObjectivePopupIsDisplayed() throws Exception {
        assertTrue("The create objective popup's markup should exist", browser.div("add_objective_panel").exists());
        assertTrue("The create objective popup should be visible", browser.div("add_objective_panel").isVisible());
        assertTrue("The placeholder objective's markup should exist", browser.accessor("$$('.objective-place-holder')[0]").exists());
        assertTrue("The placeholder objective should be visible", browser.accessor("$$('.objective-place-holder')[0]").isVisible());
    }

    @com.thoughtworks.gauge.Step("Assert create objective popup is not displayed")
	public void assertCreateObjectivePopupIsNotDisplayed() throws Exception {
        assertFalse("The create objective popup should be invisible", browser.div("add_objective_panel").isVisible());
        assertFalse("The placeholder objective's markup should not exist", browser.accessor("$$('.objective-place-holder')[0]").exists());
        assertFalse("The placeholder objective should be invisible", browser.accessor("$$('.objective-place-holder')[0]").isVisible());
    }

    @com.thoughtworks.gauge.Step("Close objective creation popup")
	public void closeObjectiveCreationPopup() throws Exception {
        browser.link("cancel_objective_creation").click();
    }

    @com.thoughtworks.gauge.Step("Enable auto sync")
	public void enableAutoSync() throws Exception {
        browser.byId("autosync").check();
    }

    @com.thoughtworks.gauge.Step("ContinueAutoSync")
	public void continueAutoSync() throws Exception {
        browser.byId("enable_auto_sync").click();
        waitForAjaxCallFinished();
    }

    @com.thoughtworks.gauge.Step("Assert that cards <cardNames> are disabled on view work table")
	public void assertThatCardsAreDisabledOnViewWorkTable(String cardNames) throws Exception {
        for (int row = 0; row < cardNames.split(",").length; row++) {
            assertEquals("work_row disabled", browser.cell(0).in(view_work_table()).parentNode().fetch("className"));
        }
    }

    @com.thoughtworks.gauge.Step("Assert <projectNames> project is present in the objective popup")
	public void assertProjectIsPresentInTheObjectivePopup(String projectNames) throws Exception {
        for (String projectName : projectNames.split(",")) {
            assertEquals("" + projectName + " is not present in the objective", projectName, browser.byId("name_" + projectName.toLowerCase()).getText());
        }
    }

    @com.thoughtworks.gauge.Step("Assert the number of work items completed in project <projectName> is <numberOfWorkItemsComplete> of <totalNumberOfWorkItems>")
	public void assertTheNumberOfWorkItemsCompletedInProjectIsOf(String projectName, Integer numberOfWorkItemsComplete, Integer totalNumberOfWorkItems) throws Exception {
        ElementStub projectProgress = browser.byId("progress_" + projectName.toLowerCase());
        String count = "" + numberOfWorkItemsComplete + " of " + totalNumberOfWorkItems + "";
        assertTrue("Number of work items completed is incorrect", browser.span(count).in(projectProgress).exists());

    }

    @com.thoughtworks.gauge.Step("Assert the progress of the project <projectName> when <numberOfWorkItemsComplete> of <totalNumberOfWorkItems> items are completed")
	public void assertTheProgressOfTheProjectWhenOfItemsAreCompleted(String projectName, Integer numberOfWorkItemsComplete, Integer totalNumberOfWorkItems) throws Exception {
        ElementStub progressBarLevel = browser.byId("level_" + projectName.toLowerCase());
        Integer expectedProgress = (int) ((numberOfWorkItemsComplete * 100) / totalNumberOfWorkItems);
        Integer widthOfProgressBar = widthInPercentOf(progressBarLevel);
        assertEquals("Progress Info for the " + projectName + " is not shown", expectedProgress, widthOfProgressBar);
    }

    private Integer widthInPercentOf(ElementStub elementStub) {
        String widthPercentString = browser.fetch("$(" + elementStub + ").style.width");

        if (widthPercentString.isEmpty()) {
            return 0;
        } else {
            String widthPercentInt = widthPercentString.substring(0, widthPercentString.length() - 1);
            return parseInt(widthPercentInt);
        }
    }

    private ElementStub view_work_table() {
        return browser.table("view_work_list");
    }

    @com.thoughtworks.gauge.Step("Cancel autoSync")
	public void cancelAutoSync() throws Exception {
        browser.byId("dismiss_lightbox_button").click();

    }

    @com.thoughtworks.gauge.Step("Disable auto sync")
	public void disableAutoSync() throws Exception {
        browser.byId("autosync").uncheck();

    }

    @com.thoughtworks.gauge.Step("Add cards <cards> from <string2> project to current objective")
	public void addCardsFromProjectToCurrentObjective(String cards, String string2) throws Exception {
        selectProject(string2);
        selectCards(cards);
        addSelectedCardsToObjective();
    }

    @com.thoughtworks.gauge.Step("Select cards <cardNumbers> on assign work page")
	public void selectCardsOnAssignWorkPage(String cardNumbers) throws Exception {
        for (String number : getCardNumbersFromRange(cardNumbers)) {
            browser.checkbox(0).in(browser.cell(number).parentNode()).check();
        }
    }

    @com.thoughtworks.gauge.Step("Add cards with numbers <cardNumbers> from project <projectName>")
	public void addCardsWithNumbersFromProject(String cardNumbers, String projectName) throws Exception {
        selectProject(projectName);
        selectCardsOnAssignWorkPage(cardNumbers);
        addSelectedCardsToObjective();
    }

    @com.thoughtworks.gauge.Step("Assert add work page is in autosync mode matching <count> card")
	public void assertAddWorkPageIsInAutosyncModeMatchingCard(Integer count) throws Exception {
        assertFalse(browser.bySeleniumLocator("#filters_result .cards").exists());
        String countMessage = browser.byId("filters_result").getText();
        assertTrue(countMessage.contains("your filter"));
        assertTrue(countMessage.contains(count + " card"));
    }

    @com.thoughtworks.gauge.Step("Choose to move to backlog")
	public void chooseToMoveToBacklog() throws Exception {
        browser.submit("Move to Backlog").click();
    }

    public void assertThatCannotCreateObjective() throws Exception {
        browser.cell(0).click();
        assertFalse("STILL GOT ADD OBJECTIVE PANEL AFTER CLICK ON THE PlAN VIEW!", browser.div("add-objective-panel").isVisible());
    }

    public void assertThatCannotModifyObjective(String objectiveName) throws Exception {
        assertFalse("OBJECTIVE IS STILL MOVEABLE!", browser.div("objective moveable").exists());
    }

    @com.thoughtworks.gauge.Step("Click on addWork in the objective <objectiveName>")
	public void clickOnAddWorkInTheObjective(String objectiveName) throws Exception {
        openObjectivePopup(objectiveName);
        clickAddWorkLink();
    }

    @com.thoughtworks.gauge.Step("Click addWork link")
	public void clickAddWorkLink() {
        browser.link("Add work").click();
    }

    @com.thoughtworks.gauge.Step("Assert the number of work items completed in objective <objectiveName> is <numberOfWorkItemsComplete> of <totalNumberOfWorkItems>")
	public void assertTheNumberOfWorkItemsCompletedInObjectiveIsOf(String objectiveName, Integer numberOfWorkItemsComplete, Integer totalNumberOfWorkItems) throws Exception {
        ElementStub objectiveElement = browser.byId(convertToHtmlId(objectiveName));
        String workStatus = "" + numberOfWorkItemsComplete + " / " + totalNumberOfWorkItems + "";
        assertTrue("Number of work items completed is incorrect", browser.span(workStatus).in(objectiveElement).exists());

    }

    @com.thoughtworks.gauge.Step("Open project forecasting chart for <projectName>")
	public void openProjectForecastingChartFor(String projectName) throws Exception {

        ElementStub chartIcon = browser.byId("chart_icon_" + projectName.toLowerCase());
        chartIcon.click();

    }

    @com.thoughtworks.gauge.Step("Assert title of forecast chart <objectiveName> <projectName>")
	public void assertTitleOfForecastChart(String objectiveName, String projectName) throws Exception {
        String title = browser.fetch("$$('.lightbox_header h2 span')[0].innerHTML");
        assertEquals(objectiveName + " - " + projectName, title);
    }

    @com.thoughtworks.gauge.Step("Assert date of completion 0 percent is <expectedDateNoScope> 50 percent is <expectedDate50PScope> and 150 percent is <expectedDate150PScope>")
	public void assertDateOfCompletion0PercentIs50PercentIsAnd150PercentIs(String expectedDateNoScope, String expectedDate50PScope, String expectedDate150PScope) throws Exception {
        try {
            String actualDateNoScope = browser.fetch("$$('.highcharts-data-labels')[4].textContent || $$('.highcharts-data-labels')[4].innerText");
            assertEquals("Forecast info is incorrect", expectedDateNoScope, actualDateNoScope);

            String actualDate50PScope = browser.fetch("$$('.highcharts-data-labels')[2].textContent || $$('.highcharts-data-labels')[2].innerText");
            assertEquals("Forecast info is incorrect", expectedDate50PScope, actualDate50PScope);

            String actualDate150PScope = browser.fetch("$$('.highcharts-data-labels')[3].textContent || $$('.highcharts-data-labels')[3].innerText");
            assertEquals("Forecast info is incorrect", expectedDate150PScope, actualDate150PScope);
        } catch (ComparisonFailure e) {
            exportAllProjectsAndPrograms();
            throw e;
        }

    }

    private void exportAllProjectsAndPrograms() {
        scriptRunner.executeWithTestHelpers(new ScriptBuilder() {
            @Override
            public void build(ScriptWriter scriptWriter) {
                scriptWriter.printfln("export_all_deliverables");
            }
        });
    }

    @com.thoughtworks.gauge.Step("Verify alert is displayed for <projectName> project")
	public void verifyAlertIsDisplayedForProject(String projectName) throws Exception {
        browser.byId("chart_icon_" + projectName.toLowerCase()).hover();
        String actualMessage = browser.fetch("$j('.tipsy').text()");
        assertMatch("May not complete.*", actualMessage);
    }

    @com.thoughtworks.gauge.Step("Click on viewWork in the objective <objectiveName>")
	public void clickOnViewWorkInTheObjective(String objectiveName) throws Exception {
        browser.byId(convertToHtmlId(objectiveName)).click();
        browser.link("View work").click();

    }

    @com.thoughtworks.gauge.Step("Assert work items completed is <completedItems> of <totalItems>")
	public void assertWorkItemsCompletedIsOf(String completedItems, String totalItems) throws Exception {
        String actualcompletedItems = browser.fetch("$$('.highcharts-data-labels')[1].textContent || $$('.highcharts-data-labels')[1].innerText");
        String actualtotalItems = browser.fetch("$$('.highcharts-data-labels')[0].textContent || $$('.highcharts-data-labels')[0].innerText");
        assertEquals("No of completed work items is incorrect", completedItems, actualcompletedItems);
        assertEquals("Total number of workitems is incorrect", totalItems, actualtotalItems);

    }

    @com.thoughtworks.gauge.Step("Wait for auto sync spinner in <objectiveName> to dissappear")
	public void waitForAutoSyncSpinnerInToDissappear(String objectiveName) throws Exception {

        ElementStub objectiveElement = browser.byId(convertToHtmlId(objectiveName));

        waitFor("$(" + objectiveElement + ").getElementsByClassName('spinner').length == 0");

    }

    public String convertToHtmlId(String objectiveName) {
        if (Character.isDigit(objectiveName.charAt(0))) {
            return "objective_objective_" + HelperUtils.nameToIdentifier(objectiveName);
        } else {
            return "objective_" + HelperUtils.nameToIdentifier(objectiveName);
        }
    }
}
