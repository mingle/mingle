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

import com.thoughtworks.mingle.planner.administration.PlannerLicense;
import com.thoughtworks.mingle.planner.smokeTest.util.Constants;

public class PlannerAvailabilityBasedOnLicense extends Constants {

    private final Browser browser;

    private String licenseType;

    public PlannerAvailabilityBasedOnLicense(Browser browser) {
        this.browser = browser;
    }

    public void setLicenseType(String licenseType) throws Exception {
        this.licenseType = licenseType;
        PlannerLicense plannerLicense = new PlannerLicense(this.browser);
        plannerLicense.registerLicenseOfType(this.licenseType);
    }

    public void setUp() throws Exception {}

    public void tearDown() throws Exception {}

    public String plannerAbailability() throws Exception {
        browser.navigateTo(getPlannerBaseUrl());
        return browser.link("tab_programs_link").exists() ? "Available" : "Unavailable";
    }

}
