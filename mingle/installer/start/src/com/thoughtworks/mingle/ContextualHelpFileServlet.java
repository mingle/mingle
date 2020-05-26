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

import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.File;
import java.io.IOException;

public class ContextualHelpFileServlet extends HttpServlet {

    private RailsPathHelper helper;

    @Override
    public void init(ServletConfig config) throws ServletException {
        super.init(config);
        helper = new RailsPathHelper(getServletContext());
    }

    protected void doGet(HttpServletRequest httpServletRequest, HttpServletResponse httpServletResponse) throws ServletException, IOException {
        File helpFile = getContextualHelpTemplate(determineFileFromRequestUrl(httpServletRequest));
        httpServletResponse.getWriter().write(render(helpFile));
    }

    private String determineFileFromRequestUrl(HttpServletRequest httpServletRequest) {
        return httpServletRequest.getRequestURI().replace(httpServletRequest.getContextPath(), "");
    }

    private File getContextualHelpTemplate(String filename) {
        return new File(helper.publicRealPath(filename + ".template"));
    }

    private String render(File file) throws IOException {
        if (!file.exists()) return "";
        SimpleTemplateBinding binding = SimpleTemplateBinding.getInstance();
        return binding.tokenize(file.getAbsolutePath()).render();
    }
}
