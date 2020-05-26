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

import java.io.IOException;
import java.net.URL;
import java.util.Enumeration;
import java.util.jar.Attributes;
import java.util.jar.JarFile;
import java.util.jar.Manifest;

/** Utility class to work with Java Manifests */
public class ManifestUtil {

    /** Utility classes should not be instantiated */
    private ManifestUtil() {
    }

    /**
     * Returns the first occurrence of String key from the loaded Manifest Main-Attributes in the classpath
     *
     * @param key the String for which we search
     * @return the first entry matching the key
     * @throws IOException on error
     */
    public static String findKeyInClassPath(String key) throws IOException {
        Enumeration<URL> manifests = allManifestsInClassPath();
        Attributes.Name attributeKey = new Attributes.Name(key);

        while (manifests.hasMoreElements()) {
            Manifest m = loadManifestFromUrl(manifests.nextElement());

            if (m.getMainAttributes().containsKey(attributeKey)) {
                return (String) m.getMainAttributes().get(attributeKey);
            }
        }

        return null;
    }

    /**
     * @return an Enumeration of all jar Manifest URLs in the classpath
     * @throws IOException on error
     */
    public static Enumeration<URL> allManifestsInClassPath() throws IOException {
        return getClassLoader().getResources(JarFile.MANIFEST_NAME);
    }

    /**
     * Loads a Manifest from a given URL
     *
     * @param url the URL to the Manifest
     * @return the Manifest referenced by the URL
     * @throws IOException on error
     */
    public static Manifest loadManifestFromUrl(URL url) throws IOException {
        return new Manifest(url.openStream());
    }

    /**
     * Convenience method to get at the ClassLoader
     *
     * @return the ClassLoader
     */
    private static ClassLoader getClassLoader() {
        return ManifestUtil.class.getClassLoader();
    }
}
