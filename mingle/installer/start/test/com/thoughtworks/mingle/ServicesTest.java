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

import com.thoughtworks.mingle.services.Service;
import com.thoughtworks.mingle.services.Services;
import org.junit.Before;
import org.junit.Test;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

public class ServicesTest implements Service {
    public static int startedCount = 0;
    public static int stopCount = 0;
    public boolean start;
    public int startIndex = -1;
    public int stopIndex = -1;

    @Before
    public void setUp() {
        startedCount = 0;
        stopCount = 0;
        start = false;
    }

    @Test
    public void startServicesByGivenOrder() {
        Services services = new Services();
        services.add("test", this);
        ServicesTest service2 = new ServicesTest();
        services.add("test2", service2);
        services.start("test, test2");
        assertTrue(start);
        assertEquals(0, startIndex);
        assertTrue(service2.start);
        assertEquals(1, service2.startIndex);
    }

    @Test(expected = Services.UnknownServiceException.class)
    public void shouldThrowErrorWhenStartingUnknownService() {
        Services services = new Services();
        services.start("test");
    }

    @Test
    public void stopStartedServicesByReversedOrder() {
        Services services = new Services();
        services.add("test", this);
        ServicesTest service2 = new ServicesTest();
        services.add("test2", service2);
        ServicesTest service3 = new ServicesTest();
        services.add("test3", service3);
        services.start("test, test2");
        services.stop();
        assertTrue(!start);
        assertEquals(1, stopIndex);
        assertTrue(!service2.start);
        assertEquals(0, service2.stopIndex);

        assertTrue(!service3.start);
        assertEquals(-1, service3.stopIndex);
    }


    @Override
    public void start() {
        start = true;
        startIndex = startedCount++;
    }

    @Override
    public void stop() {
        if (!start) {
            throw new IllegalStateException("Service does not start yet");
        }
        start = false;
        stopIndex = stopCount++;
    }
}
