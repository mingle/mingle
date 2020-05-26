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

package com.thoughtworks.mingle.planner.smokeTest.contexts;

import com.thoughtworks.mingle.planner.administration.PlannerLicense;
import com.thoughtworks.mingle.planner.fixtures.MingleProjectFixture;
import com.thoughtworks.mingle.planner.smokeTest.utils.DriverFactory;
import com.thoughtworks.mingle.planner.smokeTest.utils.JRubyScriptRunner;
import org.openqa.selenium.WebDriver;

public class RegisterLicenseOfType {

    private final WebDriver driver;
    private final JRubyScriptRunner scriptRunner;

    public RegisterLicenseOfType()
    {
        driver= DriverFactory.getDriver();
        scriptRunner=DriverFactory.getScriptRunner();
    }

    @com.thoughtworks.gauge.Step("Register license of type <licenseType> - setup")
    public void setUp(String licenseType) throws Exception {
        PlannerLicense plannerLicense = new PlannerLicense();
        plannerLicense.registerLicenseOfType(licenseType);
        MingleProjectFixture mingleAccess = new MingleProjectFixture();
        mingleAccess.logoutMingle();
    }

    @com.thoughtworks.gauge.Step("Register license of type <licenseType> - teardown")
    public void tearDown(String licenseType) throws Exception {
        scriptRunner.executeRaw("LicenseDecrypt.reset_license");
    }

}
