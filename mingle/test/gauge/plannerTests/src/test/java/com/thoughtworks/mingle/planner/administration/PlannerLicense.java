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

package com.thoughtworks.mingle.planner.administration;

import com.thoughtworks.mingle.planner.smokeTest.utils.Constants;
import com.thoughtworks.mingle.planner.smokeTest.utils.DriverFactory;
import org.openqa.selenium.By;
import org.openqa.selenium.JavascriptExecutor;
import org.openqa.selenium.WebDriver;

public class PlannerLicense extends Constants {

    private final WebDriver driver;

    public enum LicenseTypes {
        VALID_PLANNER_LICENSE("Valid Mingle license with Planner access", "cU4DAtXWmyrddqoOpD9KUkXn5zBj3J0iUh5D+AOiGVlUCiRo0Ro3JvtFoTR2a4FTDGKy5sjSrAORNORtQk2386zOaZbf34MSeVwryYdmscElPw67SRTTOANlI6S0ne4TqWZPnwuS9CVUiaz43JLMHExnesNEfksQjncCEfe8IMyKy+HqZHw4avsK3hhNHW37OqPvJtIAHX3NADD2pojyAX7H0TklYUIGEZaba62gAF0azR0kP5gRDkdeNyIf6TufbLKHIL3sahmFWMS7ILKWR1AxNbPqsdF+zmhTNSz8b//xmzi4Uxxje+KnKTuUDSRKq12gFIsEmbpZfoze7DvCaA=="),

        EXPIRED_PLANNER_LICENSE("Expired license with Planner access",

                "Nn7xo6xS0+PP6j2ILLPKEfeViChVFM18H1RNUtFrpecfSAJ6rpp9f9xqUGetNc+xuFl46vbCqtF/MnU2UA0bBygL3oaALi6a6oSBFklSSBr79IAbU5YLHvNGJ722D7Rm9bY1zclx6gyQbZM3aPRW07kAn2gBLuEyLqRDtecJcRugehB3tsSckdcaEveXQsngKyOa27XQVfk6HH2ppnDJNHPjRPcSZkClZW1ZmjH9k/1Rad3+gGVTX541saUbqb/UlDOCckVAonNHr+4ja2UsmJXxzMw0tV9PkVspWvWVzN7iT0NjAllDKfBkG5mpkGCmPHXbMBOzNk82W5zA5by7WQ=="),

        NON_PLANNER_LICENSE("Valid Mingle license without Planner access", "BU/tR4JurxQ8/BGUK2iMk6+7snDUq/6vnKGRjdviLdgQcG4J1a290BykkMZtu/82QQfgSXiURyqIM+51lup/Y7iLjAOqY0hTYObPuAldqh14XATIoJ3mJ8pfK3YPYb9ShK2jD0JIk2z9ZCGwcEMv4QzVuVsObANd9H76tpRgo42seBu4ez/qARPWVWv56bCnlnGWxuLNVMeHITVUOdEcEF5n/KocaLt/cMTGEQHCLk7jK7HyPiTNJq0NHaPQyNYZto42Qk4JOwiQxXEKYvudVkyyjWyWAljWpxTNQ2fGKriDgVuLbixeBGf3UcsDEgPg4INMUr0f+l5I21r5hMs1/A=="),

        PLANNER_LICENSE_WITH_ANONYMOUS_ACCESS("Planner license with Anonymous access", "cU4DAtXWmyrddqoOpD9KUkXn5zBj3J0iUh5D+AOiGVlUCiRo0Ro3JvtFoTR2a4FTDGKy5sjSrAORNORtQk2386zOaZbf34MSeVwryYdmscElPw67SRTTOANlI6S0ne4TqWZPnwuS9CVUiaz43JLMHExnesNEfksQjncCEfe8IMyKy+HqZHw4avsK3hhNHW37OqPvJtIAHX3NADD2pojyAX7H0TklYUIGEZaba62gAF0azR0kP5gRDkdeNyIf6TufbLKHIL3sahmFWMS7ILKWR1AxNbPqsdF+zmhTNSz8b//xmzi4Uxxje+KnKTuUDSRKq12gFIsEmbpZfoze7DvCaA==");

        private final String name;
        private final String value;

        LicenseTypes(String name, String value) {
            this.name = name;
            this.value = value;
        }

        public static LicenseTypes byName(String name) {
            for (LicenseTypes type : LicenseTypes.values()) {
                if (type.name.equals(name)) { return type; }
            }
            throw new RuntimeException("No license type named: " + name);
        }

        public String licenseString() {
            return this.value;
        }
    }

    public PlannerLicense() {
        this.driver= DriverFactory.getDriver();
    }

    @com.thoughtworks.gauge.Step("Register license of the type <licenseType>")
    public void registerLicenseOfType(String licenseType) throws Exception {
        driver.get(pathTo("license", "show"));
        driver.findElement(By.id("license_key")).sendKeys(LicenseTypes.byName(licenseType).licenseString());
        driver.findElement(By.id("licensed_to")).sendKeys("ThoughtWorks Inc.");
        ((JavascriptExecutor)driver).executeScript("document.evaluate(\"//a[text()='Register']\", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null).singleNodeValue.scrollIntoView()");
        driver.findElement(By.xpath("//a[text()='Register']")).click();
    }


}
