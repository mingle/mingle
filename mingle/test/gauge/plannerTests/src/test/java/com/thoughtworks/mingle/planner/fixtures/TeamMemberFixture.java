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

import java.util.List;

public class TeamMemberFixture extends Assertions {

    public TeamMemberFixture() {
        super();
    }

    @com.thoughtworks.gauge.Step("Navigate to team members list page of program <planName>")
    public void navigateToTeamMembersListPageOfProgram(String planName) throws Exception {
        this.driver.get(pathTo("programs", HelperUtils.nameToIdentifier(planName), "team"));
    }

    @com.thoughtworks.gauge.Step("Assert that <userLogin> is the first user on current page")
    public void assertThatIsTheFirstUserOnCurrentPage(String userLogin) throws Exception {
        assertTrue("The last user on currect page is not: " + userLogin, findElementsByXpath("//td[text()=\""+userLogin+"\"]").size()>0);
    }

    @com.thoughtworks.gauge.Step("Assert that <userLogin> is the last user on current page")
    public void assertThatIsTheLastUserOnCurrentPage(String userLogin) throws Exception {
        scrollBy(0,500);
        assertTrue("The last user on currect page is not: " + userLogin, findElementsByXpath("//td[text()=\""+userLogin+"\"]").size()>0);
        scrollBy(0,-500);
    }

    @com.thoughtworks.gauge.Step("Remove users")
    public void removeUsers() throws Exception {
        waitForElement(By.id("remove_members"));
        if(findElementById("remove_members").getAttribute("class").equals("disabled")) {
            assertTrue(true);
        }
        else {
            findElementById("remove_members").click();
        }
    }

    @com.thoughtworks.gauge.Step("Search team members by <searchKey>")
    public void searchTeamMembersBy(String searchKey) throws Exception {
        findElementById("search-query").sendKeys(searchKey);
        findElementById("user-search-submit").click();
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
            findElementByXpath("//td[text()=\""+login+"\"]/..//*[@class=\"select_user\"]").click();
        }
    }

    @com.thoughtworks.gauge.Step("Assert text present on the team member page <messege>")
    public void assertMesseage(String messege) throws InterruptedException {
        waitForElement(By.id("notice"));
        assertEquals(messege, findElementById("notice").getText().trim());
    }

    @com.thoughtworks.gauge.Step("Assert that users <userLoginsString> are not displayed on team members list")
    public void assertThatUsersAreNotDisplayedOnTeamMembersList(String userLoginsString) throws Exception {
        String[] userLogins = HelperUtils.arrayFromString(userLoginsString);
        for (String login : userLogins) {
            assertFalse("The user is there", findElementsByXpath("//td[text()=\""+login+"\"]").size()>0);
        }
    }

    @com.thoughtworks.gauge.Step("Assert that search query keyword is <keyword>")
    public void assertThatSearchQueryKeywordIs(String keyword) throws Exception {
        assertTrue("THE SEARCH QUERY IS NOT: " + keyword, findElementsByXpath("//*[@value=\"bob\"]").size()>0);
    }

    @com.thoughtworks.gauge.Step("Clear the search query")
    public void clearTheSearchQuery() throws Exception {
        findElementById("search-all-users").click();
    }

    @com.thoughtworks.gauge.Step("Navigate to <pageNumber> page")
    public void paginateTo(String pageNumber){
        findElementByXpath("//a[text()=\""+pageNumber+"\" and @rel=\"next\"]").click();
    }

    @com.thoughtworks.gauge.Step("Open add team members page")
    public void openAddTeamMembersPage() throws Exception {
        waitForElement(By.xpath("//a[@class=\"action_icon add_link\"]"));
        findElementByXpath("//a[@class=\"action_icon add_link\"]").click();
    }

    @com.thoughtworks.gauge.Step("Assert that users <userLoginsString> can be added to program")
    public void assertThatUsersCanBeAddedToProgram(String userLoginsString) throws Exception {
        String[] userLoginsArray = HelperUtils.arrayFromString(userLoginsString);
        for (String login : userLoginsArray) {
            assertTrue("CANNOT ADD USER: '" + login + "' TO PLAN.", findElementsByXpath("//td[text()=\"" + login + "\"]").size()>0);
        }
    }

    @com.thoughtworks.gauge.Step("Add user <login> to program")
    public void addUserToProgram(String login) throws Exception {
       findElementByXpath("//td[text()=\""+login+"\"]/..//*[text()=\"Add to team\"]").click();
    }

    @com.thoughtworks.gauge.Step("Back to team members page")
    public void backToTeamMembersPage() throws Exception {
       findElementByXpath("//*[@class=\"action_icon back_link\"]").click();
    }

    @com.thoughtworks.gauge.Step("Assert that users <userLoginsString> are displayed on team members list")
    public void assertThatUsersAreDisplayedOnTeamMembersList(String userLoginsString) throws Exception {
        String[] userLoginsArray = HelperUtils.arrayFromString(userLoginsString);
        for (String login : userLoginsArray) {
            assertTrue("USER: '" + login + "' DOESN'T APPEAR ON TEAM LIST. ", findElementsByXpath("//td[text()=\"bob\"]").size()>0);
        }
    }

    @com.thoughtworks.gauge.Step("Assert text present on the page <message>")
    public void assertTextPresent(String message) throws InterruptedException {
        waitForElement(By.xpath("//*[contains(.,\""+message+"\")]"));
        assertTrue(findElementsByXpath("//*[contains(.,\""+message+"\")]").size()>0);
    }

    @com.thoughtworks.gauge.Step("Assert that there are <numberOfMembers> team members for program")
    public void assertThatThereAreTeamMembersForProgram(Integer numberOfMembers) throws Exception {
        int actualNumberOfTeamMembers = getNumberOfRowsInTable();
        assertTrue("The number of members of current plan is: " + actualNumberOfTeamMembers + " , NOT: " + numberOfMembers, actualNumberOfTeamMembers == numberOfMembers);
    }

    private int getNumberOfRowsInTable() throws Exception {
        List<WebElement> tableRoes = findElementsByXpath("//*[@class=\"list_table highlightable_table\"]//tbody//tr");
        return tableRoes.size();
    }

    @com.thoughtworks.gauge.Step("Assert that <login> is on team members list")
    public void assertThatIsOnTeamMembersList(String login) throws Exception {
        assertTrue("User login is: " + login + " doesn't appear on Team Members list for current plan. ", findElementsByXpath("//td[text()=\""+login+"\"]").size()>0);
    }

    @com.thoughtworks.gauge.Step("Assert that cannot add existing member <login> to program")
    public void assertThatCannotAddExistingMemberToProgram(String login) throws Exception {
        WebElement userRow = findElementByXpath("//*[text()=\""+login.trim()+"\"]/../td[5]");
        String existingMemberMsg = "Existing team member";
        assertTrue("The expected msg: '" + existingMemberMsg + "' doesn't appear for user login is: " + login, userRow.getText().contains(existingMemberMsg));
    }

    @com.thoughtworks.gauge.Step("Assert that cannot add light user <login> to program")
    public void assertThatCannotAddLightUserToProgram(String login) throws Exception {
        WebElement userRow = findElementByXpath("//*[text()=\""+login+"\"]/..//td[5]");
        String lightUserMsg = "Light user cannot be added as program team member";
        assertTrue("The expected msg: '" + lightUserMsg + "' doesn't appear for user login is: " + login, userRow.getText().contains(lightUserMsg));
    }
}
