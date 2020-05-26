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

import com.thoughtworks.mingle.util.MingleConfigUtils;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import java.io.File;
import java.net.InetSocketAddress;
import java.util.List;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

public class MingleUtilsTest {

    public static final String TEST_DATA_DIR = new File("test", "data").getPath();

    @Before
    public void setUp() {
        System.setProperty(MingleProperties.CONFIG_DIR_KEY, TEST_DATA_DIR);
    }

    @After
    public void tearDown() {
        System.setProperty(MingleProperties.CONFIG_DIR_KEY, "");
    }

    @Test
    public void findConfigFileFromMingleConfigDir() {
        File config = MingleConfigUtils.configFile("periodical_tasks.yml");
        assertTrue(config.exists());
        assertTrue(config.getAbsolutePath().contains(TEST_DATA_DIR));
    }

    @Test
    public void shouldFallbackToConfigDirInsideWorkingDirIfConfigFileDoesNotExistInMingleConfigDir() {
        File config = MingleConfigUtils.configFile("broker.yml");
        assertTrue(config.exists());
        assertTrue(config.getAbsolutePath().contains(new File("config", "broker.yml").getPath()));
    }

    @Test(expected = ConfigFileNotFoundException.class)
    public void shouldRaiseErrorWhenConfigFileDoesNotExist() {
        MingleConfigUtils.configFile("hello.world");
    }

    @Test
    public void shouldFetchMemcachedInetAddressesFromHostAndPort() {
        String hosts = "127.0.0.1,localhost";
        String ports = "9989, 12345";

        List<InetSocketAddress> inetAddresses = MingleConfigUtils.memcachedInetAddresses(hosts, ports);

        assertEquals(2, inetAddresses.size());
        assertEquals("127.0.0.1", inetAddresses.get(0).getHostString());
        assertEquals(9989, inetAddresses.get(0).getPort());
        assertEquals("localhost", inetAddresses.get(1).getHostString());
        assertEquals(12345, inetAddresses.get(1).getPort());
    }

    @Test
    public void shouldFetchDefaultMemcachedAddresses() {
        String defaultHost = "127.0.0.1";
        int defaultPort = 11211;

        List<InetSocketAddress> inetAddresses = MingleConfigUtils.memcachedInetAddresses(null, null);

        assertEquals(1, inetAddresses.size());
        assertEquals(defaultHost, inetAddresses.get(0).getHostString());
        assertEquals(defaultPort, inetAddresses.get(0).getPort());
    }
}
