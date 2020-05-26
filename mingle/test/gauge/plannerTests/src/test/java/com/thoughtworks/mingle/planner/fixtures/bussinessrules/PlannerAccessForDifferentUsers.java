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

import com.thoughtworks.gauge.Table;
import com.thoughtworks.gauge.TableRow;
import com.thoughtworks.mingle.planner.administration.MingleUsers;
import com.thoughtworks.mingle.planner.fixtures.MingleProjectFixture;
import com.thoughtworks.mingle.planner.smokeTest.utils.Constants;
import com.thoughtworks.mingle.planner.smokeTest.utils.DriverFactory;
import org.openqa.selenium.By;
import org.openqa.selenium.WebDriver;

import java.util.List;

public class PlannerAccessForDifferentUsers extends Constants {

    private final MingleProjectFixture mingleAccess;
    private final WebDriver driver;

    public PlannerAccessForDifferentUsers() {
        this.driver= DriverFactory.getDriver();
        this.mingleAccess = new MingleProjectFixture();
    }

    public String plannerAvailability() throws Exception {
        this.driver.get(getPlannerBaseUrl());
        if (isPlannerAvailable())
        { return "Available"; }
        return "Unavailable";
    }

    private Boolean isPlannerAvailable() {
        return this.driver.findElements(By.xpath("//a[text()='Programs']")).size() > 0;
    }

    public void setUp() throws Exception {}

    public void setUserType(String userType) throws Exception {
        if (!(userType.equals("Anonymous User"))) {
            this.mingleAccess.loginAs(MingleUsers.byUserType(userType).login());
        }else
        {
            this.mingleAccess.loginAsAnonUser();
        }
    }

    public void tearDown() throws Exception {
        mingleAccess.logoutMingle();
    }

    @com.thoughtworks.gauge.Step("PlannerAccessForDifferentUsers <table>")
    public void plannerAvailability(Table table) throws Exception {
        List<TableRow> rows = table.getTableRows();
        List<String> columnNames = table.getColumnNames();
        for(TableRow row :rows)
        {
            setUserType(row.getCell(columnNames.get(0)));
            mingleAccess.assertMatch(plannerAvailability(),row.getCell(columnNames.get(1)));
        }
    }
}
