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

import net.sf.sahi.client.Browser;

import com.thoughtworks.mingle.planner.fixtures.MingleProjectFixture;

public class LoginToMingleAs {

    private final MingleProjectFixture mingleAccess;
    private final Browser browser;

    public LoginToMingleAs(Browser browser) {
        this.browser = browser;
        this.mingleAccess = new MingleProjectFixture(this.browser);
    }

    @com.thoughtworks.gauge.Step("Login to mingle as <login> - setup")
	public void setUp(String login) throws Exception {
        mingleAccess.loginAs(login);
    }

    @com.thoughtworks.gauge.Step("Login to mingle as <login> - teardown")
	public void tearDown(String login) throws Exception {
        mingleAccess.logoutMingle();
    }
}
