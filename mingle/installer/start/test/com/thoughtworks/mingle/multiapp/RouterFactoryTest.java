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

import org.apache.commons.io.FileUtils;
import org.junit.Test;

import java.io.File;
import java.util.UUID;

import static org.junit.Assert.assertTrue;

public class RouterFactoryTest {

    @Test
    public void testShouldCreateStaticRouterWhenMultiAppRoutingDisabled() throws Exception {
        Router router = RouterFactory.create(false, null, null , null);
        assertTrue(router instanceof StaticRouter);
    }

    @Test
    public void testShouldCreateDynamicRouterWhenMultiAppRoutingDisabled() throws Exception {
        File config = File.createTempFile("config", UUID.randomUUID().toString());
        Router router = RouterFactory.create(true, config.getAbsolutePath(), null , null);
        assertTrue(router instanceof DynamicRouter);
        config.delete();
    }

}
