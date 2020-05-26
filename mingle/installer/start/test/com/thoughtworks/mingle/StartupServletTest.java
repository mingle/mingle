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
import org.mockito.ArgumentCaptor;

import javax.servlet.ServletConfig;
import javax.servlet.ServletContext;
import javax.servlet.ServletException;
import java.io.File;
import java.io.IOException;

import static org.junit.Assert.assertEquals;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

public class StartupServletTest {

    private ServletContext context;
    private StartupServlet servlet;

    @Before
    public void setUp() throws Exception {
        ServletConfig config = mock(ServletConfig.class);
        context = mock(ServletContext.class);
        servlet = new StartupServlet() {
            @Override
            protected void bindTemplateVariables(ServletConfig servletConfig) {
            }
        };
        when(config.getServletContext()).thenReturn(context);
        when(config.getInitParameter("templatePath")).thenReturn("/public/templates");

        when(context.getInitParameter("public.root")).thenReturn("/public");
        when(context.getInitParameter("rails.root")).thenReturn("/");
        servlet.init(config);
    }

    @Test
    public void testJavaScriptUrls() throws ServletException {
        when(context.getContextPath()).thenReturn("/mingle");
        assertEquals("<script src=\"/mingle/assets/script.js\" type=\"text/javascript\"></script>", servlet.jsLink(new File("javascripts/script.js")));

        when(context.getContextPath()).thenReturn("/");
        assertEquals("<script src=\"/assets/script.js\" type=\"text/javascript\"></script>", servlet.jsLink(new File("javascripts/script.js")));
    }

    @Test
    public void testStylesheetUrls() throws ServletException {
        when(context.getContextPath()).thenReturn("/mingle");
        assertEquals("<link href=\"/mingle/assets/style.css\" media=\"screen\" rel=\"Stylesheet\" type=\"text/css\" />", servlet.stylesheetLink(new File("stylesheets/style.css")));

        when(context.getContextPath()).thenReturn("/");
        assertEquals("<link href=\"/assets/style.css\" media=\"screen\" rel=\"Stylesheet\" type=\"text/css\" />", servlet.stylesheetLink(new File("stylesheets/style.css")));
    }

    @Test
    public void testScriptsIn() throws ServletException, IOException {
        File f =new File("./tmp/public/assets");
        f.mkdirs();
        File file = new File(f, "sprockets_app-123.js");
        file.createNewFile();
        File file1 = new File(f, "sprockets_app_extra-43573.js");
        file1.createNewFile();
        File file2 = new File(f, "sprockets_app-124.js");
        file2.createNewFile();

        when(context.getRealPath("/public/assets")).thenReturn("./tmp/public/assets");
        File[] actual = servlet.scriptsIn("/assets");
        File [] expected = {file, file2};
        assertEquals(2, actual.length);
        assertEquals(expected[0].getName(), actual[0].getName());
        assertEquals(expected[1].getName(), actual[1].getName());
    }
}
