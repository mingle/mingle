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

package com.thoughtworks.mingle.planner.fixtures.bussinessrules;

import com.thoughtworks.gauge.TableRow;
import com.thoughtworks.mingle.planner.fixtures.ProgramFixture;
import com.thoughtworks.mingle.planner.smokeTest.utils.Constants;
import com.thoughtworks.mingle.planner.smokeTest.utils.DriverFactory;
import org.openqa.selenium.WebDriver;

import java.util.List;

/**
 * Created by gshilpa on 7/13/17.
 */
public class ProgramNameWithSpecialCharacters extends Constants {

    private final WebDriver driver;
    ProgramFixture programWorkflow;

    private String programName;

    public ProgramNameWithSpecialCharacters() {
        this.driver = DriverFactory.getDriver();
        this.programWorkflow=new ProgramFixture();
    }

    public void setProgramName(String programName) throws Exception {
        this.programName = programName;
    }

    public void setUp() throws Exception {
        // Put the code to be executed before execution of each row
    }

    public void tearDown() throws Exception {
        // Put the code to be executed after execution of each row
    }

    public String nameDisplayed(int count) throws Exception {
        programWorkflow.createProgramWithCount(programName,count);
        programWorkflow.waitForPageLoad(2000);
        programWorkflow.navigateToProgramPlanPage(programName);
        return programWorkflow.findElementById("header_plan_name").getText();
    }

    @com.thoughtworks.gauge.Step("ProgramNameWithSpecialCharacters <table>")
    public void brtMethod(com.thoughtworks.gauge.Table table) throws Throwable {
        List<TableRow> rows = table.getTableRows();
        List<String> columnNames = table.getColumnNames();
        int count = 6;
        for(TableRow row :rows)
        {
            setProgramName(row.getCell(columnNames.get(0)));
            programWorkflow.assertEquals(nameDisplayed(count).trim(),row.getCell(columnNames.get(1)).trim());
        }
    }
}
