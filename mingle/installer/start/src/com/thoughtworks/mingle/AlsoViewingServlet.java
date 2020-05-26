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

import com.google.gson.Gson;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.IOException;
import java.net.URLDecoder;
import java.nio.charset.Charset;
import java.util.Date;

public class AlsoViewingServlet extends HttpServlet {
    private Logger logger = LoggerFactory.getLogger(AlsoViewingServlet.class);
    private AlsoViewing alsoViewing = AlsoViewing.create();
    private static String ENCODING = "UTF-8";

    @Override
    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        String url = URLDecoder.decode(request.getParameter("url"), ENCODING);
        String currentUser = URLDecoder.decode(request.getParameter("currentUser"), ENCODING);
        logger.debug(String.format("Processing for (%s at %s)", request.getRemoteAddr(), new Date()));
        alsoViewing.add(url, currentUser);
        sendResponse(response, new Gson().toJson(alsoViewing.extractActiveUsersFor(url, currentUser)));
    }

    private void sendResponse(HttpServletResponse response, String json) throws IOException {
        response.setContentType("application/json");
        response.setCharacterEncoding(ENCODING);
        response.getWriter().write(json);
        response.setContentLength(json.getBytes(ENCODING).length);
    }
}
