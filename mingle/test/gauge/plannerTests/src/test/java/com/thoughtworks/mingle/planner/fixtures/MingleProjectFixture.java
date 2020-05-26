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
import org.openqa.selenium.WebElement;

public class MingleProjectFixture extends Assertions {
    public MingleProjectFixture() {
        super();
    }

    @com.thoughtworks.gauge.Step("Login as <login>")
    public void loginAs(String login) throws Exception {
        this.driver.get(pathTo("profile", "login"));
        this.driver.findElement(By.id("user_login")).sendKeys(login);
        this.driver.findElement(By.id("user_password")).sendKeys("test123.");
        this.driver.findElement(By.name("commit")).click();
    }

    @com.thoughtworks.gauge.Step("Login as anon user")
    public void loginAsAnonUser() throws Exception {
        if (this.driver.findElement(By.id("logout")).isDisplayed()) {
            logoutMingle();
        }
    }
    @com.thoughtworks.gauge.Step("Logout mingle")
    public void logoutMingle() throws Exception {
        this.driver.get(pathTo("profile", "logout"));
    }

    @com.thoughtworks.gauge.Step("Open card number <cardNumber> from project <projectName>")
    public void openCardNumberFromProject(String cardNumber, String projectName) throws Exception {
        this.driver.get(pathTo("projects", projectName.toLowerCase(), "cards", cardNumber));
    }

    @com.thoughtworks.gauge.Step("Open card number <cardNumber> from project <projectName> to edit")
    public void openCardNumberFromProjectToEdit(String cardNumber, String projectName) throws Exception {
        this.driver.get(pathTo("projects", projectName.toLowerCase(), "cards", cardNumber, "edit"));
    }

    @com.thoughtworks.gauge.Step("Assert that the plan <planName> is on card")
    public void assertThatThePlanIsOnCard(String planName) throws Exception {
        waitForElement(By.id("plan_"+HelperUtils.nameToIdentifier(planName)));
        assertTrue(this.driver.findElements(By.id("plan_"+HelperUtils.nameToIdentifier(planName))).size()>0);

    }

    @com.thoughtworks.gauge.Step("Select objective for plan <objectiveName> <planName>")
    public void selectObjectiveForPlan(String objectiveName, String planName) throws Exception {
        scrollBy(0,300);
        clickEditObjectivesLinkForPlan(planName);
        checkOrUnCheckObjective(objectiveName);
        saveSelectedObjective();
    }

    @com.thoughtworks.gauge.Step("Click edit objectives link for plan <planName>")
    public void clickEditObjectivesLinkForPlan(String planName) throws Exception {
        scrollInToText(planName);
        waitForPageLoad(2000);
        this.driver.findElement(By.id("edit_plan_" + HelperUtils.nameToIdentifier(planName) + "_objectives_link")).click();
        waitForAjaxCallFinished();
    }

    @com.thoughtworks.gauge.Step("Check or un check objective <objectiveName>")
    public void checkOrUnCheckObjective(String objectiveName) throws InterruptedException {
        waitForElement(By.id("objective_"+ HelperUtils.nameToIdentifier(objectiveName)));
        this.driver.findElement(By.id("objective_"+ HelperUtils.nameToIdentifier(objectiveName))).click();
    }

    @com.thoughtworks.gauge.Step("Save selected objective")
    public void saveSelectedObjective() {
        this.driver.findElement(By.id("save_selected_objectives")).click();
        waitForAjaxCallFinished();
    }

    @com.thoughtworks.gauge.Step("Assert that on card that card belongs to objective <objectiveNames> of plan <planName>")
    public void assertThatOnCardThatCardBelongsToObjectiveOfPlan(String objectiveNames, String planName) throws Exception {
        scrollToEndOfPage();
        for (String objectiveName : objectiveNames.split(",")) {
            waitForPageLoad(2000);
            assertTrue("objective :" + objectiveName + " does not belong to plan :" + planName, findElementsByXpath("//*[@id=\"plan_"+HelperUtils.nameToIdentifier(planName)+"\"]/..//*[text()=\""+objectiveName.trim()+"\"]").size() > 0);
        }
    }

    @com.thoughtworks.gauge.Step("Save and add another card with name <cardName>")
    public void saveAndAddAnotherCardWithName(String cardName) throws Exception {
        scrollInToViewById("tab_overview_link");
        waitForElementClickable(By.xpath("//a[text()=\"Save and add another\"]"));
        findElementsByXpath("//a[text()=\"Save and add another\"]").get(0).click();
        inputCardName(cardName);
        saveCard();
        waitForElement(By.xpath("//*[contains(text(),\"" + cardName.trim() + "\")]"));
        assertTrue("failed to create card with card name"+cardName, findElementsByXpath("//*[contains(text(),\""+cardName.trim()+"\")]").size()>0);
    }

    @com.thoughtworks.gauge.Step("Input card name <name>")
    public void inputCardName(String name) throws InterruptedException {
        waitForPageLoad(4000);
        excecuteJs("$j('#card_name').click()");
        this.driver.findElement(By.id("card_name")).sendKeys(name);
    }

    @com.thoughtworks.gauge.Step("Save card")
    public void saveCard() throws Exception {
        this.driver.findElement(By.xpath("//a[text()=\"Save\"]")).click();
    }

    @com.thoughtworks.gauge.Step("Copy card to project <projectName> and open it")
    public void copyCardToProjectAndOpenIt(String projectName) throws Exception {
        findElementsByXpath("//*[text()=\"Copy to...\"]").get(0).click();
        waitForElement(By.className("drop_link_wrapper"));
        findElementById("select_project_drop_link").click();
        waitForElement(By.id("select_project_option_"+ projectName));
        findElementById("select_project_option_" + projectName).click();
        findElementById("continue-copy-to").click();
        waitForElement(By.xpath("//a[@class=\"ok\"]"));
        findElementByXpath("//a[@class=\"ok\"]").click();
        waitForElement(By.xpath("//*[@id=\"card_number\"]"));
        findElementByXpath("//*[@id=\"card_number\"]").click();
        waitForAjaxCallFinished();
    }

    @com.thoughtworks.gauge.Step("Deselect objective for plan <objectiveName> <planName>")
    public void deselectObjectiveForPlan(String objectiveName, String planName) throws Exception {
        clickEditObjectivesLinkForPlan(planName);
        checkOrUnCheckObjective(objectiveName);
        saveSelectedObjective();
    }

    @com.thoughtworks.gauge.Step("Assert that current page is login page")
    public void assertThatCurrentPageIsLoginPage() throws Exception {
        assertCurrentPageIs("/profile/login");
    }

    @com.thoughtworks.gauge.Step("Enable anonymous access for project <projectName>")
    public void enableAnonymousAccessForProject(String projectName) throws Exception {
        this.driver.get(pathTo("projects", projectName.toLowerCase()));
        waitForAjaxCallFinished();
        findElementByXpath("//*[text()=\"Project admin\"]").click();
        findElementByXpath("//a[text()=\"Project settings\"]").click();
        findElementById("options-toggle-link").click();
        waitForElement(By.id("project_anonymous_accessible"));
        scrollInToViewById("project_anonymous_accessible");
        findElementById("project_anonymous_accessible").click();
        findElementByXpath("//*[text()=\"Save\"]").click();
    }

    @com.thoughtworks.gauge.Step("Bulk update <propertyName> of cards number <cardNames> of project <projectName> from <propValFrom> to <propValTo>")
    public void bulkUpdateOfCardsNumberOfProjectFromTo(String propertyName, String cardNames, String projectName, String propValFrom, String propValTo) throws Exception {
        openCardListViewOfProject(projectName);
        checkCardsOnListView(cardNames);
        findElementById("bulk-set-properties-button").click();
        waitForElementClickable(By.xpath("//*[@title=\""+propertyName+"\"]/..//*[text()=\""+propValFrom+"\"]"));
        findElementByXpath("//*[@title=\""+propertyName+"\"]/..//*[text()=\""+propValFrom+"\"]").click();
        findElementByXpath("//text[text()=\""+propValTo+"\"]").click();
        waitForAjaxCallFinished();
        waitForPageLoad(2000);
        findElementById("bulk-set-properties-button").click();
        unCheckCardsNumbersOnListView(cardNames);
    }

    public void openCardListViewOfProject(String projectName) throws Exception {
        this.driver.get(pathTo("projects", projectName.toLowerCase(), "cards/list?style=list&tab=All"));
    }
    // Private methods
    private void checkCardsOnListView(String cardNames) throws InterruptedException {
        waitForPageLoad(2000);
        scrollToEndOfPage();
        for (String cardName : cardNames.split(",")) {
            String [] cardProperty = cardName.split("_");
            findElementByXpath("//a[@href=\"/projects/"+cardProperty[0].trim().toLowerCase()+"/cards/"+cardProperty[1].trim()+"\"]/../..//*[@type=\"checkbox\"]").click();
        }
        scrollToTopOfpage();
    }

    private void unCheckCardsNumbersOnListView(String cardNames) throws InterruptedException {
        waitForPageLoad(2000);
        scrollToEndOfPage();
        for (String cardName : cardNames.split(",")) {
            String [] cardProperty = cardName.split("_");
            findElementByXpath("//a[@href=\"/projects/"+cardProperty[0].trim().toLowerCase()+"/cards/"+cardProperty[1].trim()+"\"]/../..//*[@type=\"checkbox\"]").click();
        }
        scrollToTopOfpage();
    }

    @com.thoughtworks.gauge.Step("Update card property <oldpropertyName> as <newPropertyName> in project <projectName>")
    public void updateCardPropertyAsInProject(String oldpropertyName, String newPropertyName, String projectName) throws Exception {
        this.driver.get(pathTo("projects", projectName.toLowerCase(), "property_definitions"));
        waitForAjaxCallFinished();
        findElementByXpath("//a[text()='Edit']").click();
        waitForAjaxCallFinished();
        findElementById("property_definition_name").clear();
        findElementById("property_definition_name").sendKeys(newPropertyName);
        findElementByXpath("//a[text()=\"Save property\"]").click();
    }

    @com.thoughtworks.gauge.Step("Assert that the objective <objectiveName> not present on card")
    public void assertThatTheObjectiveNotPresentOnCard(String objectiveName) throws Exception {
        assertFalse("The Objective is part of the card ", findElementsById("objective_" + HelperUtils.nameToIdentifier(objectiveName)).size() > 0);
    }

    @com.thoughtworks.gauge.Step("Create card type <cardTypeName> in project <projectName>")
    public void createCardTypeInProject(final String cardTypeName, final String projectName) throws Exception {
        this.driver.get(pathTo("projects", projectName.toLowerCase(), "card_types", "new"));
        findElementById("card_type_name").sendKeys(cardTypeName);
        findElementsByXpath("//*[text()=\"Create type\"]").get(0).click();
    }

    @com.thoughtworks.gauge.Step("Create managed text property <propertyName> with values <values> in project <projectName> without card type")
    public void createManagedTextPropertyWithValuesInProjectWithoutCardType(String propertyName, String values, String projectName) throws Exception {
        this.driver.get(pathTo("projects", projectName.toLowerCase(), "property_definitions", "new"));
        findElementById("property_definition_name").sendKeys(propertyName);
        scrollInToViewById("select_none");
        findElementById("select_none").click();
        findElementsByXpath("//*[text()=\"Create property\"]").get(0).click();
        findElementByXpath(" //*[text()=\""+propertyName.trim()+"\"]/../..//a[text()=\"0 values\"]").click();
        for (String value : values.split(",")) {
            findElementById("enumeration_value_input_box").sendKeys(value);
            findElementById("submit-quick-add").click();
        }
    }

    @com.thoughtworks.gauge.Step("Click profile link for current user")
    public void clickProfileLinkForCurrentUser() throws Exception {
       findElementByCssSelector("a.profile").click();
    }

    @com.thoughtworks.gauge.Step("Assert current page is profile page for <loginName>")
    public void assertCurrentPageIsProfilePageFor(String loginName) throws Exception {
        waitForElement(By.id("user_login"));
        assertEquals(loginName.trim(), findElementById("user_login").getText().trim());
    }

    @com.thoughtworks.gauge.Step("Assert that program name <planName> is displayed next to mingle logo")
    public void assertThatProgramNameIsDisplayedNextToMingleLogo(String planName) throws Exception {
        assertTrue(planName + " is not next to Mingle Logo. ", findElementsByXpath("//*[@id=\"header_plan_name\"]/..//*[@id=\"logo_link\"]").size()>0);
    }

    @com.thoughtworks.gauge.Step("Navigate to project <projectName> property definitions page")
    public void navigateToProjectPropertyDefinitionsPage(String projectName) throws Exception {
        driver.get(pathTo("projects", projectName.toLowerCase(), "property_definitions"));
    }

    @com.thoughtworks.gauge.Step("Open enumerated values page of property <propertyName> using link <linkText>")
    public void openEnumeratedValuesPageOfPropertyUsingLink(String propertyName, String linkText) throws Exception {
        waitForElement(By.xpath("//*[text()=\""+propertyName.trim()+"\"]/../..//*[text()=\""+linkText+"\"]"));
        findElementByXpath("//*[text()=\""+propertyName.trim()+"\"]/../..//*[text()=\""+linkText+"\"]").click();
    }

    @com.thoughtworks.gauge.Step("Drag <status1> upwards above <status2>")
    public void dragUpwardsAbove(String status1, String status2) throws Exception {
        WebElement source = findElementByXpath("//*[text()=\""+status1.trim()+"\"]/../../..//a[text()=\"Drag\"]");
        WebElement destination = findElementByXpath("//*[text()=\""+status2.trim()+"\"]/../../..//a[text()=\"Drag\"]");
        dragAndDrop(source,destination);
    }

    @com.thoughtworks.gauge.Step("Update card name to <cardName>")
    public void updateCardNameTo(String cardName) throws Exception {
        waitForElement(By.id("card-edit-link-top"));
        findElementById("card-edit-link-top").click();
        waitForElement(By.id("card_name"));
        findElementById("card_name").clear();
        findElementById("card_name").sendKeys(cardName);
        saveCard();
    }

    @com.thoughtworks.gauge.Step("Open card version <cardVersion> for card <cardNumber> from project <projectName>")
    public void openCardVersionForCardFromProject(String cardVersion, String cardNumber, String projectName) throws Exception {
        driver.get(pathTo("projects", projectName.toLowerCase(), "cards", cardNumber, "?version=" + cardVersion));
    }

    @com.thoughtworks.gauge.Step("Create a wiki <pageName> of project <projectName>")
    public void createAWikiOfProject(String pageName, String projectName) throws Exception {
        driver.get(pathTo("projects", projectName.toLowerCase(), "wiki", pageName));
        findElementsByXpath("//*[@class=\"save\"]").get(0).click();
    }

    @com.thoughtworks.gauge.Step("Create a table macro with where clause of <whereClause> in wiki <pageName> of project <projectName>")
    public void createATableMacroWithWhereClauseOfInWikiOfProject(String whereClause, String pageName, String projectName) throws Exception {
        createATableMacroWithWhereClauseOfInWikiOfProjectWithoutSaving(whereClause, pageName, projectName);
        findElementsByXpath("//*[@class=\"save\"]").get(0).click();
    }

    public void createATableMacroWithWhereClauseOfInWikiOfProjectWithoutSaving(String whereClause, String pageName, String projectName) throws Exception {
        driver.get(pathTo("projects", projectName.toLowerCase(), "wiki", pageName, "edit"));
        String pageContent = "  table\n" + "    query: SELECT number, name where " + whereClause;
        openMacroEditorWithRetries("cke_dialog_ui_input_textarea");
        findElementByXpath("//*[@class=\"cke_dialog_ui_input_textarea\"]//textarea").sendKeys(pageContent);
        findElementByXpath("//*[text()=\"OK\"]").click();
        waitForPageLoad(1000);
    }

    private void openMacroEditorWithRetries(String textareaLocator) throws InterruptedException {
        waitForElement(By.xpath("//a[@title=\"Insert Macro\"]"));
        findElementByXpath("//a[@title=\"Insert Macro\"]").click();
        waitForElement(By.cssSelector("table.cke_dialog_contents"));
        findElementByXpath("//*[@class=\""+textareaLocator+"\"]//textarea").click();
        findElementByXpath("//*[@class=\""+textareaLocator+"\"]//textarea").clear();
        waitForPageLoad(1000);
    }

    @com.thoughtworks.gauge.Step("Assert that the cards <cardNumbers> are displayed on page")
    public void assertThatTheCardsAreDisplayedOnPage(String cardNumbers) throws Exception {
        String[] cardNumber = cardNumbers.replaceAll("\\s*,\\s*", ",").trim().split(",");
        for (String number : cardNumber) {
            assertTrue("Card number " + number + " is not displayed on page. ",findElementsByXpath("//a[@href=\"/projects/sap/cards/"+number+"\"]").size()>0);
        }
    }

    @com.thoughtworks.gauge.Step("Assert edit objectives link is disabled for plan <planName>")
    public void assertEditObjectivesLinkIsDisabledForPlan(String planName) throws Exception {
        assertEquals("plan-objective disabled", findElementById("edit_plan_" + HelperUtils.nameToIdentifier(planName) + "_objectives_link").getAttribute("class"));
    }

    @com.thoughtworks.gauge.Step("Assert objectives <objectiveNames> are present on edit objectives popup")
    public void assertObjectivesArePresentOnEditObjectivesPopup(String objectiveNames) throws Exception {
        waitForPageLoad(2000);
        for (String objectiveName : objectiveNames.split(",")) {
           assertTrue("objective " + objectiveName + " is not present", findElementsById("objective_"+HelperUtils.nameToIdentifier(objectiveName)).size()>0);
        }
    }

    @com.thoughtworks.gauge.Step("Assert objectives <objectiveNames> is checked")
    public void assertObjectivesIsChecked(String objectiveNames) throws Exception {
        waitForPageLoad(2000);
        for (String objectiveName : objectiveNames.split(",")) {
            assertTrue("Feature " + objectiveName + "is not checked", findElementById("objective_" + HelperUtils.nameToIdentifier(objectiveName)).isSelected());
        }
    }

    @com.thoughtworks.gauge.Step("Assert objectives <objectiveNames> is set for auto synced objective")
    public void assertObjectivesIsSetForAutoSyncedObjective(String objectiveNames) throws Exception {
        for (String objectiveName : objectiveNames.split(",")) {
            assertTrue("objective " + objectiveName + " is not present", findElementsById("auto_sync_objective_" + HelperUtils.nameToIdentifier(objectiveName)).size()>0);
            assertEquals("objective " + objectiveName + " is not checked", "true", excecuteJsWithStringretun(" return $('auto_sync_objective_" + HelperUtils.nameToIdentifier(objectiveName) + "').checked"));
            assertEquals("objective " + objectiveName + " is not disabled", "true", excecuteJsWithStringretun("return $('auto_sync_objective_" + HelperUtils.nameToIdentifier(objectiveName) + "').disabled"));

        }
    }

    @com.thoughtworks.gauge.Step("Click cancel edit objective popup")
    public void clickCancelEditObjectivePopup() throws Exception {
        findElementById("dismiss_lightbox_button").click();
        waitForAjaxCallFinished();
    }

    @com.thoughtworks.gauge.Step("Save and add another card")
    public void saveAndAddAnotherCard() throws Exception {
        waitForElement(By.xpath("//*[text()=\"Save and add another\"]"));
        findElementsByXpath("//*[text()=\"Save and add another\"]").get(0).click();
    }

    @com.thoughtworks.gauge.Step("Assert that on card that card does not belongs to objective <objectiveNames> of plan <planName>")
    public void assertThatOnCardThatCardDoesNotBelongsToObjectiveOfPlan(String objectiveNames, String planName) throws Exception {
        for (String objectiveName : objectiveNames.split(",")) {
            assertFalse("objective :" + objectiveName + " does not belong to plan :" + planName, findElementsByXpath("//*[@id=\"plan_"+HelperUtils.nameToIdentifier(objectiveName)+"_objectives\"]/..//*[@id=\"plan_"+HelperUtils.nameToIdentifier(planName)+"\"]").size() > 0);
        }
    }

    @com.thoughtworks.gauge.Step("Open card <cardName>")
    public void openCard(String cardName) throws Exception {
        waitForElement(By.id("card_list_view"));
        findElementByLinkText(cardName).click();
    }

    @com.thoughtworks.gauge.Step("Navigate to users list page")
    public void navigateToUsersListPage() throws Exception {
        this.driver.get(pathTo("users"));
    }

    @com.thoughtworks.gauge.Step("Change user <login> to light user")
    public void changeUserToLightUser(String login) throws Exception {
        waitForPageLoad(2000);
        findElementByXpath("//td[text()='"+login.trim()+"']/..//*[@name=\"light-user\"]").click();
        //flash notice takes time to appear
        waitForPageLoad(2000);
        waitForElement(By.id("notice"));
        assertTrue(findElementById("notice").getText().contains("light user."));
    }
}
