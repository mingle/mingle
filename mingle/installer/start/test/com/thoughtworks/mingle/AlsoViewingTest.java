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

package com.thoughtworks.mingle;

import org.junit.Before;
import org.junit.Test;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.fail;

public class AlsoViewingTest {
    private AlsoViewing alsoViewing;

    @Before
    public void setup() {
        alsoViewing = new AlsoViewing(9999, 0);
    }

    @Test
    public void should_extract_viewers_for_a_given_url() {
        this.alsoViewing.add("url", "user");
        HashMap<String, ArrayList<String>> users = this.alsoViewing.extractActiveUsersFor("url", "currentUser");
        ArrayList<String> expectedViewers = new ArrayList<String>() {{
            add("user");
        }};
        assertEquals(expectedViewers, users.get("viewers"));
        assertEquals(0, users.get("editors").size());
    }

    @Test
    public void should_extract_multiple_viewers_for_a_given_url() {
        this.alsoViewing.add("url", "foo");
        this.alsoViewing.add("url", "bar");
        
        HashMap<String, ArrayList<String>> users = this.alsoViewing.extractActiveUsersFor("url", "currentUser");
        ArrayList<String> expected = new ArrayList<String>() {{
            add("foo");
            add("bar");
        }};
        ArrayList<String> actual = users.get("viewers");
        Collections.sort(expected);
        Collections.sort(actual);
        assertEquals(expected, actual);
    }

    @Test
    public void should_extract_viewers_and_editors_for_a_given_url_at_the_same_time() {
        this.alsoViewing.add("url", "foo");
        this.alsoViewing.add("url/edit", "bar");

        HashMap<String, ArrayList<String>> users = this.alsoViewing.extractActiveUsersFor("url", "currentUser");
        ArrayList<String> expectedViewers = new ArrayList<String>() {{
            add("foo");
        }};
        ArrayList<String> expectedEditors = new ArrayList<String>() {{
            add("bar");
        }};
        assertEquals(expectedViewers, users.get("viewers"));
        assertEquals(expectedEditors, users.get("editors"));
    }

    @Test
    public void should_extract_editors_for_a_given_url() {
        this.alsoViewing.add("url/edit", "user");
        HashMap<String, ArrayList<String>> users = this.alsoViewing.extractActiveUsersFor("url", "currentUser");
        ArrayList<String> expectedEditors = new ArrayList<String>() {{
            add("user");
        }};
        assertEquals(expectedEditors, users.get("editors"));
        assertEquals(0, users.get("viewers").size());
    }

    @Test
    public void extract_editors_should_not_contain_current_user() {
        this.alsoViewing.add("url/edit", "user");
        this.alsoViewing.add("url/edit", "currentUser");
        HashMap<String, ArrayList<String>> users = this.alsoViewing.extractActiveUsersFor("url", "currentUser");
        ArrayList<String> expectedEditors = new ArrayList<String>() {{
            add("user");
        }};
        assertEquals(expectedEditors, users.get("editors"));
    }

    @Test
    public void extract_viewers_should_not_contain_current_user() {
        this.alsoViewing.add("url", "user");
        this.alsoViewing.add("url", "currentUser");
        HashMap<String, ArrayList<String>> users = this.alsoViewing.extractActiveUsersFor("url", "currentUser");
        ArrayList<String> expectedViewers = new ArrayList<String>() {{
            add("user");
        }};
        assertEquals(expectedViewers, users.get("viewers"));
    }

    @Test
    public void extract_viewers_should_not_contain_user_already_in_editors() {
        this.alsoViewing.add("url", "user1");
        this.alsoViewing.add("url", "user2");
        this.alsoViewing.add("url/edit", "user2");
        this.alsoViewing.add("url", "currentUser");
        HashMap<String, ArrayList<String>> users = this.alsoViewing.extractActiveUsersFor("url", "currentUser");
        ArrayList<String> expectedViewers = new ArrayList<String>() {{
            add("user1");
        }};
        ArrayList<String> expectedEditors = new ArrayList<String>() {{
            add("user2");
        }};
        assertEquals(expectedViewers, users.get("viewers"));
        assertEquals(expectedEditors, users.get("editors"));
    }

    @Test
    public void should_expire_viewers_after_timeout() {
        alsoViewing = new AlsoViewing(0, 0);
        alsoViewing.add("url", "user");
        assertEquals(0, alsoViewing.extractActiveUsersFor("url", "currentUser").get("viewers").size());
    }

    @Test
    public void should_not_throw_error_when_url_is_null() {
        try {
            alsoViewing.add(null, "user");
            alsoViewing.add("", "user");
            alsoViewing.extractActiveUsersFor(null, "user");
            alsoViewing.extractActiveUsersFor("", "user");
        } catch (Exception e) {
            e.printStackTrace();
            fail("Should not throw exception when url is null");
        }
    }

    @Test
    public void should_not_throw_error_when_current_user_is_null() {
        try {
            alsoViewing.add("url", "");
            alsoViewing.add("url", null);
            alsoViewing.extractActiveUsersFor("url", "");
            alsoViewing.extractActiveUsersFor("url", null);
        } catch (Exception e) {
            e.printStackTrace();
            fail("Should not throw exception when url is null");
        }
    }
}
