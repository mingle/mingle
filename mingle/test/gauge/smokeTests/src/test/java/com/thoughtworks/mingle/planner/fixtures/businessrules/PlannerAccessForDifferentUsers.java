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

package com.thoughtworks.mingle.planner.fixtures.businessrules;

import net.sf.sahi.client.Browser;

import com.thoughtworks.mingle.planner.administration.MingleUsers;
import com.thoughtworks.mingle.planner.fixtures.MingleProjectFixture;
import com.thoughtworks.mingle.planner.smokeTest.util.Constants;

public class PlannerAccessForDifferentUsers extends Constants {

    private final MingleProjectFixture mingleAccess;
    private final Browser browser;

    public PlannerAccessForDifferentUsers(Browser browser) {
        this.browser = browser;
        this.mingleAccess = new MingleProjectFixture(this.browser);
    }

    public void setUp() throws Exception {}

    public void setUserType(String userType) throws Exception {
        if (!(userType.equals("Anonymous User"))) {
            this.mingleAccess.loginAs(MingleUsers.byUserType(userType).login());
        }
    }

    public void tearDown() throws Exception {
        mingleAccess.logoutMingle();
    }

    public String plannerAvailability() throws Exception {
        browser.navigateTo(getPlannerBaseUrl());
        if (isPlannerAvailable()) { return "Available"; }
        return "Unavailable";
    }

    // Private methods

    private Boolean isPlannerAvailable() {
        return browser.link("Programs").in(browser.div("header-pills")).exists();
    }

	@com.thoughtworks.gauge.Step("PlannerAccessForDifferentUsers <table>")
	public void brtMethod(com.thoughtworks.gauge.Table table) throws Throwable {
		com.thoughtworks.twist.migration.brt.BRTMigrator brtMigrator = new com.thoughtworks.twist.migration.brt.BRTMigrator();
		try {
			brtMigrator.BRTExecutor(table, this);
		} catch (Exception e) {
			throw e.getCause();
		}
	}

}
