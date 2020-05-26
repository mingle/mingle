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

package com.thoughtworks.mingle.planner.smokeTest.utils;


import com.thoughtworks.gauge.AfterScenario;
import com.thoughtworks.gauge.AfterSuite;
import com.thoughtworks.gauge.BeforeScenario;
import com.thoughtworks.gauge.BeforeSuite;
import com.thoughtworks.mingle.planner.smokeTest.contexts.CleanupPrograms;
import com.thoughtworks.mingle.planner.smokeTest.contexts.SetupTestEnvironment;
import io.github.bonigarcia.wdm.ChromeDriverManager;
import io.github.bonigarcia.wdm.FirefoxDriverManager;
import io.github.bonigarcia.wdm.InternetExplorerDriverManager;
import org.openqa.selenium.WebDriver;
import org.openqa.selenium.chrome.ChromeDriver;
import org.openqa.selenium.firefox.FirefoxDriver;
import org.openqa.selenium.ie.InternetExplorerDriver;
public class DriverFactory{

    private static final String FIREFOX = "firefox";
    private static final String IE = "ie";
    private static final String DEFAULT = "chrome";
    private static WebDriver driver;
    private static JRubyScriptRunner scriptRunner;

    public static JRubyScriptRunner getScriptRunner(){
        scriptRunner= new JRubyScriptRunner();
        return scriptRunner;
    }

    public static WebDriver getDriver() {
        return driver;
    }

    @BeforeSuite
    public void driverSetup()
    {
        String browser = System.getenv("BROWSER");
        if (browser == null) {
            browser = DEFAULT;
        }
        if (browser.toLowerCase().equals(FIREFOX)) {
            FirefoxDriverManager.getInstance().setup();
            driver = new FirefoxDriver();
        } else if (browser.toLowerCase().equals(IE)) {
            InternetExplorerDriverManager.getInstance().setup();
            driver = new InternetExplorerDriver();
        } else {
            ChromeDriverManager.getInstance().version(System.getenv("CHROME_VERSION")).setup();
            driver = new ChromeDriver();
        }
    }

    @BeforeScenario
    public void testEnvSetUp() throws Exception {
        new SetupTestEnvironment().start();
    }

    @AfterScenario
    public void testEnvCleanUp() throws Exception {
        new CleanupPrograms().tearDown();
    }

    @AfterSuite
    public void tearDown()
    {
        driver.quit();
    }
}
