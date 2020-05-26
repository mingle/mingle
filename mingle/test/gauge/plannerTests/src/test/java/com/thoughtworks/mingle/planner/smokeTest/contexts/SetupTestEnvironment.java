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

import com.thoughtworks.mingle.planner.smokeTest.utils.Constants;
import com.thoughtworks.mingle.planner.smokeTest.utils.DriverFactory;
import com.thoughtworks.mingle.planner.smokeTest.utils.JRubyScriptRunner;
import org.openqa.selenium.WebDriver;


public class SetupTestEnvironment extends Constants{

    private final JRubyScriptRunner scriptRunner;
    private final WebDriver driver;

    public SetupTestEnvironment() {
        this.scriptRunner = DriverFactory.getScriptRunner();
        this.driver = DriverFactory.getDriver();
    }

    public SetupTestEnvironment(WebDriver driver, JRubyScriptRunner jRubyScriptRunner) {
        this.driver = driver;
        this.scriptRunner = jRubyScriptRunner;
    }

    public void start() throws Exception {
        scriptRunner.executeRaw("SetupHelper.setup_for_planner_acceptance_tests");
        driver.get(this.getPlannerBaseUrl() + "/_class_method_call?class=SetupHelper&method=setup_for_planner_acceptance_tests");
    }


}


