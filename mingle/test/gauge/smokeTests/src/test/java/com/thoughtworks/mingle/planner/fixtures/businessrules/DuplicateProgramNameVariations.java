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

import com.thoughtworks.mingle.planner.fixtures.ProgramFixture;

public class DuplicateProgramNameVariations {

    private final Browser browser;

    private String programName;

    public DuplicateProgramNameVariations(Browser browser) {
        this.browser = browser;
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

    public String errorMessage() throws Exception {
        new ProgramFixture(browser).createProgram(programName);
        return browser.exists(browser.div("flash-content")) ? browser.div("flash-content").getText() : "";
    }

	@com.thoughtworks.gauge.Step("DuplicateProgramNameVariations <table>")
	public void brtMethod(com.thoughtworks.gauge.Table table) throws Throwable {
		com.thoughtworks.twist.migration.brt.BRTMigrator brtMigrator = new com.thoughtworks.twist.migration.brt.BRTMigrator();
		try {
			brtMigrator.BRTExecutor(table, this);
		} catch (Exception e) {
			throw e.getCause();
		}
	}

}
