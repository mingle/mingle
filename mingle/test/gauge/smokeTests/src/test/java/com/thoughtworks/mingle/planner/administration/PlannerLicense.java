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

import net.sf.sahi.client.Browser;

import com.thoughtworks.mingle.planner.smokeTest.util.Constants;
import com.thoughtworks.mingle.planner.smokeTest.util.HelperUtils;

public class PlannerLicense extends Constants {

    private final Browser browser;

    public enum LicenseTypes {
        VALID_PLANNER_LICENSE("Valid Mingle license with Planner access", "cU4DAtXWmyrddqoOpD9KUkXn5zBj3J0iUh5D+AOiGVlUCiRo0Ro3JvtFoTR2a4FTDGKy5sjSrAORNORtQk2386zOaZbf34MSeVwryYdmscElPw67SRTTOANlI6S0ne4TqWZPnwuS9CVUiaz43JLMHExnesNEfksQjncCEfe8IMyKy+HqZHw4avsK3hhNHW37OqPvJtIAHX3NADD2pojyAX7H0TklYUIGEZaba62gAF0azR0kP5gRDkdeNyIf6TufbLKHIL3sahmFWMS7ILKWR1AxNbPqsdF+zmhTNSz8b//xmzi4Uxxje+KnKTuUDSRKq12gFIsEmbpZfoze7DvCaA=="),

        EXPIRED_PLANNER_LICENSE("Expired license with Planner access",

        "Nn7xo6xS0+PP6j2ILLPKEfeViChVFM18H1RNUtFrpecfSAJ6rpp9f9xqUGetNc+xuFl46vbCqtF/MnU2UA0bBygL3oaALi6a6oSBFklSSBr79IAbU5YLHvNGJ722D7Rm9bY1zclx6gyQbZM3aPRW07kAn2gBLuEyLqRDtecJcRugehB3tsSckdcaEveXQsngKyOa27XQVfk6HH2ppnDJNHPjRPcSZkClZW1ZmjH9k/1Rad3+gGVTX541saUbqb/UlDOCckVAonNHr+4ja2UsmJXxzMw0tV9PkVspWvWVzN7iT0NjAllDKfBkG5mpkGCmPHXbMBOzNk82W5zA5by7WQ=="),

        NON_PLANNER_LICENSE("Valid Mingle license without Planner access", "gGckA8bL1btQH1+QmCe5Ei8n7HBL4FJnzI6abJ69xL7dwuwg1APDBjVUDyd9nrjJ5iwdrRWbNqa5kTFN6vIH1GSPiPR9ob8BlIXFjsVz6DgM+/ccfPCaoPSwHAdPm39Vx0Qc0INrcA4DVAM6KF+nTkaHIY6SZ7euv5zElT1k8vO5gRjmzGuH21CKYv+ECfW8Ym+aKDek5B7dR0Gr2Gsy9SYsYN9P4D/tB5y6W1kOeehgaCBjGU7iIt616eWK/9Nr27rU0oJWxh32AfU75eBfHWOX3p7aO5Rn/XDyGiZ2cA0vVF9L3NQ9V7kY9lB5Rdy5+hOENsXVuon2n18F1u7dKw=="),

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

    public PlannerLicense(Browser browser) {
        this.browser = browser;
    }

    @com.thoughtworks.gauge.Step("Register license of the type <licenseType>")
	public void registerLicenseOfType(String licenseType) throws Exception {
        browser.navigateTo(pathTo("license", "show"));
        browser.textarea("license_key").setValue(LicenseTypes.byName(licenseType).licenseString());
        browser.textbox("licensed_to").setValue("ThoughtWorks Inc.");
        browser.link(HelperUtils.returnLinkText(browser, "Register")).click();
    }

}
