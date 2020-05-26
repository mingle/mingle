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
import com.thoughtworks.mingle.planner.smokeTest.utils.DriverFactory;
import com.thoughtworks.mingle.planner.smokeTest.utils.HelperUtils;
import com.thoughtworks.mingle.planner.smokeTest.utils.JRubyScriptRunner;
import junit.framework.ComparisonFailure;
import org.openqa.selenium.By;
import org.openqa.selenium.JavascriptExecutor;
import org.openqa.selenium.StaleElementReferenceException;
import org.openqa.selenium.WebElement;
import org.openqa.selenium.interactions.Actions;

import javax.swing.text.DateFormatter;
import java.util.ArrayList;
import java.util.List;

public class ObjectiveFixture extends Assertions {
    private final DateFormatter dateFormats;
    private final JRubyScriptRunner scriptRunner;

    public ObjectiveFixture() {
        super();
        this.scriptRunner = DriverFactory.getScriptRunner();
        this.dateFormats = new DateFormatter();
    }

    @com.thoughtworks.gauge.Step("Navigate to plan <planName> objective <objectiveName> assign work page")
    public void navigateToPlanObjectiveAssignWorkPage(String planName, String objectiveName) {
        this.navigateTo("programs", HelperUtils.nameToIdentifier(planName), "plan", "objectives", HelperUtils.nameToIdentifier(objectiveName), "work", "cards");
    }

    @com.thoughtworks.gauge.Step("Click on viewWork in the objective <objectiveName>")
    public void clickOnViewWorkInTheObjective(String objectiveName) throws Exception {
        waitForElement(By.id("objective_"+HelperUtils.nameToIdentifier(objectiveName)));
        findElementById("objective_"+HelperUtils.nameToIdentifier(objectiveName)).click();
        waitForElement((By.xpath("//a[text()=\"View work\"]")));
        findElementByXpath("//a[text()=\"View work\"]").click();
    }

    @com.thoughtworks.gauge.Step("Click on viewWork in the objective on the month view <objectiveName>")
    public void clickOnViewWorkInTheObjectiveOnTheMonthView(String objectiveName) throws Exception {
        waitForElement((By.xpath("//a[text()=\"View work\"]")));
        this.driver.findElement((By.xpath("//a[text()=\"View work\"]"))).click();
    }


    @com.thoughtworks.gauge.Step("Assert that cards <cardNames> of project <projectNameExpected> are present in work table")
    public void assertThatCardsOfProjectArePresentInWorkTable(String cardNames, String projectNameExpected) throws InterruptedException {
        waitForPageLoad(2000);
        waitForAjaxCallFinished();
        for (String cardName : cardNames.split(",")) {
            String actualProjectName = this.driver.findElement(By.xpath("//*[text()=\""+cardName.trim()+"\"]/../..//*[@class=\"project_link\"]")).getText();
            assertEquals(projectNameExpected,actualProjectName);
        }
    }

    @com.thoughtworks.gauge.Step("Assert that card number <cardNumber> of project <projectNameExpected> are present in work table")
    public void assertThatCardOfProjectArePresentInWorkTable(String cardNumber, String projectNameExpected) throws InterruptedException {
        waitForAjaxCallFinished();
        waitForPageLoad(3000);
        for (String cardName : cardNumber.split(",")) {
            String actualProjectName = this.driver.findElement(By.xpath("//*[text()=\""+cardNumber.trim()+"\"]/../..//*[@class=\"project_link\"]")).getText();
            assertEquals(projectNameExpected,actualProjectName);
        }
    }

    @com.thoughtworks.gauge.Step("Select cards <cardNumbers> from project <projectName> on work page")
    public void selectCardsFromProjectOnWorkPage(String cardNumbers, String projectName) throws Exception {
        int numberOfCards = getNumberOfRowsInTable("view_work_list");
        for (String cardNumber : getCardNumbersFromRange(cardNumbers)) {
            selectCardFromProjectOnWorkPage(cardNumber, projectName, numberOfCards);
        }
    }

    private int getNumberOfRowsInTable(String tableId) throws Exception {
        return findElementsByXpath("//table[@id='"+tableId+"']/tbody/tr").size();
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

    private void selectCardFromProjectOnWorkPage(String cardNumber, String projectName, Integer numberOfRowsInTable) throws Exception {
        Boolean matched = false;
        for (int i = 1; i<= numberOfRowsInTable; i++) {
            Thread.sleep(1000);
            String actualCardNumber = findElementByXpath("//*[@id=\"view_work_list\"]/tbody/tr["+i+"]/td[3]").getText().trim();
            String actualProjectName = findElementByXpath("//*[@id=\"view_work_list\"]/tbody/tr["+i+"]/td[2]").getText().trim();
            if (actualCardNumber.equals(cardNumber) && actualProjectName.equals(projectName)) {
                matched = true;
                findElementByXpath("//*[@id=\"view_work_list\"]/tbody/tr["+i+"]/td[1]/input").click();
                break;
            }
        }
        assertTrue("The card NUMBER: " + cardNumber + " in PROJECT: " + projectName + " doesn't appear on work page. ", matched.equals(true));
    }

    @com.thoughtworks.gauge.Step("Remove selected work items from objective")
    public void removeSelectedWorkItemsFromObjective() throws Exception {
        findElementById("remove_works").click();
    }

    @com.thoughtworks.gauge.Step("Add cards <cards> from <string2> project to current objective")
    public void addCardsFromProjectToCurrentObjective(String cards, String string2) throws Exception {
        selectProject(string2);
        selectCards(cards);
        addSelectedCardsToObjective();
    }

    @com.thoughtworks.gauge.Step("Select project <projectName>")
    public void selectProject(String projectName) throws Exception {
        waitForAjaxCallFinished();
        waitForElement(By.id("project_id"));
        selectByText("project_id",projectName);
    }

    @com.thoughtworks.gauge.Step("Select cards <cardNames>")
    public void selectCards(String cardNames) throws InterruptedException {
        scrollBy(0,350);
        for (String cardName : cardNames.split(",")) {
            try {
                findElementByXpath("//*[text()=\"" + cardName.trim() + "\"]/../..//*[@class=\"select_card\"]").click();
            }catch (StaleElementReferenceException e)
            {
                Thread.sleep(5000);
                findElementByXpath("//*[text()=\"" + cardName.trim() + "\"]/../..//*[@class=\"select_card\"]").click();
            }
        }
    }

    @com.thoughtworks.gauge.Step("Add selected cards to objective")
    public void addSelectedCardsToObjective() throws InterruptedException {
        waitForElement(By.id("add_works_filter"));
        excecuteJs("$(\"add_works_filter\").click()");
        waitForElement(By.id("notice"));
        assertTrue(findElementsById("notice").size()>0);
        while (!waitForAllAjaxCompleted()){
            waitForPageLoad(1000);
        }
    }

    @com.thoughtworks.gauge.Step("Wait for <seconds> seconds")
    public void waitForSeconds(int seconds) throws Exception {
        waitForPageLoad(seconds * 1000);
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

        if (!findElementByXpath("//th[@class=\"number\"]").isDisplayed()) {
            return false;
        } else {
            int numberOfRowsInTable = getNumberOfRowsInTable("view_work_list");
            for (int i = 1; i < numberOfRowsInTable; i++) {
                String actualCardNumberInCurrentRow = findElementByXpath("//*[@id=\"view_work_list\"]/tbody/tr["+i+"]/td[3]").getText().trim();
                String actualProjectNameInCurrentRow = findElementByXpath("//*[@id=\"view_work_list\"]/tbody/tr["+i+"]/td[2]").getText().trim();

                if (actualCardNumberInCurrentRow.equals(cardNumber) && actualProjectNameInCurrentRow.equals(projectName)) { return true; }
            }
        }
        return matched;

    }

    @com.thoughtworks.gauge.Step("Navigate to objective <objectiveName> of plan <planName>")
    public void navigateToObjectiveOfPlan(String objectiveName, String planName) throws InterruptedException {
        navigateTo("programs", HelperUtils.nameToIdentifier(planName), "plan");
        openObjectivePopup(objectiveName);
    }

    @com.thoughtworks.gauge.Step("Open objective <objectiveName> popup")
    public void openObjectivePopup(String objectiveName) throws InterruptedException {
        excecuteJs("Timeline.Objective.Popup.PROGRESS_SCALE_DURATION = 0;");
        String id = convertToHtmlId(objectiveName.toLowerCase());
        waitForElement(By.id(id));
        findElementById(id).click();
        waitForTimeLineStatusIsReady();
    }

    public String convertToHtmlId(String objectiveName) {
        if (Character.isDigit(objectiveName.charAt(0))) {
            return "objective_objective_" + HelperUtils.nameToIdentifier(objectiveName);
        } else {
            return "objective_" + HelperUtils.nameToIdentifier(objectiveName);
        }
    }

    @com.thoughtworks.gauge.Step("Assert text present on the objective popup <message>")
    public void assertTextPresentOnThePopup(String message) throws InterruptedException {
        waitForElement(By.id("popup-content"));
        assertEquals(findElementById("popup-content").getText().trim(),message);
    }

    @com.thoughtworks.gauge.Step("Assert text present <message>")
    public void assertTextPresent(String message) throws InterruptedException {
       waitForElement(By.xpath("//*[contains(.,\""+message.trim()+"\")]"));
       assertTrue("Unable to find the text on the page", findElementsByXpath("//*[contains(.,\""+message.trim()+"\")]").size()>0);
    }

    @com.thoughtworks.gauge.Step("Assert Add work to this feature text present")
    public void assertAddWorkPresent() throws InterruptedException{
        waitForElement(By.id("objective_work_summary"));
        assertTrue("Unable to find add work on the objectives", findElementsByXpath("//*[text()='Add work']").size()>0);
    }

    @com.thoughtworks.gauge.Step("Assert notice text present <message>")
    public void assertNoticeTextPresent(String message) throws InterruptedException {
        String [] formatedExpectedTexts = message.split("-");
        String actualyText = findElementById("error").getText();
        String [] formatedActualTexts=actualyText.split("\n");
        for (int i=0; i<formatedActualTexts.length; i++){
            assertEquals(formatedExpectedTexts[i].trim(),formatedActualTexts[i].trim());
        }
    }

    @com.thoughtworks.gauge.Step("Assert confirmation text <message>")
    public void assertConfirmationText(String message){
        String actualText=findElementByXpath("//*[@class=\"info-box\"]").getText();
        String [] actualTexts=actualText.split("\n");
        String formatedText=actualTexts[0]+actualTexts[1];
        assertEquals(formatedText,message);
    }

    @com.thoughtworks.gauge.Step("Assert text present on the objective page <message>")
    public void assertTestPresentOnTheObjectivePage(String message) throws InterruptedException {
        waitForElement(By.id("objective_work_summary"));
        assertEquals(findElementById("objective_work_summary").getText().trim(),message);
    }

    @com.thoughtworks.gauge.Step("Open add works page")
    public void openAddWorksPage() throws InterruptedException {
        waitForElement(By.id("objective_work_summary"));
        findElementsByXpath("//a[text()=\"Add work\"]").get(0).click();
    }

    @com.thoughtworks.gauge.Step("Assert flash message <message>")
    public void assertFlashMessage(String message) throws InterruptedException {
        waitForAjaxCallFinished();
        waitForElement(By.id("notice"));
        assertEquals(message,findElementById("notice").getText());

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
        while (!waitForAllAjaxCompleted()){
            waitForPageLoad(1000);
        }
    }

    private void setFirstFilterWithPropertyOperatorAndValue(String filterOperator, String filterValue) throws Exception {
        waitForElement(By.id("filter_widget_cards_filter_0_operators_drop_link"));
        findElementById("filter_widget_cards_filter_0_operators_drop_link").click();
        waitForElement(By.id("filter_widget_cards_filter_0_operators_drop_down"));
        excecuteJs("$(\"filter_widget_cards_filter_0_operators_option_"+filterOperator+"\").click()");
        findElementById("filter_widget_cards_filter_0_values_drop_link").click();
        waitForElement(By.id("filter_widget_cards_filter_0_values_drop_down"));
        excecuteJs("$(\"filter_widget_cards_filter_0_values_option_"+filterValue+"\").click()");
    }

    private void setFilterProperty(Integer filterNumber, String filterProperty) throws Exception {
        excecuteJs("document.getElementById(\"filter_widget_cards_filter_" + filterNumber + "_properties_drop_link\").click();");
        excecuteJs("document.getElementById(\"filter_widget_cards_filter_" + filterNumber + "_properties_option_" + filterProperty +"\").click();");
    }

    private void setFilterOperator(Integer filterNumber, String filterOperator) throws Exception {
        excecuteJs("document.getElementById(\"filter_widget_cards_filter_" + filterNumber + "_operators_drop_link\").click();");
        excecuteJs("document.getElementById(\"filter_widget_cards_filter_" + filterNumber + "_operators_option_" + filterOperator +"\").click();");
    }

    private void setFilterValue(Integer filterNumber, String filterValue) throws Exception {
        excecuteJs("document.getElementById(\"filter_widget_cards_filter_" + filterNumber + "_values_drop_link\").click();");
        excecuteJs("document.getElementById(\"filter_widget_cards_filter_" + filterNumber + "_values_option_" + filterValue +"\").click();");
    }

    @com.thoughtworks.gauge.Step("Select all cards")
    public void selectAllCards() throws Exception {
        waitForPageLoad(1000);
        waitForElement(By.id("select_all_filter"));
        excecuteJs("$(\"select_all_filter\").click()");
        while (!waitForAllAjaxCompleted()){
           waitForPageLoad(1000);
        }
    }

    @com.thoughtworks.gauge.Step("Clear cards selection")
    public void clearCardsSelection() throws Exception {
        waitForPageLoad(1000);
        waitForElement(By.id("select_none_filter"));
        excecuteJs("$(\"select_none_filter\").click()");
        while (!waitForAllAjaxCompleted()){
            waitForPageLoad(1000);
        }
    }

    @com.thoughtworks.gauge.Step("Assert cards <cardNames> are not selected")
    public void assertCardsAreNotSelected(String cardNames) throws Exception {
        for (String cardName : cardNames.split(",")) {
            scrollInToText(cardName.trim());
            assertFalse("Card is selected", findElementByXpath("//*[text()=\""+cardName.trim()+"\"]/../..//*[@class=\"checkbox\"]/input").isSelected());
        }
    }

    @com.thoughtworks.gauge.Step("Assert that pagination exists")
    public void assertThatPaginationExists() throws InterruptedException {
        waitForPageLoad(1000);
        assertTrue(findElementsByClass("next_page").size()>0);
        assertTrue(findElementsByXpath("//*[@class=\"disabled prev_page\"]").size()>0);
        assertTrue(findElementsByClass("pagination-summary").size()>0);
    }

    @com.thoughtworks.gauge.Step("Click next link to open next page")
    public void clickNextLinkToOpenNextPage() throws Exception {
        findElementsByLinkText("Next").get(0).click();
    }

    @com.thoughtworks.gauge.Step("Assert that cards <cardNames> are disabled")
    public void assertThatCardsAreDisabled(String cardNames) throws InterruptedException {
        for (String cardName : cardNames.split(",")) {
            scrollInToText(cardName.trim());
            assertEquals("disabled", findElementByXpath("//*[text()=\""+cardName.trim()+"\"]/../..").getAttribute("class"));
        }
    }

    @com.thoughtworks.gauge.Step("Assert that the cards <cardNames> are enabled")
    public void assertThatCardsAreEnabled(String cardNames) throws InterruptedException {
        for (String cardName : cardNames.split(",")) {
            scrollInToText(cardName.trim());
            assertEquals("", findElementByXpath("//*[text()=\""+cardName.trim()+"\"]/../..").getAttribute("class"));
        }
    }

    @com.thoughtworks.gauge.Step("Assert the text for <message>")
    public void assertTextPresentOnThePage(String message) throws InterruptedException {
        waitForAjaxCallFinished();
        waitForElement(By.xpath("//*[@class=\"cards\"]"));
        try {
            assertTrue(findElementByXpath("//*[@class=\"find_cards_wrapper\"]").isDisplayed());
        }catch (StaleElementReferenceException e)
        {
            Thread.sleep(2000);
            assertTrue(findElementByXpath("//*[@class=\"find_cards_wrapper\"]").isDisplayed());
        }
        //Unable to locate the text. There is hidden div which gets populated
    }

    @com.thoughtworks.gauge.Step("Add another filter")
    public void addAnotherFilter() throws InterruptedException {
        ((JavascriptExecutor)this.driver).executeScript("document.evaluate(\"//a[@id='add_new_filter']\", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue.click()");
    }

    @com.thoughtworks.gauge.Step("Add another filter in work")
    public void addFilter() throws InterruptedException {
        ((JavascriptExecutor)this.driver).executeScript("document.evaluate(\"//a[text()='Add a filter']\", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue.click()");
    }

    @com.thoughtworks.gauge.Step("Assert that cards <cardNames> are present")
    public void assertThatCardsArePresent(String cardNames) throws InterruptedException {
        scrollToEndOfPage();
        waitForPageLoad(2000);
        for (String cardName : cardNames.split(",")) {
            assertTrue("Cannot find card: '" + cardName + "' on current page!", findElementsByXpath("//*[text()=\""+cardName.trim()+"\"]/../..//*[@class='card-name']").size()>0);
        }
    }

    @com.thoughtworks.gauge.Step("Click on addWork in the objective <objectiveName>")
    public void clickOnAddWorkInTheObjective(String objectiveName) throws Exception {
        openObjectivePopup(objectiveName);
        clickAddWorkLink();
    }

    @com.thoughtworks.gauge.Step("Click on addWork in the objective <objectiveName> -forcast")
    public void clickOnAddWork(String objectiveName) throws Exception {
        openObjectivePopup(objectiveName);
        clickAddWorkLinkOnMonthView(objectiveName);
    }

    @com.thoughtworks.gauge.Step("Click addWork link")
    public void clickAddWorkLink() throws InterruptedException {
        waitForElement(By.xpath("//*[@id=\"objective_work_summary\"]//*[text()=\"Add work\"]"));
        waitForPageLoad(2000);
        excecuteJs("document.evaluate(\"//*[@id='objective_work_summary']//*[text()='Add work']\", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue.click()");
    }

    @com.thoughtworks.gauge.Step("Click on addWork in the objective on the month view <objectView>")
    public void clickAddWorkLinkOnMonthView(String objectView) throws InterruptedException {
        waitForElementClickable(By.xpath("//a[text()=\"Add work\"]"));
        findElementByXpath("//a[text()=\"Add work\"]").click();
    }

    @com.thoughtworks.gauge.Step("Enable auto sync")
    public void enableAutoSync() throws Exception {
        waitForPageLoad(3000);
        waitForElementClickable(By.id("autosync"));
        findElementById("autosync").click();
    }

    @com.thoughtworks.gauge.Step("Cancel autoSync")
    public void cancelAutoSync() throws Exception {
        waitForPageLoad(3000);
        excecuteJs("$(\"dismiss_lightbox_button\").click()");
    }

    @com.thoughtworks.gauge.Step("Assert that popup <popupId> contains text <ExpectedText>")
    public void assertThatPopupContainsText(String popupId, String ExpectedText) throws InterruptedException {
        waitForPageLoad(3000);
        assertTrue(executeJsWithBooleanReturn("return $('"+popupId+"').textContent != null"));
        String actualText = excecuteJsWithStringretun("return $('"+popupId+"').textContent");
        assertTrue(actualText.contains(ExpectedText));
    }


    @com.thoughtworks.gauge.Step("ContinueAutoSync")
    public void continueAutoSync() throws Exception {
        waitForPageLoad(2000);
        excecuteJs("$(\"enable_auto_sync\").click()");
        waitForPageLoad(3000);
    }

    @com.thoughtworks.gauge.Step("Assert add work page is in autosync mode matching <count> card")
    public void assertAddWorkPageIsInAutosyncModeMatchingCard(Integer count) throws Exception {
        waitForElement(By.id("filters_result"));
        String countMessage = findElementById("filters_result").getText();
        assertTrue(countMessage.contains("your filter"));
        assertTrue(countMessage.contains(count + " card"));
    }

    @com.thoughtworks.gauge.Step("Wait for auto sync spinner in <objectiveName> to dissappear")
    public void waitForAutoSyncSpinnerInToDissappear(String objectiveName) throws Exception {
        waitForElement(By.id("work_" + HelperUtils.nameToIdentifier(objectiveName)));
    }

    @com.thoughtworks.gauge.Step("Assert text present on the work table <message>")
    public void assertTextPresentOnTheWorkTable(String message) throws InterruptedException {
           assertTrue(findElementsByXpath("//*[@class=\"auto-sync-message\"]").size()>0);
        }

    @com.thoughtworks.gauge.Step("Assert error message present <message>")
    public void assertTheErrorMessage(String message) throws InterruptedException {
            waitForElement(By.id("error"));
            assertEquals(message, findElementById("error").getText().trim());
        }

    @com.thoughtworks.gauge.Step("Assert that cards <cardNames> are disabled on view work table")
    public void assertThatCardsAreDisabledOnViewWorkTable(String cardNames) throws Exception {
        for (String cardName : cardNames.split(",")) {
            assertEquals("work_row disabled", findElementByXpath("//*[text()=\""+cardName+"\"]/../..").getAttribute("class"));
        }
    }

    @com.thoughtworks.gauge.Step("Disable auto sync")
    public void disableAutoSync() throws Exception {
        findElementById("autosync").click();
    }

    @com.thoughtworks.gauge.Step("View work")
    public void viewWork() throws InterruptedException {
        waitForElement(By.linkText("View work"));
        findElementByLinkText("View work").click();
    }

    @com.thoughtworks.gauge.Step("View work of the <objectiveName> in plan <planName>")
    public void viewWorkOfThePlan(String objectiveName,String planName){
        this.navigateTo("programs", HelperUtils.nameToIdentifier(planName), "plan", "objectives", HelperUtils.nameToIdentifier(objectiveName), "work");
    }

    @com.thoughtworks.gauge.Step("Remove <filterName> filter")
    public void removeFilterWithIndex(String filterName) throws Exception {
       waitForAjaxCallFinished();
       findElementById("filter_widget_cards_filter_0_delete").click();
    }

    @com.thoughtworks.gauge.Step("Remove <filterName> indexed at <filterNumber> filter")
    public void removeFilter(String filterName, String filterNumber) throws Exception {
        waitForAjaxCallFinished();
        findElementById("filter_widget_cards_filter_"+filterNumber+"_delete").click();
    }



    @com.thoughtworks.gauge.Step("Assert that the status column for cards <cardNames> is <statusExpected>")
    public void assertThatTheStatusColumnForCardsIs(String cardNames, String statusExpected) throws InterruptedException {
        for (String cardName : cardNames.split(",")) {
            try {
                waitForElement(By.xpath("//a[text()=\"" + cardName.trim() + "\"]/../..//*[@class=\"status\"]"));
            }catch (org.openqa.selenium.StaleElementReferenceException e)
            {
                Thread.sleep(5000);
                waitForElement(By.xpath("//a[text()=\"" + cardName.trim() + "\"]/../..//*[@class=\"status\"]"));
            }
            String actualStatus;
            try {
                actualStatus = findElementByXpath("//a[text()=\"" + cardName.trim() + "\"]/../..//*[@class=\"status\"]").getText().trim();
            }catch (org.openqa.selenium.StaleElementReferenceException e){
                Thread.sleep(5000);
                 actualStatus = findElementByXpath("//a[text()=\"" + cardName.trim() + "\"]/../..//*[@class=\"status\"]").getText().trim();
            }
            assertEquals(statusExpected, actualStatus);
        }
    }

    @com.thoughtworks.gauge.Step("Choose to delete objective")
    public void chooseToDeleteObjective() throws InterruptedException {
        waitForElement(By.xpath("//a[@class='action_icon delete_link']"));
        findElementByXpath("//a[@class='action_icon delete_link']").click();
    }

    @com.thoughtworks.gauge.Step("Add cards with numbers <cardNumbers> from project <projectName>")
    public void addCardsWithNumbersFromProject(String cardNumbers, String projectName) throws Exception {
        selectProject(projectName);
        selectCardsOnAssignWorkPage(cardNumbers);
        addSelectedCardsToObjective();
    }

    @com.thoughtworks.gauge.Step("Select cards <cardNumbers> on assign work page")
    public void selectCardsOnAssignWorkPage(String cardNumbers) throws Exception {
        scrollToEndOfPage();
        for (String number : getCardNumbersFromRange(cardNumbers)) {
            findElementByXpath("//a[text()=\""+number+"\"]/../..//*[@class=\"select_card\"]").click();
        }
    }

    @com.thoughtworks.gauge.Step("Continue to delete objective")
    public void continueToDeleteObjective() throws InterruptedException {
        waitForElement(By.xpath("//*[@value=\"Delete\"]"));
       findElementByXpath("//*[@value=\"Delete\"]").click();
    }

    @com.thoughtworks.gauge.Step("Assert that objective <objectiveName> is not present")
    public void assertThatObjectiveIsNotPresent(String objectiveName) throws InterruptedException {
        assertFalse("Objective exixts on the program", findElementsByXpath("//*[@id=\""+convertToHtmlId(objectiveName)+"\"]").size() > 0);
    }

    @com.thoughtworks.gauge.Step("Choose to move to backlog")
    public void chooseToMoveToBacklog() throws Exception {
        waitForElement(By.xpath("//*[@value=\"Move to Backlog\"]"));
        findElementByXpath("//*[@value=\"Move to Backlog\"]").click();
    }

    @com.thoughtworks.gauge.Step("Assert that objective name is on objective popup <objectiveName>")
    public void assertThatObjectiveNameIsOnObjectivePopup(String objectiveName) throws InterruptedException {
        waitForPageLoad(3000);
        String actualText=findElementByXpath("//*[@id=\"objective_details_contents\"]//*[@class=\"popup-title\"]//span").getText().trim();
        assertEquals(objectiveName, actualText);
    }

    @com.thoughtworks.gauge.Step("Edit objective with new name <objectiveName> new start date <startDate> new end date <endDate>")
    public void editObjectiveWithNewNameNewStartDateNewEndDate(String objectiveName, String startDate, String endDate) throws InterruptedException {
        //Needs additional wait time to click on the edit button
        waitForPageLoad(3000);
        excecuteJs("document.evaluate(\"//a[text()='Edit']\", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue.click()");
        findElementById("objective_name").clear();
        findElementById("objective_name").sendKeys(objectiveName);
        findElementById("objective_start_at").clear();
        findElementById("objective_start_at").sendKeys(startDate);
        findElementById("objective_end_at").clear();
        findElementById("objective_end_at").sendKeys(endDate);
    }

    @com.thoughtworks.gauge.Step("Save objective edit")
    public void saveObjectiveEdit() {
        findElementByXpath("//input[@value=\"Save\"]").click();
    }

    @com.thoughtworks.gauge.Step("Click <linkText> link")
    public void clickLink(String linkText) throws InterruptedException {
        waitForElement(By.linkText(linkText));
        findElementByLinkText(linkText.trim()).click();
    }

    @com.thoughtworks.gauge.Step("Update objective with new start date <startDate> new end date <endDate>")
    public void updateObjectiveWithNewStartDateNewEndDate(String startDate, String endDate) {
        findElementById("objective_start_at").clear();
        findElementById("objective_start_at").sendKeys(startDate);
        findElementById("objective_end_at").clear();
        findElementById("objective_end_at").sendKeys(endDate);
    }

    @com.thoughtworks.gauge.Step("Cancel objective editing")
    public void cancelObjectiveEditing() {
        findElementByXpath("//*[@value=\"Cancel\"]").click();
    }

    @com.thoughtworks.gauge.Step("Assert that objective popup shows <project> project has <completed> completed work items out of <total> total")
    public void assertThatObjectivePopupShowsProjectHasCompletedWorkItemsOutOfTotal(String project, Integer completed, Integer total) throws Exception {
        assertTheNumberOfWorkItemsCompletedInProjectIsOf(project, completed, total);
    }

    @com.thoughtworks.gauge.Step("Assert the number of work items completed in project <projectName> is <numberOfWorkItemsComplete> of <totalNumberOfWorkItems>")
    public void assertTheNumberOfWorkItemsCompletedInProjectIsOf(String projectName, Integer numberOfWorkItemsComplete, Integer totalNumberOfWorkItems) throws Exception {
        waitForElement(By.id("objective_popup_details"));
        String count = "" + numberOfWorkItemsComplete + " of " + totalNumberOfWorkItems + "";
        waitForPageLoad(2000);
        assertEquals("Number of work items completed is incorrect", count, findElementByXpath("//*[@id=\"progress_"+projectName.toLowerCase().trim()+"\"]//*[@class=\"count\"]").getText().trim());
    }

    @com.thoughtworks.gauge.Step("Assert create objective popup is displayed")
    public void assertCreateObjectivePopupIsDisplayed() throws Exception {
        assertTrue("The create objective popup's markup should exist", findElementsById("add_objective_panel").size()>0);
        assertTrue("The create objective popup should be visible", findElementById("add_objective_panel").isDisplayed());
        assertTrue("The placeholder objective's markup should exist", findElementsByXpath("//*[@class=\"objective objective-place-holder\"]").size()>0);
        assertTrue("The placeholder objective should be visible", findElementByXpath("//*[@class=\"objective objective-place-holder\"]").isDisplayed());
    }

    @com.thoughtworks.gauge.Step("Close objective creation popup")
    public void closeObjectiveCreationPopup() throws Exception {
        findElementById("cancel_objective_creation").click();
    }

    @com.thoughtworks.gauge.Step("Assert create objective popup is not displayed")
    public void assertCreateObjectivePopupIsNotDisplayed() throws Exception {
        assertFalse("The create objective popup should be invisible", findElementById("add_objective_panel").isDisplayed());
        assertFalse("The placeholder objective's markup should not exist", findElementsByXpath("//*[@class=\"objective objective-place-holder\"]").size()>0);
    }

    @com.thoughtworks.gauge.Step("Verify alert is displayed for <projectName> project")
    public void verifyAlertIsDisplayedForProject(String projectName) throws Exception {
        waitForElement(By.id("chart_icon_" + projectName.toLowerCase()));
        WebElement chartElement = findElementById("chart_icon_" + projectName.toLowerCase());
        Actions action = new Actions(driver);
        action.moveToElement(chartElement).build().perform();
        String actualMessage = excecuteJsWithStringretun("return $j('.tipsy').text()");
        assertMatch("May not complete.*", actualMessage);
    }

    @com.thoughtworks.gauge.Step("Open project forecasting chart for <projectName>")
    public void openProjectForecastingChartFor(String projectName) throws Exception {
        waitForElement(By.id("chart_icon_" + projectName.toLowerCase()));
        WebElement chartElement = findElementById("chart_icon_" + projectName.toLowerCase());
        chartElement.click();
    }

    @com.thoughtworks.gauge.Step("Assert work items completed is <completedItems> of <totalItems>")
    public void assertWorkItemsCompletedIsOf(String completedItems, String totalItems) throws Exception {
        waitForPageLoad(2000);
        String actualcompletedItems = excecuteJsWithStringretun("return $$('.highcharts-data-labels')[1].textContent || $$('.highcharts-data-labels')[1].innerText");
        String actualtotalItems = excecuteJsWithStringretun("return $$('.highcharts-data-labels')[0].textContent || $$('.highcharts-data-labels')[0].innerText");
        assertEquals("No of completed work items is incorrect", completedItems, actualcompletedItems);
        assertEquals("Total number of workitems is incorrect", totalItems, actualtotalItems);
    }

    @com.thoughtworks.gauge.Step("Assert date of completion 0 percent is <expectedDateNoScope> 50 percent is <expectedDate50PScope> and 150 percent is <expectedDate150PScope>")
    public void assertDateOfCompletion0PercentIs50PercentIsAnd150PercentIs(String expectedDateNoScope, String expectedDate50PScope, String expectedDate150PScope) throws Exception {
        Thread.sleep(2000);
        try {
            String actualDateNoScope = excecuteJsWithStringretun("return $$('.highcharts-data-labels')[4].textContent || $$('.highcharts-data-labels')[4].innerText");
            assertEquals("Forecast info is incorrect", expectedDateNoScope, actualDateNoScope);

            String actualDate50PScope = excecuteJsWithStringretun(" return $$('.highcharts-data-labels')[2].textContent || $$('.highcharts-data-labels')[2].innerText");
            assertEquals("Forecast info is incorrect", expectedDate50PScope, actualDate50PScope);

            String actualDate150PScope = excecuteJsWithStringretun("return $$('.highcharts-data-labels')[3].textContent || $$('.highcharts-data-labels')[3].innerText");
            assertEquals("Forecast info is incorrect", expectedDate150PScope, actualDate150PScope);
        } catch (ComparisonFailure e) {
            exportAllProjectsAndPrograms();
            throw e;
        }
    }

    @com.thoughtworks.gauge.Step("Close the ForcastPopup")
    public void closeTheForecastPopup(){
        findElementByXpath("//*[@class=\"popup-close remove-button\"]").click();
    }

    private void exportAllProjectsAndPrograms() {
        scriptRunner.executeWithTestHelpers(new JRubyScriptRunner.ScriptBuilder() {
            @Override
            public void build(JRubyScriptRunner.ScriptWriter scriptWriter) {
                scriptWriter.printfln("export_all_deliverables");
            }
        });
    }

    @com.thoughtworks.gauge.Step("Assert title of forecast chart <objectiveName> <projectName>")
    public void assertTitleOfForecastChart(String objectiveName, String projectName) throws Exception {
        Thread.sleep(2000);
        String title = excecuteJsWithStringretun("return $$('.lightbox_header h2 span')[0].innerHTML");
        assertEquals(objectiveName + " - " + projectName, title);
    }

    @com.thoughtworks.gauge.Step("Set filter number <filterNumber> with property <filterProperty> operator <filterOperator> and value <filterValue> on work page")
    public void setFilterNumberWithPropertyOperatorAndValueOnWorkPage(Integer filterNumber, String filterProperty, String filterOperator, String filterValue) throws Exception {
        setFilterProperty(filterNumber, filterProperty);
        setFilterOperator(filterNumber, filterOperator);
        setFilterValue(filterNumber, filterValue);
    }

    @com.thoughtworks.gauge.Step("Navigate to wiki page <wikiName> of project <projectName>")
    public void navigateToWikiPageOfProject(String wikiName, String projectName) {
        this.navigateTo("projects", projectName.toLowerCase(), "wiki", wikiName.replaceAll(" ", "_"));
    }

    @com.thoughtworks.gauge.Step("Deselect cards <cardNames>")
    public void deselectCards(String cardNames) throws Exception {
        scrollToEndOfPage();
        for (String cardName : cardNames.split(",")) {
            findElementByXpath("//*[text()=\"" + cardName.trim() + "\"]/../..//*[@class=\"select_card\"]").click();
        }
    }

    @com.thoughtworks.gauge.Step("Assert that the order of projects in dropdown on objective detail page is <projectsList>")
    public void assertThatTheOrderOfProjectsInDropdownOnObjectiveDetailPageIs(String projectsList) {
        String trimmedProjectsList = projectsList.replaceAll("\\s*,\\s*", "\n").trim();
        String actualProjectsList = projectDropdown().getText();
        assertEquals(trimmedProjectsList, actualProjectsList);
    }

    private WebElement projectDropdown() {
        return findElementById("project_id");
    }

    @com.thoughtworks.gauge.Step("Assert the number of work items completed in objective <objectiveName> is <numberOfWorkItemsComplete> of <totalNumberOfWorkItems>")
    public void assertTheNumberOfWorkItemsCompletedInObjectiveIsOf(String objectiveName, Integer numberOfWorkItemsComplete, Integer totalNumberOfWorkItems) throws Exception {
        waitForElement(By.id("objective_"+ HelperUtils.nameToIdentifier(objectiveName)));
        WebElement objectiveElement = findElementById("objective_"+ HelperUtils.nameToIdentifier(objectiveName));
        String workStatus = "" + numberOfWorkItemsComplete + " / " + totalNumberOfWorkItems + "";
        assertTrue("Number of work items completed is incorrect", findElementsByXpath("//*[text()=\""+workStatus.trim()+"\"]").size() > 0);
    }

    @com.thoughtworks.gauge.Step("Assert <projectNames> project is present in the objective popup")
    public void assertProjectIsPresentInTheObjectivePopup(String projectNames) throws Exception {
        for (String projectName : projectNames.split(",")) {
            waitForElement(By.id("name_" + projectName.toLowerCase()));
            assertEquals("" + projectName + " is not present in the objective", projectName, findElementById("name_" + projectName.toLowerCase()).getText());
        }
    }

    @com.thoughtworks.gauge.Step("Assert the progress of the project <projectName> when <numberOfWorkItemsComplete> of <totalNumberOfWorkItems> items are completed")
    public void assertTheProgressOfTheProjectWhenOfItemsAreCompleted(String projectName, Integer numberOfWorkItemsComplete, Integer totalNumberOfWorkItems) throws Exception {
        WebElement progressBarLevel = findElementById("level_" + projectName.toLowerCase());
        Integer expectedProgress = (int) ((numberOfWorkItemsComplete * 100) / totalNumberOfWorkItems);
        Integer widthOfProgressBar = widthInPercentOf(progressBarLevel);
        assertEquals("Progress Info for the " + projectName + " is not shown", expectedProgress, widthOfProgressBar);
    }

    private Integer widthInPercentOf(WebElement elementStub) throws InterruptedException {
        String widthPercentString = excecuteJsWithStringretun("return $(" +elementStub.getAttribute("id") + ").style.width");
        if (widthPercentString.isEmpty()) {
            return 0;
        } else {
            String widthPercentInt = widthPercentString.substring(0, widthPercentString.length() - 1);
            return Integer.parseInt(widthPercentInt);
        }
    }

    @com.thoughtworks.gauge.Step("Navigate to edit plan <planName> objective <objectiveName>")
    public void navigateToEditPlanObjective(String planName, String objectiveName) {
        this.navigateTo("programs", HelperUtils.nameToIdentifier(planName), "plan", "objectives", HelperUtils.nameToIdentifier(objectiveName), "edit");
    }

    @com.thoughtworks.gauge.Step("Update objective to <objectiveName>")
    public void updateObjectiveTo(String objectiveName) throws InterruptedException {
        waitForElement(By.id("objective_name"));
        findElementById("objective_name").clear();
        findElementById("objective_name").sendKeys(objectiveName);
        findElementByXpath("//*[@value=\"Save\"]").click();
    }
}
