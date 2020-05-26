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
import org.openqa.selenium.interactions.Actions;

/**
 * Created by gshilpa on 5/24/17.
 */
public class BacklogFixture extends Assertions {

    public BacklogFixture() {
        super();
    }

    @com.thoughtworks.gauge.Step("Click backlog link for the program <programName>")
    public void clickBacklogLinkForTheProgram(String programName) throws Exception {
        waitForElement(By.id(HelperUtils.nameToIdentifier(programName) + "_program_wall_link"));
        findElementById(HelperUtils.nameToIdentifier(programName) + "_program_wall_link").click();
    }

    @com.thoughtworks.gauge.Step("Assert backlog objective name cannot be blank")
    public void assertBacklogObjectiveNameCannotBeBlank() throws Exception {
        findElementById("submit-add-backlog-objective").click();
        waitForElement(By.id("error"));
        assertEquals("Name can't be blank", findElementById("error").getText().trim());
    }

    @com.thoughtworks.gauge.Step("Create backlog objective <backlogObjectiveNames> with value statement <valueStatements>")
    public void createBacklogObjectiveWithValueStatement(String backlogObjectiveNames, String valueStatements) throws Exception {
        String[] names = backlogObjectiveNames.split(",");
        String[] statements = valueStatements.split(",");
        for (int i = 0; i < names.length; i++) {
            findElementById("backlog_objective_input_box").sendKeys(names[i].trim());
            findElementById("submit-add-backlog-objective").click();
            scrollToEndOfPage();
            findElementById("objective_value_statement").sendKeys(statements[i].trim());
            scrollInToText("Save");
            waitForPageLoad(1000);
            clickOnLabelOfObjectives(names[i].trim(),"Save");
            waitForPageLoad(1000);
        }
    }

    @com.thoughtworks.gauge.Step("Assert backlog objective cannot have same name <backlogObjectiveName>")
    public void assertBacklogObjectiveCannotHaveSameName(String backlogObjectiveName) throws Exception {
        findElementById("backlog_objective_input_box").sendKeys(backlogObjectiveName);
        findElementById("submit-add-backlog-objective").click();
        waitForElement(By.id("error"));
        assertEquals("Name already used for an existing Feature.",findElementById("error").getText().trim());
        findElementById("backlog_objective_input_box").clear();
    }

    @com.thoughtworks.gauge.Step("Rename backlog objective <backlogObjectiveName> as <newBacklogObjectiveName>")
    public void renameBacklogObjectiveAs(String backlogObjectiveName, String newBacklogObjectiveName) throws Exception {
        refreshThePage();
        findElementByXpath("//span[text()=\""+backlogObjectiveName+"\"]").click();
        findElementByXpath("//input[@value=\""+backlogObjectiveName+"\"]").clear();
        findElementByXpath("//input[@value=\""+backlogObjectiveName+"\"]").sendKeys(newBacklogObjectiveName);
        scrollToEndOfPage();
        waitForPageLoad(2000);
        clickOnLabelOfObjectives(backlogObjectiveName,"Save");
        waitForPageLoad(1000);
    }

    @com.thoughtworks.gauge.Step("Assert backlog objective <backlogObjectiveName> is present")
    public void assertBacklogObjectiveIsPresent(String backlogObjectiveName) throws Exception {
        assertTrue("Backlog Objective not present", findElementsByXpath("//span[text()=\""+backlogObjectiveName+"\"]").size()>0);
    }

    @com.thoughtworks.gauge.Step("Click cancel on renaming <backlogObjectiveName> backlog objective as <newBacklogObjectiveName>")
    public void clickCancelOnRenamingBacklogObjectiveAs(String backlogObjectiveName, String newBacklogObjectiveName) throws Exception {
        findElementByXpath("//span[text()=\""+backlogObjectiveName+"\"]").click();
        findElementByXpath("//span[text()=\""+ backlogObjectiveName + "\"]/..//input").clear();
        findElementByXpath("//*[@value='objective2']").sendKeys(newBacklogObjectiveName);
        scrollToEndOfPage();
        waitForPageLoad(1000);
        clickOnLabelOfObjectives("objective2","Cancel");
    }

    @com.thoughtworks.gauge.Step("Assert value slider for <objective> at index <orderNumber> is at <value> percent")
    public void assertValueSliderForObjectiveAtIndexIsAtPercent(String objectiveName, String orderNumber, String value) throws Exception {
        WebElement objectiveSlider = findElementByXpath("//*[@name=\"backlog_objective_"+objectiveName.trim()+"_value_slider\"]/div");
        assertEquals(value , objectiveSlider.getAttribute("style").trim().split(" ")[1].trim().split("%")[0]);
    }

    @com.thoughtworks.gauge.Step("Assert size slider for <objective> at index <orderNumber> is at <value> percent")
    public void assertSizeSliderForObjectiveAtIndexIsAtPercent(String objectiveName,String orderNumber, String value) throws Exception {
        WebElement objectiveSlider = findElementByXpath("//*[@name=\"backlog_objective_"+objectiveName.trim()+"_size_slider\"]/div");
        assertEquals(value , objectiveSlider.getAttribute("style").trim().split(" ")[1].trim().split("%")[0]);
    }

    @com.thoughtworks.gauge.Step("Set value slider for <objective> at index <orderNumber> to <value> percent")
    public void setValueSliderForObjectiveAtIndexToPercent(String objectiveName,String orderNumber, Integer value) throws Exception {
        setSlider(objectiveName, value, "value");
    }

    private void setSlider(String objectiveName, Integer percentage, String name) throws Exception {
        String sliderName = "backlog_objective_" +objectiveName.trim() + "_" + name + "_slider";
        WebElement slider  = findElementByXpath("//*[@name=\""+sliderName+"\"]/div");
        WebElement sliderHandle = findElementByXpath("//*[@name=\""+sliderName+"\"]/a");
        new Actions(this.driver)
                .dragAndDropBy(sliderHandle,percentage,0)
                .build()
                .perform();
        Thread.sleep(5000L);
    }

    @com.thoughtworks.gauge.Step("Set size slider for <objective> at index <orderNumber> to <value> percent")
    public void setSizeSliderForObjectiveAtIndexToPercent(String objectiveName, String orderNumber, Integer value) throws Exception {
        setSlider(objectiveName, value, "size");
    }

    @com.thoughtworks.gauge.Step("Assert ratio for <objective> at index <orderNumber> is equal to <expectedRatio>")
    public void assertRatioForObjectiveAtIndexIsEqualTo(String objectiveName, String orderNumber, String expectedRatio) throws Exception {
        waitForPageLoad(1000);
        WebElement ratioEle = findElementByXpath("//div[@name=\"progressbar_"+objectiveName.trim()+"\"]");
        assertEquals(expectedRatio, ratioEle.getAttribute("aria-valuenow"));
    }

    @com.thoughtworks.gauge.Step("Assert value statement set as <valueStatements> for objectives <backlogObjectiveNames> respectively")
    public void assertValueStatementSetAsForObjectivesRespectively(String valueStatements, String backlogObjectiveNames) throws Exception {
        String[] names = backlogObjectiveNames.split(",");
        String[] statements = valueStatements.split(",");
        for (int i = 0; i < names.length; i++) {
            String name = names[i].trim();
            findElementByXpath("//span[text()=\""+name+"\"]").click();
            waitForPageLoad(1000);
            assertTrue(findElementsByXpath("//*[text()=\""+statements[i].trim()+"\"]").size()>0);
            scrollToEndOfPage();
            waitForPageLoad(1000);
            if(name.equals("Testing")){
                clickOnLabelOfObjectives("objective2","Cancel");
            }else{
                clickOnLabelOfObjectives(name,"Cancel");
            }
            waitForPageLoad(1000);
        }
    }

    @com.thoughtworks.gauge.Step("Assert count of backlog objectives for program <programName> are <count>")
    public void assertCountOfBacklogObjectivesForProgramAre(String programName, String count) throws Exception {
        assertTrue(findElementById(HelperUtils.nameToIdentifier(programName) + "_backlog_description").getText().contains(count));
    }

    @com.thoughtworks.gauge.Step("Plan objective <backlogObjectiveName> from backlog")
    public void planObjectiveFromBacklog(String backlogObjectiveName) throws Exception {
        findElementByXpath("//span[text()=\""+backlogObjectiveName+"\"]").click();
        scrollToEndOfPage();
        waitForPageLoad(1000);
        clickOnLabelOfObjectives(backlogObjectiveName,"Plan on timeline");
        waitForPageLoad((1000));
    }

    @com.thoughtworks.gauge.Step("Click backlog link on the nav pill")
    public void clickBacklogLinkOnTheNavPill() throws Exception {
        waitForElement(By.linkText("Program Wall"));
        findElementByLinkText("Program Wall").click();
    }

    @com.thoughtworks.gauge.Step("Assert backlog objective <backlogObjectiveName> is not present")
    public void assertBacklogObjectiveIsNotPresent(String backlogObjectiveName) throws Exception {
        assertFalse("Backlog Feature not present", findElementsById("backlog_objective_" + backlogObjectiveName + "_name_editor").size()>0);
    }

    @com.thoughtworks.gauge.Step("Assert backlog objective cannot have same name as planned objective <backlogObjectiveName>")
    public void assertBacklogObjectiveCannotHaveSameNameAsPlannedObjective(String backlogObjectiveName) throws Exception {
        findElementById("backlog_objective_input_box").sendKeys(backlogObjectiveName);
        findElementById("submit-add-backlog-objective").click();
        assertEquals("Name already used for an existing Feature.",findElementById("error").getText().trim());
    }

    @com.thoughtworks.gauge.Step("Delete backlog objective at index <orderNumber>")
    public void deleteBacklogObjectiveAtIndex(String orderNumber) throws Exception {
        waitForPageLoad(2000);
        findElementById(excecuteJsWithStringretun(" return document.getElementsByClassName('name')[" + orderNumber + "].id")).click();
        scrollToEndOfPage();
        waitForPageLoad(1000);
        excecuteJs("document.getElementById('delete-value-"+findObjectiveId(orderNumber)+"').click();");
        waitForElement(By.id("confirm_delete"));
        excecuteJs("document.getElementById('confirm_delete').click();");
    }

    //private methods

    public void clickOnLabelOfObjectives(String ObjectiveName,String Label){
        excecuteJs("(document.evaluate(\"//*[@value='"+ ObjectiveName.trim() +"']/../../..//a[text()='"+Label.trim()+"']\",document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue).click()");
    }

    public String findObjectiveId(String orderNumber) throws Exception {
        String objectiveId = excecuteJsWithStringretun("return document.getElementsByClassName('name')[" + orderNumber + "].id");
        return objectiveId.split("_")[2];
    }
}
