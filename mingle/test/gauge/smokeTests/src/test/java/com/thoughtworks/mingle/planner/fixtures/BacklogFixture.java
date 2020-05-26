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
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;
import net.sf.sahi.client.Browser;
import net.sf.sahi.client.ElementStub;
import net.sf.sahi.client.ExecutionException;

import com.thoughtworks.mingle.planner.smokeTest.util.Assertions;
import com.thoughtworks.mingle.planner.smokeTest.util.HelperUtils;

public class BacklogFixture extends Assertions {

	public BacklogFixture(Browser browser) {
		super(browser);
	}

	@com.thoughtworks.gauge.Step("Delete backlog objective at index <orderNumber>")
	public void deleteBacklogObjectiveAtIndex(String orderNumber) throws ExecutionException, Exception {
		browser.byId("delete-value-" + findObjectiveId(orderNumber)).click();
	}

	public void dragBacklogObjectiveAbove(String objective1, String objective2) throws Exception {

		ElementStub dragelement1 = browser.byId("backlog_objective_" + objective1 + "_handle");
		ElementStub dropelement2 = browser.byId("backlog_objective_" + objective2 + "_handle");
		browser.execute("_sahi._dragDropXY(" + dragelement1 + ", " + x_Location_Movement_From_Bottom(dragelement1, dropelement2) + ", " + y_Location_Movement_From_Bottom(dragelement1, dropelement2)
				+ ", false)");

	}

	public void assertBacklogObjectiveIsRanked(String objectiveName, Integer rank) throws Exception {
		assertTrue(browser.byXPath("//ul[@class='objectives ui-sortable']/li[" + rank + "]//span[contains(.,'" + objectiveName + "')])").exists());
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
		// int origin = center_Of_Xcoordinate(locator1);
		// int destination = center_Of_Xcoordinate(locator2);
		// int xloc = destination - origin;
		// System.out.println("X loc");
		// System.out.println(origin);
		// System.out.println(destination);
		// System.out.println(xloc);
		// return xloc;
		int xloc = getX(locator2);
		System.out.println(xloc);
		return xloc;
	}

	public int y_Location_Movement_From_Bottom(ElementStub locator1, ElementStub locator2) {
		// int origin = center_Of_Ycoordinate(locator1);
		// int destination = center_Of_Ycoordinate(locator2);
		// System.out.println("Y loc");
		// System.out.println(origin);
		// System.out.println(destination);
		// int yloc = destination - origin;
		// System.out.println(yloc);
		// return yloc;

		int yloc = getY(locator2);
		System.out.println(yloc);
		return yloc;
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

	private int getX(ElementStub elementStub) {
		return parseInt(browser.fetch("$(" + elementStub + ").cumulativeOffset()[0]"));
	}

	@com.thoughtworks.gauge.Step("Plan objective <backlogObjectiveName> from backlog")
	public void planObjectiveFromBacklog(String backlogObjectiveName) throws Exception {
		browser.span(backlogObjectiveName).click();
		browser.link(HelperUtils.returnLinkText(browser, "Plan on timeline")).near(browser.span(backlogObjectiveName)).click();
		Thread.sleep(1000);
	}

	@com.thoughtworks.gauge.Step("Assert backlog objective <backlogObjectiveName> is not present")
	public void assertBacklogObjectiveIsNotPresent(String backlogObjectiveName) throws Exception {
		assertFalse("Backlog Feature not present", browser.byId("backlog_objective_" + backlogObjectiveName + "_name_editor").exists());
	}

	@com.thoughtworks.gauge.Step("Assert backlog objective cannot have same name as planned objective <backlogObjectiveName>")
	public void assertBacklogObjectiveCannotHaveSameNameAsPlannedObjective(String backlogObjectiveName) throws Exception {
		browser.byId("backlog_objective_input_box").setValue(backlogObjectiveName);
		browser.byId("submit-add-backlog-objective").click();
		assertTextPresent("Name already used for an existing Feature.");
	}

	@com.thoughtworks.gauge.Step("Click backlog link on the nav pill")
	public void clickBacklogLinkOnTheNavPill() throws Exception {
		browser.link("Backlog").click();
	}

	@com.thoughtworks.gauge.Step("Click backlog link for the program <programName>")
	public void clickBacklogLinkForTheProgram(String programName) throws Exception {
		browser.byId(HelperUtils.nameToIdentifier(programName) + "_backlog_link").click();
	}

	@com.thoughtworks.gauge.Step("Create backlog objective <backlogObjectiveNames> with value statement <valueStatements>")
	public void createBacklogObjectiveWithValueStatement(String backlogObjectiveNames, String valueStatements) throws Exception {
		String[] names = backlogObjectiveNames.split(",");
		String[] statements = valueStatements.split(",");
		for (int i = 0; i < names.length; i++) {
			browser.byId("backlog_objective_input_box").setValue(names[i].trim());
			browser.byId("submit-add-backlog-objective").click();
			browser.byId("backlog_objective_value_statement").setValue(statements[i].trim());
			browser.link(HelperUtils.returnLinkText(browser, "Save")).click();
			Thread.sleep(1000);
		}

	}

	@com.thoughtworks.gauge.Step("Assert backlog objective name cannot be blank")
	public void assertBacklogObjectiveNameCannotBeBlank() throws Exception {
		browser.byId("submit-add-backlog-objective").click();
		assertTextPresent("Name can't be blank");
	}

	@com.thoughtworks.gauge.Step("Assert backlog objective cannot have same name <backlogObjectiveName>")
	public void assertBacklogObjectiveCannotHaveSameName(String backlogObjectiveName) throws Exception {
		browser.byId("backlog_objective_input_box").setValue(backlogObjectiveName);
		browser.byId("submit-add-backlog-objective").click();
		assertTextPresent("Name already used for an existing Feature.");
		browser.byId("backlog_objective_input_box").click();

	}

	@com.thoughtworks.gauge.Step("Rename backlog objective <backlogObjectiveName> as <newBacklogObjectiveName>")
	public void renameBacklogObjectiveAs(String backlogObjectiveName, String newBacklogObjectiveName) throws Exception {
		browser.span(backlogObjectiveName).click();
		browser.textbox(0).near(browser.span(backlogObjectiveName)).setValue(newBacklogObjectiveName);
		browser.link(HelperUtils.returnLinkText(browser, "Save")).near(browser.span(backlogObjectiveName)).click();
		Thread.sleep(1000);

	}

	@com.thoughtworks.gauge.Step("Assert backlog objective <backlogObjectiveName> is present")
	public void assertBacklogObjectiveIsPresent(String backlogObjectiveName) throws Exception {
		assertTrue("Backlog Objective not present", browser.span(backlogObjectiveName).exists());

	}

	@com.thoughtworks.gauge.Step("Click cancel on renaming <backlogObjectiveName> backlog objective as <newBacklogObjectiveName>")
	public void clickCancelOnRenamingBacklogObjectiveAs(String backlogObjectiveName, String newBacklogObjectiveName) throws Exception {
		browser.span(backlogObjectiveName).click();
		browser.textbox(0).near(browser.span(backlogObjectiveName)).setValue(newBacklogObjectiveName);
		browser.link(HelperUtils.returnLinkText(browser, "Cancel")).near(browser.span(backlogObjectiveName)).click();
		Thread.sleep(1000);
	}

	@com.thoughtworks.gauge.Step("Assert count of backlog objectives for program <programName> are <count>")
	public void assertCountOfBacklogObjectivesForProgramAre(String programName, String count) throws Exception {

		assertTrue(browser.byId(HelperUtils.nameToIdentifier(programName) + "_backlog_description").getText().contains(count));

	}

	public String findObjectiveId(String orderNumber) throws Exception {
		String objectiveId = browser.fetch("document.getElementsByClassName('name')[" + orderNumber + "].id");
		return objectiveId.split("_")[2];
	}

	@com.thoughtworks.gauge.Step("Set value slider for objective at index <orderNumber> to <value> percent")
	public void setValueSliderForObjectiveAtIndexToPercent(String orderNumber, Integer value) throws Exception {
		setSlider(orderNumber, value, "value");
	}

	@com.thoughtworks.gauge.Step("Set size slider for objective at index <orderNumber> to <value> percent")
	public void setSizeSliderForObjectiveAtIndexToPercent(String orderNumber, Integer value) throws Exception {
		setSlider(orderNumber, value, "size");
	}

	private void setSlider(String orderNumber, Integer percentage, String name) throws Exception {
		String sliderId = "backlog_objective_" + findObjectiveId(orderNumber) + "_" + name + "_slider";
		ElementStub sliderElement = browser.byId(sliderId);
		ElementStub sliderHandle = browser.link("").in(sliderElement);

		int sliderWidth = Integer.valueOf(browser.fetch("$j('#" + sliderId + "').outerWidth()"));
		int slideDistance = (int) Math.ceil((percentage / 100.0) * sliderWidth);

		System.out.println("desired percentage: " + percentage);
		System.out.println("slider width:       " + sliderWidth);
		System.out.println("actual distance:    " + slideDistance);

		browser.execute("_sahi._dragDropXY(" + sliderHandle + "," + slideDistance + ", 0, true)");
		Thread.sleep(1000);
	}

	@com.thoughtworks.gauge.Step("Assert value slider for objective at index <orderNumber> is at <value> percent")
	public void assertValueSliderForObjectiveAtIndexIsAtPercent(String orderNumber, String value) throws Exception {
		ElementStub ratioElement = browser.div("objective_summary_" + findObjectiveId(orderNumber));
		assertEquals(value, browser.hidden("backlog_objective_value").near(ratioElement).getValue());
	}

	@com.thoughtworks.gauge.Step("Assert size slider for objective at index <orderNumber> is at <value> percent")
	public void assertSizeSliderForObjectiveAtIndexIsAtPercent(String orderNumber, String value) throws Exception {
		ElementStub ratioElement = browser.div("objective_summary_" + findObjectiveId(orderNumber));
		assertEquals(value, browser.hidden("backlog_objective_size").in(ratioElement).getValue());
	}

	@com.thoughtworks.gauge.Step("Assert ratio for objective at index <orderNumber> is equal to <expectedRatio>")
	public void assertRatioForObjectiveAtIndexIsEqualTo(String orderNumber, String expectedRatio) throws Exception {
		assertEquals(expectedRatio, browser.fetch("document.getElementById('progressbar_" + findObjectiveId(orderNumber) + "').getAttribute('aria-valuenow')"));
	}

	@com.thoughtworks.gauge.Step("Assert value statement set as <valueStatements> for objectives <backlogObjectiveNames> respectively")
	public void assertValueStatementSetAsForObjectivesRespectively(String valueStatements, String backlogObjectiveNames) throws Exception {
		String[] names = backlogObjectiveNames.split(",");
		String[] statements = valueStatements.split(",");

		for (int i = 0; i < names.length; i++) {
			String name = names[i].trim();
			browser.span(name).click();
			assertEquals(statements[i].trim(), browser.textarea(0).near(browser.span(name)).getValue());
			browser.link(HelperUtils.returnLinkText(browser, "Cancel")).near(browser.span(name)).click();
			Thread.sleep(1000);
		}

	}

}
