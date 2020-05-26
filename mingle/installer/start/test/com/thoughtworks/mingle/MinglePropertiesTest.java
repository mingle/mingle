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

import org.apache.commons.io.FileUtils;
import org.junit.After;
import org.junit.Assert;
import org.junit.Before;
import org.junit.Test;

import java.io.*;
import java.util.ArrayList;
import java.util.List;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertNull;
import static org.mockito.Mockito.*;

public class MinglePropertiesTest {
    File dirForTest;
    DataDirectory dataDir;
    ConfigDirectory configDir;
    private MinglePropertiesFactory factory;

    public static void clearMingleSystemProperties() {
        for (String prop : System.getProperties().stringPropertyNames()) {
            if (prop.startsWith("mingle.")) {
                System.out.println("Clearing Mingle system property: " + prop);
                System.clearProperty(prop);
            }
        }
    }

    @Before
    public void setup() {
        clearMingleSystemProperties();
        dirForTest = new File("forTest");
        dirForTest.mkdir();

        dataDir = new DataDirectory(dirForTest.getPath());
        dataDir.createIfNeeded();
        configDir = new ConfigDirectory(dirForTest.getPath());
        configDir.createIfNeeded();
        factory = new MinglePropertiesFactory();
    }

    @After
    public void tearDown() throws Exception {
        clearMingleSystemProperties();
        FileUtils.deleteDirectory(dirForTest);
        System.clearProperty("jruby.max.runtimes");
    }

    @Test
    public void factoryShouldLoadPropertiesFromSystemPropertiesToo() throws Exception {
        System.setProperty("jruby.max.runtimes", "1");
        MingleProperties props = new MinglePropertiesFactory().loadMingleProperties(dataDir, configDir);
        props.configureSystemProperties();
        assertEquals(1, MingleProperties.jrubyMaxRuntimes(System.getProperties()));
    }

    @Test
    public void runtimeConfigurationShouldBeKeptAfterMinglePropertiesLoaded() throws Exception {
        StringBuilder properties = new StringBuilder();
        properties.append(formatProperty("jruby.max.runtimes", "1"));
        writeMinglePropertiesForTest(properties.toString());

        MingleProperties props = new MinglePropertiesFactory().loadMingleProperties(dataDir, configDir);
        props.configureSystemProperties();
        assertEquals(1, MingleProperties.jrubyMaxRuntimes(System.getProperties()));
        props.save();
        assertPropertiesFileIncludesLine("-Djruby.max.runtimes=1");
    }

    @Test
    public void loadPropertiesMoveMinglePropertiesFileIntoConfigDirectoryWhenItIsInDataDirectory() {
        String propertiesPath = new File("aDirectory", MingleProperties.FILE_NAME).getPath();

        DataDirectory dataDir = mock(DataDirectory.class);
        ConfigDirectory configDir = mock(ConfigDirectory.class);

        when(configDir.dir()).thenReturn("aDirectory");
        when(dataDir.subdirectoryNamed(anyString())).thenReturn(new File(""));

        when(configDir.containsFile(propertiesPath))
                .thenReturn(false)
                .thenReturn(true);
        when(dataDir.containsMingleProperties())
                .thenReturn(true)
                .thenReturn(false);

        factory.loadMingleProperties(dataDir, configDir);

        verify(dataDir, times(1)).moveMinglePropertiesToConfigDir("aDirectory");
    }

    @Test
    public void loadPropertiesShouldLoadPropertiesFromMingleProperties() throws FileNotFoundException {
        StringBuilder properties = new StringBuilder();
        properties.append(formatProperty(MingleProperties.SWAP_DIR_KEY, "aSwapDir"));
        properties.append(formatProperty(MingleProperties.LOG_DIR_KEY, "aLogDir"));
        properties.append(formatProperty(MingleProperties.MINGLE_PORT_KEY, "1"));
        properties.append(formatProperty(MingleProperties.MEMCACHED_HOST_KEY, "//memcache"));
        properties.append(formatProperty(MingleProperties.MEMCACHED_PORT_KEY, "2"));
        properties.append(formatProperty(MingleProperties.APP_CONTEXT_KEY, "/app/"));

        properties.append(formatProperty(MingleProperties.MINGLE_SSL_PORT_KEY, "8089"));
        properties.append(formatProperty(MingleProperties.MINGLE_SSL_KEYSTORE_KEY, "/Users/schu/.keystore"));
        properties.append(formatProperty(MingleProperties.MINGLE_SSL_KEYSTORE_PASSWORD_KEY, "keystore foobar"));
        properties.append(formatProperty(MingleProperties.MINGLE_SSL_KEY_PASSWORD_KEY, "keypair_passphrase"));
        properties.append(formatProperty(MingleProperties.MINGLE_PROJECT_CACHE_MAX_SIZE, "1"));

        writeMinglePropertiesForTest(properties.toString());

        MingleProperties mingleProperties = factory.loadMingleProperties(dataDir, configDir);

        assertEquals("aSwapDir", mingleProperties.swapDir.toString());
        assertEquals("aLogDir", mingleProperties.logDir.toString());
        assertEquals("//memcache", mingleProperties.memcachedHost);
        assertEquals("2", mingleProperties.memcachedPort);
        assertEquals("1", mingleProperties.port);
        assertEquals("/app/", mingleProperties.appContext);

        assertEquals("8089", mingleProperties.sslPort);
        assertEquals("/Users/schu/.keystore", mingleProperties.sslKeystore);
        assertEquals("keystore foobar", mingleProperties.sslKeystorePassword);
        assertEquals("keypair_passphrase", mingleProperties.sslKeyPassword);
        assertEquals("1", mingleProperties.projectCacheMaxSize);
    }

    @Test
    public void loadPropertiesShouldNotLoadDefaultPortIfSslPortAlreadySet() throws FileNotFoundException {
        StringBuilder properties = new StringBuilder();
        properties.append(formatProperty(MingleProperties.MINGLE_SSL_PORT_KEY, "8089"));
        writeMinglePropertiesForTest(properties.toString());

        MingleProperties mingleProperties = factory.loadMingleProperties(dataDir, configDir);

        assertEquals("8089", mingleProperties.sslPort);
        assertEquals(null, mingleProperties.port);
    }

    @Test
    public void loadPropertiesShouldAllowSslPortToBeNotSet() throws FileNotFoundException {
        StringBuilder properties = new StringBuilder();
        properties.append(formatProperty(MingleProperties.MINGLE_PORT_KEY, "8081"));
        writeMinglePropertiesForTest(properties.toString());

        MingleProperties mingleProperties = factory.loadMingleProperties(dataDir, configDir);

        assertEquals(null, mingleProperties.sslPort);
        assertEquals("8081", mingleProperties.port);
    }

    @Test
    public void loadPropertiesShouldDetectRequiredParamtersWhichAreMissingAndAddDefaults() throws FileNotFoundException {
        String minglePropertiesWithMissingRequiredProperties = formatProperty(MingleProperties.MINGLE_PORT_KEY, "1");
        writeMinglePropertiesForTest(minglePropertiesWithMissingRequiredProperties);

        MingleProperties mingleProperties = factory.loadMingleProperties(dataDir, configDir);

        assertEquals(SwapDirectory.defaultInstance(dataDir).toString(), mingleProperties.swapDir.toString());
        assertEquals(LogDirectory.defaultInstance(dataDir).toString(), mingleProperties.logDir.toString());
        assertEquals("127.0.0.1", mingleProperties.memcachedHost);
        assertEquals("11211", mingleProperties.memcachedPort);
        assertEquals("/", mingleProperties.appContext);
        assertEquals("1", mingleProperties.port);
    }

    @Test
    public void loadPropertiesShouldCreateMinglePropertiesWithDefaultValuesIfNoneExists() {
        MingleProperties mingleProperties = factory.loadMingleProperties(dataDir, configDir);

        assertEquals(SwapDirectory.defaultInstance(dataDir).toString(), mingleProperties.swapDir.toString());
        assertEquals(LogDirectory.defaultInstance(dataDir).toString(), mingleProperties.logDir.toString());
        assertEquals("127.0.0.1", mingleProperties.memcachedHost);
        assertEquals("11211", mingleProperties.memcachedPort);
        assertEquals("/", mingleProperties.appContext);
        assertEquals("8080", mingleProperties.port);
    }

    @Test
    public void unrecognizedPropertiesShouldBeLoadedAndSavedBackToThePropertiesFile() throws Exception {
        StringBuilder properties = new StringBuilder();
        properties.append(formatProperty(MingleProperties.SWAP_DIR_KEY, "aSwapDir"));
        properties.append(formatProperty("com.sun.management.jmxremote.ssl", "false"));
        properties.append("# some new comment\r\n");
        writeMinglePropertiesForTest(properties.toString());

        MingleProperties mingleProperties = factory.loadMingleProperties(dataDir, configDir);
        assertPropertiesFileIncludesLine("-Dcom.sun.management.jmxremote.ssl=false");
        assertPropertiesFileIncludesLine("# some new comment");
        assertPropertiesFileIncludesLine("-D" + MingleProperties.SWAP_DIR_KEY + "=aSwapDir");

        mingleProperties.save();
        assertPropertiesFileIncludesLine("-Dcom.sun.management.jmxremote.ssl=false");
        assertPropertiesFileIncludesLine("# some new comment");
        assertPropertiesFileIncludesLine("-D" + MingleProperties.SWAP_DIR_KEY + "=aSwapDir");
    }

    @Test
    public void deprecatedPropertiesShouldBeRemoved() throws Exception {
        StringBuilder properties = new StringBuilder();
        properties.append(formatProperty(MingleProperties.DEPRECATED_JRUBY_MAX_ACCESS_THREADS_KEY, "5"));
        writeMinglePropertiesForTest(properties.toString());
        assertPropertiesFileIncludesLine(formatProperty(MingleProperties.DEPRECATED_JRUBY_MAX_ACCESS_THREADS_KEY, "5").trim());

        factory.loadMingleProperties(dataDir, configDir);
        assertPropertiesFileDoesNotIncludeLine(formatProperty(MingleProperties.DEPRECATED_JRUBY_MAX_ACCESS_THREADS_KEY, "5").trim());
    }

    @Test
    public void shouldNotSetSslSystemPropsIfNull() throws Exception {
        StringBuilder properties = new StringBuilder();
        properties.append(formatProperty(MingleProperties.MINGLE_PORT_KEY, "8081"));
        writeMinglePropertiesForTest(properties.toString());

        MingleProperties mingleProperties = factory.loadMingleProperties(dataDir, configDir);
        mingleProperties.configureSystemProperties();

        assertEquals(null, System.getProperty(MingleProperties.MINGLE_SSL_PORT_KEY));
        assertEquals("8081", System.getProperty(MingleProperties.MINGLE_PORT_KEY));
    }

    @Test
    public void shouldNotSetPortSystemPropIfNull() throws Exception {
        System.clearProperty(MingleProperties.MINGLE_PORT_KEY);

        StringBuilder properties = new StringBuilder();
        properties.append(formatProperty(MingleProperties.MINGLE_SSL_PORT_KEY, "8089"));
        properties.append(formatProperty(MingleProperties.MINGLE_SSL_KEYSTORE_KEY, "/Users/schu/.keystore"));
        properties.append(formatProperty(MingleProperties.MINGLE_SSL_KEYSTORE_PASSWORD_KEY, "keystore foobar"));
        properties.append(formatProperty(MingleProperties.MINGLE_SSL_KEY_PASSWORD_KEY, "keypair_passphrase"));
        writeMinglePropertiesForTest(properties.toString());

        MingleProperties mingleProperties = factory.loadMingleProperties(dataDir, configDir);
        mingleProperties.configureSystemProperties();

        assertEquals(null, System.getProperty(MingleProperties.MINGLE_PORT_KEY));
        assertEquals("8089", System.getProperty(MingleProperties.MINGLE_SSL_PORT_KEY));
    }

    @Test
    public void shouldStripAnyPropertyKeyAndValues() throws Exception {
        StringBuilder properties = new StringBuilder();
        properties.append("-D " + MingleProperties.MINGLE_PORT_KEY + " = 1234  \r\n");
        writeMinglePropertiesForTest(properties.toString());

        MingleProperties mingleProperties = factory.loadMingleProperties(dataDir, configDir);
        mingleProperties.configureSystemProperties();

        assertEquals("1234", System.getProperty(MingleProperties.MINGLE_PORT_KEY));
    }

    @Test
    public void defaultMingleJRubyMaxAccessThread() {
        assertEquals(12, MingleProperties.jrubyMaxRuntimes(null));
    }

    @Test
    public void changeMingleThreadPoolSizeByLegacySystemProperty() {
        System.clearProperty(MingleProperties.JRUBY_MAX_RUNTIMES_KEY);
        System.setProperty(MingleProperties.DEPRECATED_JRUBY_MAX_ACCESS_THREADS_KEY, "2");
        try {
            assertEquals(2, MingleProperties.jrubyMaxRuntimes(null));
            assertNull(System.getProperty(MingleProperties.DEPRECATED_JRUBY_MAX_ACCESS_THREADS_KEY));
            assertEquals("2", System.getProperty(MingleProperties.JRUBY_MAX_RUNTIMES_KEY));
        } finally {
            System.clearProperty(MingleProperties.JRUBY_MAX_RUNTIMES_KEY);
            System.clearProperty(MingleProperties.DEPRECATED_JRUBY_MAX_ACCESS_THREADS_KEY);
        }
    }

    @Test
    public void changeMingleThreadPoolSizeBySystemProperty() {
        System.setProperty(MingleProperties.DEPRECATED_JRUBY_MAX_ACCESS_THREADS_KEY, "12");

        /* takes precedence over legacy property */
        System.setProperty(MingleProperties.JRUBY_MAX_RUNTIMES_KEY, "2");
        try {
            assertEquals(2, MingleProperties.jrubyMaxRuntimes(null));
        } finally {
            System.clearProperty(MingleProperties.JRUBY_MAX_RUNTIMES_KEY);
            System.clearProperty(MingleProperties.DEPRECATED_JRUBY_MAX_ACCESS_THREADS_KEY);
        }
    }

    @Test
    public void shouldReturnRouteConfigPathForInProgressRoutesWhenInProgressRouteConfigIsSetToTrue(){
        System.setProperty(MingleProperties.IN_PROGRESS_ROUTING_CONFIG, "true");
        MingleProperties props = new MinglePropertiesFactory().loadMingleProperties(dataDir, configDir);
        assertEquals("somePath/config/in_progress_routes.yml",props.multiAppRoutingConfig("somePath"));
    }

    @Test
    public void shouldReturnRouteConfigPathForRoutesWhenInProgressRouteConfigIsNot(){
        MingleProperties props = new MinglePropertiesFactory().loadMingleProperties(dataDir, configDir);
        assertEquals("somePath/config/routes.yml",props.multiAppRoutingConfig("somePath"));
    }

    private void assertPropertiesFileIncludesLine(String expectedLine) throws Exception {
        Assert.assertTrue("Expected to find line '" + expectedLine + "' in properties file.",
                readMinglePropertiesLines().contains(expectedLine));
    }

    private void assertPropertiesFileDoesNotIncludeLine(String expectedLine) throws Exception {
        Assert.assertFalse("Expected to NOT find line '" + expectedLine + "' in properties file.",
                readMinglePropertiesLines().contains(expectedLine));
    }

    private List<String> readMinglePropertiesLines() throws Exception {
        ArrayList<String> lines = new ArrayList<String>();

        String filename = dirForTest.getPath() + File.separator + MingleProperties.FILE_NAME;
        BufferedReader reader = null;

        try {
            reader = new BufferedReader(new FileReader(new File(filename)));
            String line = null;
            while ((line = reader.readLine()) != null) {
                lines.add(line);
            }
        } finally {
            if (reader != null) {
                reader.close();
            }
        }
        return lines;
    }

    private void writeMinglePropertiesForTest(String properties) throws FileNotFoundException {
        File file = new File(dirForTest.getPath(), MingleProperties.FILE_NAME);
        System.out.println("writing properties to: " + file.getAbsolutePath());
        PrintStream ps = new PrintStream(new FileOutputStream(file));
        ps.println(properties);
        ps.close();
    }

    private String formatProperty(String propertyName, String value) {
        return String.format("-D%s=%s\r\n", propertyName, value);
    }

}
