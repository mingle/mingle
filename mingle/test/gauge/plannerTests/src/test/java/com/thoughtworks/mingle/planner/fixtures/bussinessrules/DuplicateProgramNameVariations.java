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
import com.thoughtworks.mingle.planner.fixtures.MingleProjectFixture;
import com.thoughtworks.mingle.planner.fixtures.ProgramFixture;
import com.thoughtworks.mingle.planner.smokeTest.utils.Constants;
import com.thoughtworks.mingle.planner.smokeTest.utils.DriverFactory;
import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;

import java.util.List;

/**
 * Created by gshilpa on 7/13/17.
 */
public class DuplicateProgramNameVariations extends Constants {
    private final WebDriver driver;
    private final ProgramFixture programWorkFlow;

    private String programName;

    public DuplicateProgramNameVariations() {
        this.programWorkFlow = new ProgramFixture();
        this.driver = DriverFactory.getDriver();
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

    public String errorMessage(int count) throws Exception {
        programWorkFlow.createProgramWithCount(programName, count);
        programWorkFlow.waitForPageLoad(2000);
        if (programWorkFlow.findElementsById("error").size()> 0) {
            return programWorkFlow.findElementById("error").getText();
        }else
        {
            return "";
        }
    }

    @com.thoughtworks.gauge.Step("DuplicateProgramNameVariations <table>")
    public void brtMethod(com.thoughtworks.gauge.Table table) throws Throwable {
        List<TableRow> rows = table.getTableRows();
        List<String> columnNames = table.getColumnNames();
        int count =0;
        for(TableRow row :rows)
        {
            setProgramName(row.getCell(columnNames.get(0)));
            programWorkFlow.assertMatch(errorMessage(count),row.getCell(columnNames.get(1)));
            count++;
        }
    }
}
