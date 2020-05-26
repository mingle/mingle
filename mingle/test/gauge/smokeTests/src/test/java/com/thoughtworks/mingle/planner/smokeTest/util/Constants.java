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

package com.thoughtworks.mingle.planner.smokeTest.util;

import java.net.InetAddress;

public class Constants {

	public String getPlannerBaseDir() {
		return "../../../";
	}

	public String pathTo(String... pathFragments) {
		StringBuffer result = new StringBuffer(this.getPlannerBaseUrl());
		for (String pathFragment : pathFragments) {
			result.append("/").append(pathFragment);
		}
		return result.toString();
	}

	public String getPlannerBaseUrl() {
		return "http://" + getLocalHostName() + ":" + getPlannerBaseUrlPort();
	}

	public String getPlannerBaseUrlPort() {
		return "4001";
	}

	private String getLocalHostName() {
		try {
			return InetAddress.getLocalHost().getHostName().toLowerCase();
		} catch (Exception e) {
			e.printStackTrace();
			throw new RuntimeException(e);
		}
	}
}
