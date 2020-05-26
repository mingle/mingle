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

public enum MingleUsers {
    MINGLE_ADMIN("Mingle Admin", "admin"), FULL_USRE("Full User", "bob"), READONLY_USER("Readonly User", "read_only_user"), ANONYMOUS_USER("Anonymous User", "");

    private final String userType;
    private final String login;

    MingleUsers(String userType, String login) {
        this.userType = userType;
        this.login = login;
    }

    public static MingleUsers byUserType(String userType) {
        for (MingleUsers user : MingleUsers.values()) {
            if (user.userType.equals(userType)) { return user; }
        }
        throw new RuntimeException("No such user type: " + userType);
    }

    public String login() {
        return this.login;
    }
}
