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

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class HttpRedirectFilterTest {

    private HttpRedirectFilter filter;

    @Before
    public void setup() {
        filter = new HttpRedirectFilter();
    }
    
    @Test
    public void isHttpRequest() {
        assertTrue(filter.isForwardedHttpRequest("http"));
        assertFalse(filter.isForwardedHttpRequest(null));
        assertFalse(filter.isForwardedHttpRequest("https"));
    }

    @Test
    public void replaceHttpWithHttps() {
        String url = filter.replaceHttpWithHttps(new StringBuffer("http://hello"));
        assertEquals("https://hello", url);
    }

}
