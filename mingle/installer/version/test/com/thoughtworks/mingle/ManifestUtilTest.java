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

import org.junit.Test;

import java.net.URL;
import java.util.*;
import java.util.jar.Manifest;

import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertNull;
import static org.junit.Assert.assertEquals;

/** Tests for utility class ManifestUtil */
public class ManifestUtilTest {

    /**
     * validates that we can search for a key in all of the Manifest entries in the classpath
     *
     * @throws Exception on error
     */
    @Test
    public void testFindKeyInClassPath() throws Exception {
        /* This key should be found in the slf4j jar */
        String key = "Fragment-Host";
        String value = ManifestUtil.findKeyInClassPath(key);

        String expected = "slf4j.api";
        assertNotNull("Could not find key", value);
        assertEquals("key " + key + " should be " + expected, expected, value);
    }

    /**
     * validates that we return no results when a key doesn't exists in any of the Manifest entries in the classpath
     *
     * @throws Exception on error
     */
    @Test
    public void testFindKeyInClassPathNotFound() throws Exception {
        /* This key should not exist anywhere */
        String key = "Holy-Cow-I-Do-Not-Exist";

        assertNull("Found key: " + key + " in manifests within the classpath. It shouldn't exist!",
                ManifestUtil.findKeyInClassPath(key));
    }

    /**
     * Prints out a list of unique keys and their value to stdout. This is really only useful
     * when you need to find a new key for testFindKeyInClassPath() if our jars change.
     *
     * @throws Exception on error
     */
    public void showAllUniqueManifestAttributes() throws Exception {
        Enumeration<URL> urls = ManifestUtil.allManifestsInClassPath();
        Map<String, List<String>> count = new HashMap<String, List<String>>();
        while(urls.hasMoreElements()) {
            Manifest m = ManifestUtil.loadManifestFromUrl(urls.nextElement());
            for (Object attr : m.getMainAttributes().keySet()) {
                String key = attr.toString();
                String value = (String) m.getMainAttributes().get(attr);

                if (count.containsKey(key)) {
                    count.get(key).add(value);
                } else {
                    ArrayList<String> values = new ArrayList<String>();
                    values.add(value);
                    count.put(key, values);
                }
            }
        }

        for (String key : count.keySet()) {
            List<String> values = count.get(key);
            if (values.size() == 1) {
                System.out.println("Unique: " + key + ": " + values.get(0));
            }
        }
    }
}
