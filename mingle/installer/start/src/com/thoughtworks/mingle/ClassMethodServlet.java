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

import org.apache.commons.lang.StringEscapeUtils;

import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.util.Enumeration;
import java.util.HashMap;
import java.util.Map;

public class ClassMethodServlet extends HttpServlet {

    ServletConfig _config = null;

    public void init(ServletConfig servletConfig) throws ServletException {
        super.init(servletConfig);
        _config = servletConfig;
    }

    protected void doGet(HttpServletRequest req, HttpServletResponse httpServletResponse) throws ServletException, IOException {

        try {
            String klazz = req.getParameter("class");
            String method = req.getParameter("method");
            Map<String, String> options = new HashMap<String, String>();
            Enumeration allParams = req.getParameterNames();
            while (allParams.hasMoreElements()) {
                String paramName = (String) allParams.nextElement();
                if (!paramName.equals("class") && !paramName.equals("method")) {
                    options.put(paramName, req.getParameter(paramName));
                }
            }

            String scriptlet;
            if (options.size() > 0) {
                int optionCount = 0;
                String optionsString = "{";
                for (Map.Entry e : options.entrySet()) {
                    optionCount += 1;
                    optionsString += "'" + e.getKey() + "'";
                    optionsString += " => ";
                    optionsString += "'" + e.getValue() + "'";
                    if (optionCount < options.size()) {
                        optionsString += ", ";
                    }
                }
                optionsString += "}";
                scriptlet = klazz + ".send(:" + method + ", " + optionsString + ")";
            } else {
                scriptlet = klazz + ".send(:" + method + ")";
            }

            String result = String.valueOf(new RubyExpression(getServletContext(), scriptlet).evaluateUsingBorrower("ClassMethodServlet"));

            String message = StringEscapeUtils.escapeHtml("SUCCESS: " + klazz + "." + method + " called, result is: " + result);
            httpServletResponse.getWriter().write("<html><head></head><body>" + message + "</body></html>");
        } catch (Exception e) {
            throw new ServletException(e);
        }
    }

}
