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

package com.thoughtworks.mingle.multiapp;

import net.spy.memcached.MemcachedClient;
import org.junit.Before;
import org.junit.Test;

import java.io.File;
import java.io.IOException;
import java.util.UUID;

import static org.junit.Assert.*;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

public class RouteConfigClientTest {

    private File tempFile;
    private MemcachedClient memcachedClient;

    @Before
    public void setUp() throws Exception {
        tempFile = File.createTempFile("tmp", UUID.randomUUID().toString());
        memcachedClient = mock(MemcachedClient.class);
    }

    @Test
    public void testIsEnabledChecksMemcached() throws IOException {
        when(memcachedClient.get("MULTI_APP_ROUTING_DISABLED")).thenReturn("false");

        assertTrue(new RouteConfigClient(tempFile.getAbsolutePath(), memcachedClient).isEnabled());
    }

    @Test
    public void testIsEnabledWhenMemcachedCheckReturnsEmpty() throws IOException {
        when(memcachedClient.get("MULTI_APP_ROUTING_DISABLED")).thenReturn(null);

        assertTrue(new RouteConfigClient(tempFile.getAbsolutePath(), memcachedClient).isEnabled());
    }

    @Test
    public void testIsDisableddWhenMemcachedCheckReturnsTrue() {
        when(memcachedClient.get("MULTI_APP_ROUTING_DISABLED")).thenReturn("true");

        assertFalse(new RouteConfigClient(tempFile.getAbsolutePath(), memcachedClient).isEnabled());
    }

}
