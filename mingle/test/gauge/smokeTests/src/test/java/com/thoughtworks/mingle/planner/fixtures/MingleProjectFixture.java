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
import static junit.framework.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import net.sf.sahi.client.Browser;
import net.sf.sahi.client.BrowserCondition;
import net.sf.sahi.client.ElementStub;
import net.sf.sahi.client.ExecutionException;

import com.thoughtworks.mingle.planner.smokeTest.util.Assertions;
import com.thoughtworks.mingle.planner.smokeTest.util.HelperUtils;

public class MingleProjectFixture extends Assertions {

    public MingleProjectFixture(Browser browser) {
        super(browser);
    }

    @com.thoughtworks.gauge.Step("Login as <login>")
	public void loginAs(String login) throws Exception {
        while (browser.link("Sign out").exists()) {
            logoutMingle();
        }
        browser.navigateTo(pathTo("profile", "login"));
        browser.textbox("user[login]").setValue(login);
        browser.password("user[password]").setValue("test123.");
        browser.submit("commit").click();
    }

    @com.thoughtworks.gauge.Step("Login as anon user")
	public void loginAsAnonUser() throws Exception {
        if (browser.link("Sign out").exists()) {
            logoutMingle();
        }
    }

    @com.thoughtworks.gauge.Step("Logout mingle")
	public void logoutMingle() throws Exception {
        browser.navigateTo(pathTo("profile", "logout"));
    }

    @com.thoughtworks.gauge.Step("Click profile link for current user")
	public void clickProfileLinkForCurrentUser() throws Exception {
        browser.link("profile").click();
    }

    @com.thoughtworks.gauge.Step("Create a wiki <pageName> of project <projectName>")
	public void createAWikiOfProject(String pageName, String projectName) throws Exception {
        browser.navigateTo(pathTo("projects", projectName.toLowerCase(), "wiki", pageName));
        browser.link(HelperUtils.returnLinkText(browser, "Save")).click();
    }

    @com.thoughtworks.gauge.Step("Create a table macro with where clause of <whereClause> in wiki <pageName> of project <projectName>")
	public void createATableMacroWithWhereClauseOfInWikiOfProject(String whereClause, String pageName, String projectName) throws Exception {
        createATableMacroWithWhereClauseOfInWikiOfProjectWithoutSaving(whereClause, pageName, projectName);
        browser.link(HelperUtils.returnLinkText(browser, "Save")).click();
    }

    public void createATableMacroWithWhereClauseOfInWikiOfProjectWithoutSaving(String whereClause, String pageName, String projectName) throws Exception {
        browser.navigateTo(pathTo("projects", projectName.toLowerCase(), "wiki", pageName, "edit"));
        String pageContent = "  table\n" + "    query: SELECT number, name where " + whereClause;

        openMacroEditorWithRetries("cke_dialog_ui_input_textarea", 3);

        browser.textarea("/cke_.*_textarea/").setValue(pageContent);
        browser.link("OK").click();
        Thread.sleep(1000);
    }

    private void openMacroEditorWithRetries(String textareaLocator, int retries) {
        int i;
        for (i = 0; i < retries; i++) {
            browser.link("Insert Macro").click();
            browser.waitFor(new BrowserCondition(browser) {
                public boolean test() throws ExecutionException {
                    return isBrowserVisible();
                }

            }, 2000);
            if (isBrowserVisible()) {
                break;
            }
        }

        assertFalse(i == retries);
    }

    private boolean isBrowserVisible() {
        String visibility = "";
        if (browser.isChrome()) {
            visibility = browser.table("cke_dialog cke_browser_webkit cke_ltr cke_single_page").style("visibility");
        } else {
            visibility = browser.table("cke_dialog cke_browser_ie cke_browser_ie9 cke_ltr cke_single_page").style("visibility");
        }

        return visibility.equals("visible");
    }

    @com.thoughtworks.gauge.Step("Open card number <cardNumber> from project <projectName>")
	public void openCardNumberFromProject(String cardNumber, String projectName) throws Exception {
        browser.navigateTo(pathTo("projects", projectName.toLowerCase(), "cards", cardNumber));
        Thread.sleep(1000);
    }

    @com.thoughtworks.gauge.Step("Open card number <cardNumber> from project <projectName> to edit")
	public void openCardNumberFromProjectToEdit(String cardNumber, String projectName) throws Exception {
        browser.navigateTo(pathTo("projects", projectName.toLowerCase(), "cards", cardNumber, "edit"));
    }

    public void openCardListViewOfProject(String projectName) throws Exception {
        browser.navigateTo(pathTo("projects", projectName.toLowerCase(), "cards/list?style=list&tab=All"));
    }

    @com.thoughtworks.gauge.Step("Open card version <cardVersion> for card <cardNumber> from project <projectName>")
	public void openCardVersionForCardFromProject(String cardVersion, String cardNumber, String projectName) throws Exception {
        browser.navigateTo(pathTo("projects", projectName.toLowerCase(), "cards", cardNumber, "?version=" + cardVersion));
    }

    @com.thoughtworks.gauge.Step("Bulk update <propertyName> of cards number <cardNames> of project <projectName> from <propValFrom> to <propValTo>")
	public void bulkUpdateOfCardsNumberOfProjectFromTo(String propertyName, String cardNames, String projectName, String propValFrom, String propValTo) throws Exception {
        openCardListViewOfProject(projectName);
        checkCardsOnListView(cardNames);
        browser.link("Edit properties").click();
        waitForAjaxCallFinished();
        browser.link(propValFrom).near(browser.span(propertyName)).click();
        browser.listItem(propValTo).click();
        waitForAjaxCallFinished();
        browser.link("Edit properties").click();
        unCheckCardsNumbersOnListView(cardNames);
    }

    @com.thoughtworks.gauge.Step("Update card name to <cardName>")
	public void updateCardNameTo(String cardName) throws Exception {
        browser.link(HelperUtils.returnLinkText(browser, "Edit")).click();
        browser.textbox("card[name]").setValue(cardName);
        saveCard();
    }

    @com.thoughtworks.gauge.Step("Save card")
	public void saveCard() throws Exception {
        browser.link(HelperUtils.returnLinkText(browser, "Save")).click();
    }

    @com.thoughtworks.gauge.Step("Navigate to users list page")
	public void navigateToUsersListPage() throws Exception {
        browser.navigateTo(pathTo("users"));
    }

    @com.thoughtworks.gauge.Step("Change user <login> to light user")
	public void changeUserToLightUser(String login) throws Exception {
        browser.checkbox("light-user").near(browser.cell(login)).check();
    }

    // Private methods

    private void checkCardsOnListView(String cardNames) {
        for (String cardName : cardNames.split(",")) {
            browser.checkbox(0).in(browser.cell(cardName).parentNode()).check();
        }
    }

    private void unCheckCardsNumbersOnListView(String cardNames) {
        for (String cardName : cardNames.split(",")) {
            browser.checkbox(0).in(browser.cell(cardName).parentNode()).uncheck();
        }
    }

    // Public assertions
    public void assertThatErrorMessageAppearsOnWikiPageContent(String errorMessage) throws Exception {
        String actualMessage = browser.div("error").getText();
        assertTrue(actualMessage.contains(errorMessage));
        browser.link("Cancel").click();
    }

    @com.thoughtworks.gauge.Step("Assert that program name <planName> is displayed next to mingle logo")
	public void assertThatProgramNameIsDisplayedNextToMingleLogo(String planName) throws Exception {
        assertTrue(planName + " is not next to Mingle Logo. ", browser.link(planName).near(browser.link("logo_link")).exists());
    }

    @com.thoughtworks.gauge.Step("Assert current page is profile page for <loginName>")
	public void assertCurrentPageIsProfilePageFor(String loginName) throws Exception {
        assertEquals(loginName, browser.span("user_login").getText());
    }

    public void assertThatTheOrderOfButtonsOnCardshowIs(String buttonName, String plansList) throws Exception {
        String buttonTextList = browser.div("addable_plans").getText().replace(buttonName, "");
        String trimmedActualButtonList = buttonTextList.replaceAll("  ", ",").trim();
        String expectedButtonList = plansList.replaceAll("\\s*,\\s*", ",").trim();
        assertEquals(expectedButtonList, trimmedActualButtonList);
    }

    @com.thoughtworks.gauge.Step("Assert that the cards <cardNumbers> are displayed on page")
	public void assertThatTheCardsAreDisplayedOnPage(String cardNumbers) throws Exception {
        String[] cardNumber = cardNumbers.replaceAll("\\s*,\\s*", ",").trim().split(",");
        for (String number : cardNumber) {
            assertTrue("Card number " + number + " is not displayed on page. ", browser.cell(number).under(browser.tableHeader("Number")).isVisible());
        }
    }

    @com.thoughtworks.gauge.Step("Assert that the cards <cardNumbers> are not displayed on page")
	public void assertThatTheCardsAreNotDisplayedOnPage(String cardNumbers) throws Exception {
        String[] cardNumber = cardNumbers.replaceAll("\\s*,\\s*", ",").trim().split(",");
        for (String number : cardNumber) {
            assertFalse("Card number " + number + " is displayed on page. ", browser.cell(number).under(browser.tableHeader("Number")).isVisible());
        }
    }

    @com.thoughtworks.gauge.Step("Assert that current page is login page")
	public void assertThatCurrentPageIsLoginPage() throws Exception {
        assertCurrentPageIs("/profile/login");
    }

    @com.thoughtworks.gauge.Step("Enable anonymous access for project <projectName>")
	public void enableAnonymousAccessForProject(String projectName) throws Exception {
        browser.navigateTo(pathTo("projects", projectName.toLowerCase()));
        browser.link("Project admin").click();
        browser.link("Project settings").click();
        browser.link("options-toggle-link").click();
        browser.checkbox("project_anonymous_accessible").click();
        browser.link(HelperUtils.returnLinkText(browser, "Save")).click();
    }

    @com.thoughtworks.gauge.Step("Assert that the plan <planName> is on card")
	public void assertThatThePlanIsOnCard(String planName) throws Exception {
        assertTrue(browser.isVisible(browser.byId("plan_" + HelperUtils.nameToIdentifier(planName))));
    }

    @com.thoughtworks.gauge.Step("Select objective for plan <objectiveName> <planName>")
	public void selectObjectiveForPlan(String objectiveName, String planName) throws Exception {
        clickEditObjectivesLinkForPlan(planName);
        checkOrUnCheckObjective(objectiveName);
        saveSelectedObjective();
    }

    @com.thoughtworks.gauge.Step("Deselect objective for plan <objectiveName> <planName>")
	public void deselectObjectiveForPlan(String objectiveName, String planName) throws Exception {
        clickEditObjectivesLinkForPlan(planName);
        checkOrUnCheckObjective(objectiveName);
        saveSelectedObjective();
    }

    @com.thoughtworks.gauge.Step("Check or un check objective <objectiveName>")
	public void checkOrUnCheckObjective(String objectiveName) {
        browser.label(objectiveName).click();
    }

    @com.thoughtworks.gauge.Step("Save selected objective")
	public void saveSelectedObjective() {
        browser.byId("save_selected_objectives").click();
        waitForAjaxCallFinished();
    }

    @com.thoughtworks.gauge.Step("Click cancel edit objective popup")
	public void clickCancelEditObjectivePopup() throws Exception {
        browser.byId("dismiss_lightbox_button").click();
        waitForAjaxCallFinished();
    }

    public void assertThatThePlanNotPresentOnCard(String planName) throws Exception {
        assertFalse(browser.isVisible(browser.byId("plan_" + HelperUtils.nameToIdentifier(planName))));
    }

    @com.thoughtworks.gauge.Step("Save and add another card")
	public void saveAndAddAnotherCard() throws Exception {
        browser.link(HelperUtils.returnLinkText(browser, "Save and add another")).click();
    }

    @com.thoughtworks.gauge.Step("Save and add another card with name <cardName>")
	public void saveAndAddAnotherCardWithName(String cardName) throws Exception {
        browser.link(HelperUtils.returnLinkText(browser, "Save and add another")).click();
        inputCardName(cardName);
        saveCard();
    }

    @com.thoughtworks.gauge.Step("Input card name <name>")
	public void inputCardName(String name) {
        browser.byId("card_name").setValue(name);
    }

    @com.thoughtworks.gauge.Step("Copy card to project <projectName> and open it")
	public void copyCardToProjectAndOpenIt(String projectName) throws Exception {
        browser.link(HelperUtils.returnLinkText(browser, "Copy to...")).click();
        Thread.sleep(2000);
        browser.byId("select_project_drop_link").click();
        Thread.sleep(2000);
        browser.byId("select_project_option_" + projectName).click();
        browser.byId("continue-copy-to").click();
        waitForAjaxCallFinished();
        browser.link(HelperUtils.returnLinkText(browser, "Continue to copy")).click();
        waitForAjaxCallFinished();
        browser.link(0).near(browser.span("card_number")).click();
    }

    @com.thoughtworks.gauge.Step("Create card type <cardTypeName> in project <projectName>")
	public void createCardTypeInProject(final String cardTypeName, final String projectName) throws Exception {
        browser.navigateTo(pathTo("projects", projectName.toLowerCase(), "card_types", "new"));
        browser.byId("card_type_name").setValue(cardTypeName);
        browser.link(HelperUtils.returnLinkText(browser, "Create type")).click();

    }

    @com.thoughtworks.gauge.Step("Create managed text property <propertyName> with values <values> in project <projectName> without card type")
	public void createManagedTextPropertyWithValuesInProjectWithoutCardType(String propertyName, String values, String projectName) throws Exception {
        browser.navigateTo(pathTo("projects", projectName.toLowerCase(), "property_definitions", "new"));
        browser.byId("property_definition_name").setValue(propertyName);
        browser.byId("select_none").click();
        browser.link(HelperUtils.returnLinkText(browser, "Create property")).click();

        browser.link("0 values").click();
        for (String value : values.split(",")) {
            browser.byId("enumeration_value_input_box").setValue(value);
            browser.submit("submit-quick-add").click();
        }
    }

    @com.thoughtworks.gauge.Step("Update card property <oldpropertyName> as <newPropertyName> in project <projectName>")
	public void updateCardPropertyAsInProject(String oldpropertyName, String newPropertyName, String projectName) throws Exception {
        browser.navigateTo(pathTo("projects", projectName.toLowerCase(), "property_definitions"));
        browser.click(browser.link("Edit").near(browser.div(oldpropertyName)));
        browser.byId("property_definition_name").setValue(newPropertyName);
        browser.link(HelperUtils.returnLinkText(browser, "Save property")).click();

    }

    @com.thoughtworks.gauge.Step("Click edit objectives link for plan <planName>")
	public void clickEditObjectivesLinkForPlan(String planName) throws Exception {
        browser.byId("edit_plan_" + HelperUtils.nameToIdentifier(planName) + "_objectives_link").click();
        waitForAjaxCallFinished();
    }

    @com.thoughtworks.gauge.Step("Assert objectives <objectiveNames> are present on edit objectives popup")
	public void assertObjectivesArePresentOnEditObjectivesPopup(String objectiveNames) throws Exception {
        for (String objectiveName : objectiveNames.split(",")) {
            assertTrue("objective " + objectiveName + " is not present", browser.label(objectiveName).exists());

        }

    }

    @com.thoughtworks.gauge.Step("Assert objectives <objectiveNames> is set for auto synced objective")
	public void assertObjectivesIsSetForAutoSyncedObjective(String objectiveNames) throws Exception {
        for (String objectiveName : objectiveNames.split(",")) {
            assertTrue("objective " + objectiveName + " is not present", browser.byId("auto_sync_objective_" + HelperUtils.nameToIdentifier(objectiveName)).exists());
            assertEquals("objective " + objectiveName + " is not checked", "true", browser.fetch("$('auto_sync_objective_" + HelperUtils.nameToIdentifier(objectiveName) + "').checked"));
            assertEquals("objective " + objectiveName + " is not disabled", "true", browser.fetch("$('auto_sync_objective_" + HelperUtils.nameToIdentifier(objectiveName) + "').disabled"));

        }

    }

    @com.thoughtworks.gauge.Step("Assert objectives <objectiveNames> is checked")
	public void assertObjectivesIsChecked(String objectiveNames) throws Exception {
        for (String objectiveName : objectiveNames.split(",")) {
            assertTrue("Feature " + objectiveName + "is not checked", browser.byId("objective_" + HelperUtils.nameToIdentifier(objectiveName)).checked());
        }
    }

    @com.thoughtworks.gauge.Step("Assert edit objectives link is disabled for plan <planName>")
	public void assertEditObjectivesLinkIsDisabledForPlan(String planName) throws Exception {

        assertEquals("plan-objective disabled", browser.byId("edit_plan_" + HelperUtils.nameToIdentifier(planName) + "_objectives_link").fetch("className"));

    }

    @com.thoughtworks.gauge.Step("Assert that on card that card belongs to objective <objectiveNames> of plan <planName>")
	public void assertThatOnCardThatCardBelongsToObjectiveOfPlan(String objectiveNames, String planName) throws Exception {
        for (String objectiveName : objectiveNames.split(",")) {
            assertTrue("objective :" + objectiveName + " does not belong to plan :" + planName, browser.div(objectiveName).in(browser.byId("plan_" + HelperUtils.nameToIdentifier(planName) + "_objectives")).exists());
        }

    }

    @com.thoughtworks.gauge.Step("Assert that on card that card does not belongs to objective <objectiveNames> of plan <planName>")
	public void assertThatOnCardThatCardDoesNotBelongsToObjectiveOfPlan(String objectiveNames, String planName) throws Exception {
        for (String objectiveName : objectiveNames.split(",")) {
            assertFalse("objective :" + objectiveName + " does not belong to plan :" + planName, browser.div(objectiveName).in(browser.byId("plan_" + HelperUtils.nameToIdentifier(planName) + "_objectives")).exists());
        }
    }

    @com.thoughtworks.gauge.Step("Open card <cardName>")
	public void openCard(String cardName) throws Exception {
        browser.link(cardName).click();
    }

    @com.thoughtworks.gauge.Step("Navigate to project <projectName> property definitions page")
	public void navigateToProjectPropertyDefinitionsPage(String projectName) throws Exception {
        browser.navigateTo(pathTo("projects", projectName.toLowerCase(), "property_definitions"));
    }

    @com.thoughtworks.gauge.Step("Open enumerated values page of property <propertyName> using link <linkText>")
	public void openEnumeratedValuesPageOfPropertyUsingLink(String propertyName, String linkText) throws Exception {
        browser.click(browser.link(linkText).near(browser.div(propertyName)));

    }

    @com.thoughtworks.gauge.Step("Drag <status1> upwards above <status2>")
	public void dragUpwardsAbove(String status1, String status2) throws Exception {
        ElementStub element1 = browser.link("Drag").near(browser.span(status1));
        ElementStub element2 = browser.link("Drag").near(browser.span(status2));
        browser.execute("_sahi._dragDropXY(" + element1 + ", " + x_Location_Movement_From_Bottom(element1, element2) + ", " + y_Location_Movement_From_Bottom(element1, element2) + ", true)");
    }

    public int center_Of_Xcoordinate(ElementStub locator) {

        int left_x = getX(locator);
        int width = widthOf(locator);
        int result_x = left_x + width / 2;
        return result_x;

    }

    public int center_Of_Ycoordinate(ElementStub locator) {

        int top_y = getY(locator);
        int height = heightOf(locator);
        int result_y = top_y + height / 2;
        return result_y;
    }

    public int x_Location_Movement_From_Bottom(ElementStub locator1, ElementStub locator2) {
        int origin = center_Of_Xcoordinate(locator1);
        int destination = center_Of_Xcoordinate(locator2);
        int xloc = destination - origin;
        return xloc;
    }

    public int y_Location_Movement_From_Bottom(ElementStub locator1, ElementStub locator2) {
        int origin = center_Of_Ycoordinate(locator1);
        int destination = center_Of_Ycoordinate(locator2);
        System.out.println("Y loc");
        System.out.println(origin);
        System.out.println(destination);
        int yloc = destination - origin - 17;
        System.out.println(yloc);
        return yloc;
    }

    private int getX(ElementStub elementStub) {
        return parseInt(browser.fetch("$(" + elementStub + ").cumulativeOffset()[0]"));
    }

    private int getY(ElementStub elementStub) {
        int y = parseInt(browser.fetch("$(" + elementStub + ").cumulativeOffset()[1]"));
        return y;
    }

    private Integer heightOf(ElementStub elementStub) {
        return parseInt(browser.fetch("$(" + elementStub + ").getHeight()"));
    }

    private Integer widthOf(ElementStub elementStub) {
        return parseInt(browser.fetch("$(" + elementStub + ").getWidth()"));
    }

    @com.thoughtworks.gauge.Step("Assert that the objective <objectiveName> not present on card")
	public void assertThatTheObjectiveNotPresentOnCard(String objectiveName) throws Exception {
        assertFalse(browser.isVisible(browser.byId("objective_" + HelperUtils.nameToIdentifier(objectiveName))));
    }
}
