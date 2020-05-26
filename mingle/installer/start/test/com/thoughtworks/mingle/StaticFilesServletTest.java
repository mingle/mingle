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

import static junit.framework.Assert.assertFalse;
import static junit.framework.Assert.assertTrue;

public class StaticFilesServletTest {
    @Test
    public void isStaticFile() {
        assertTrue("should be true", StaticFilesServlet.isStaticFile("/favicon.ico"));
        assertTrue("should be true", StaticFilesServlet.isStaticFile("/assets/stylesheets/foo.css"));
        assertTrue("should be true", StaticFilesServlet.isStaticFile("/images/icon/123"));
        assertTrue("should be true", StaticFilesServlet.isStaticFile("/javascripts/icon/123"));
        assertTrue("should be true", StaticFilesServlet.isStaticFile("/flash/clippy.swf"));
        assertTrue("should be true", StaticFilesServlet.isStaticFile("/fonts/font-awesome.woff"));

        assertFalse("should be false", StaticFilesServlet.isStaticFile("/assets.jpg"));
        assertFalse("should be false", StaticFilesServlet.isStaticFile("/project/icon/123"));
        assertFalse("should be false", StaticFilesServlet.isStaticFile("/user/icon/123"));
    }

}
