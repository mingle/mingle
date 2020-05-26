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

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import net.sf.sahi.client.Browser;
import net.sf.sahi.client.ElementStub;

import com.thoughtworks.mingle.planner.smokeTest.util.Assertions;
import com.thoughtworks.mingle.planner.smokeTest.util.HelperUtils;

public class TeamMemberFixture extends Assertions {

    public TeamMemberFixture(Browser browser) {
        super(browser);

    }

    @com.thoughtworks.gauge.Step("Navigate to team members list page of program <planName>")
	public void navigateToTeamMembersListPageOfProgram(String planName) throws Exception {
        browser.navigateTo(pathTo("programs", HelperUtils.nameToIdentifier(planName), "team"));
    }

    @com.thoughtworks.gauge.Step("Open add team members page")
	public void openAddTeamMembersPage() throws Exception {
        browser.link("Add team member").click();
    }

    @com.thoughtworks.gauge.Step("Add user <login> to program")
	public void addUserToProgram(String login) throws Exception {
        browser.link("Add to team").in(browser.cell(login).parentNode()).click();
    }

    @com.thoughtworks.gauge.Step("Search team members by <searchKey>")
	public void searchTeamMembersBy(String searchKey) throws Exception {
        browser.textbox("search-query").setValue(searchKey);
        browser.button("user-search-submit").click();
    }

    @com.thoughtworks.gauge.Step("Assert that there are <numberOfMembers> team members for program")
	public void assertThatThereAreTeamMembersForProgram(Integer numberOfMembers) throws Exception {
        int actualNumberOfTeamMembers = getNumberOfRowsInTable() - 1;
        assertTrue("The number of members of current plan is: " + actualNumberOfTeamMembers + " , NOT: " + numberOfMembers, actualNumberOfTeamMembers == numberOfMembers);
    }

    private int getNumberOfRowsInTable() throws Exception {
        int numberOfRows = 0;
        while (browser.row(numberOfRows).exists()) {
            numberOfRows++;
        }
        return numberOfRows;
    }

    @com.thoughtworks.gauge.Step("Assert that <login> is on team members list")
	public void assertThatIsOnTeamMembersList(String login) throws Exception {
        assertTrue("User login is: " + login + " doesn't appear on Team Members list for current plan. ", browser.cell(login).under(browser.tableHeader("Sign-in name")).isVisible());
    }

    @com.thoughtworks.gauge.Step("Assert that cannot add light user <login> to program")
	public void assertThatCannotAddLightUserToProgram(String login) throws Exception {
        ElementStub userRow = browser.cell(login).under(browser.tableHeader("Sign-in name")).parentNode();
        assertFalse("Add to team link is visible for user login is: ADMIN", userRow.containsText("Add to team"));

        String lightUserMsg = "Light user cannot be added as program team member";
        assertTrue("The expected msg: '" + lightUserMsg + "' doesn't appear for user login is: " + login, userRow.containsText(lightUserMsg));
    }

    @com.thoughtworks.gauge.Step("Assert that cannot add existing member <login> to program")
	public void assertThatCannotAddExistingMemberToProgram(String login) throws Exception {
        ElementStub userRow = browser.cell(login).under(browser.tableHeader("Sign-in name")).parentNode();
        assertFalse("Add to team link is visible for user login is: ADMIN", userRow.containsText("Add to team"));

        String existingMemberMsg = "Existing team member";
        assertTrue("The expected msg: '" + existingMemberMsg + "' doesn't appear for user login is: " + login, userRow.containsText(existingMemberMsg));
    }

    @com.thoughtworks.gauge.Step("Assert that users <userLoginsString> are displayed on team members list")
	public void assertThatUsersAreDisplayedOnTeamMembersList(String userLoginsString) throws Exception {
        String[] userLoginsArray = HelperUtils.arrayFromString(userLoginsString);
        for (String login : userLoginsArray) {
            assertTrue("USER: '" + login + "' DOESN'T APPEAR ON TEAM LIST. ", browser.cell(login).under(browser.tableHeader("Sign-in name").parentNode()).exists());
        }
    }

    @com.thoughtworks.gauge.Step("Assert that users <userLoginsString> are not displayed on team members list")
	public void assertThatUsersAreNotDisplayedOnTeamMembersList(String userLoginsString) throws Exception {
        String[] userLogins = HelperUtils.arrayFromString(userLoginsString);
        for (String login : userLogins) {
            assertFalse("The user is there", browser.cell(login).under(browser.tableHeader("Sign-in name")).exists());
        }
    }

    @com.thoughtworks.gauge.Step("Assert that users <userLoginsString> can be added to program")
	public void assertThatUsersCanBeAddedToProgram(String userLoginsString) throws Exception {
        String[] userLoginsArray = HelperUtils.arrayFromString(userLoginsString);
        for (String login : userLoginsArray) {
            assertTrue("CANNOT ADD USER: '" + login + "' TO PLAN.", browser.link("Add to team").in(browser.cell(login).parentNode()).exists());
        }
    }

    @com.thoughtworks.gauge.Step("Clear the search query")
	public void clearTheSearchQuery() throws Exception {
        browser.button("search-all-users").click();
    }

    @com.thoughtworks.gauge.Step("Remove users <userLoginsString> from program")
	public void removeUsersFromProgram(String userLoginsString) throws Exception {
        selectUsers(userLoginsString);
        removeUsers();
    }

    @com.thoughtworks.gauge.Step("Select users <userLoginsString>")
	public void selectUsers(String userLoginsString) throws Exception {
        String[] userLoginsArray = HelperUtils.arrayFromString(userLoginsString);
        for (String login : userLoginsArray) {
            browser.checkbox(0).in(browser.cell(login).parentNode()).check();
        }
    }

    @com.thoughtworks.gauge.Step("Remove users")
	public void removeUsers() throws Exception {
        browser.submit("Remove").click();
    }

    @com.thoughtworks.gauge.Step("Back to team members page")
	public void backToTeamMembersPage() throws Exception {
        browser.link("Back").click();
    }

    @com.thoughtworks.gauge.Step("Assert that search query keyword is <keyword>")
	public void assertThatSearchQueryKeywordIs(String keyword) throws Exception {
        assertTrue("THE SEARCH QUERY IS NOT: " + keyword, browser.textbox("search-query").getValue().equals(keyword));
    }

    public void assertThatUsersAreSelected(String userLoginsString) throws Exception {
        String[] userLoginsArray = HelperUtils.arrayFromString(userLoginsString);
        for (String login : userLoginsArray) {
            assertTrue("USER: '" + login + "'  IS NOT SELECTED. ", browser.checkbox(0).in(browser.cell(login).parentNode()).checked());
        }
    }

    @com.thoughtworks.gauge.Step("Assert that <userLogin> is the first user on current page")
	public void assertThatIsTheFirstUserOnCurrentPage(String userLogin) throws Exception {
        assertTrue("The first user on currect page is not: " + userLogin, browser.cell(2).in(browser.row(1)).getText().equals(userLogin));
    }

    @com.thoughtworks.gauge.Step("Assert that <userLogin> is the last user on current page")
	public void assertThatIsTheLastUserOnCurrentPage(String userLogin) throws Exception {
        assertTrue("The last user on currect page is not: " + userLogin, browser.cell(2).in(browser.row(25)).getText().equals(userLogin));
    }

}
