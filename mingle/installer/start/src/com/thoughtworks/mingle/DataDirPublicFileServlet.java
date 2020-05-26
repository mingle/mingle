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

import org.apache.catalina.util.RequestUtil;
import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.StringUtils;

import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.File;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;
import java.util.regex.Pattern;

public class DataDirPublicFileServlet extends HttpServlet {
    private static Pattern dataDirRegex = Pattern.compile("(/attachments(?:_(?:\\d+))?/|/project/|/user/).*");
    private File publicDir;
    private String cacheControl;

    @Override
    public void init() throws ServletException {
        String dataDir = System.getProperty(MingleProperties.DATA_DIR_KEY);
        if (dataDir == null) {
            throw new RuntimeException("Need mingle.dataDir init parameter");
        }
        cacheControl = getServletConfig().getInitParameter("cacheControl");
        setPublicDir(new File(new File(dataDir).getAbsolutePath(), "public"));
        super.init();
    }

    @Override
    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        if (!StringUtils.isBlank(cacheControl)) {
            response.setHeader("Cache-Control", cacheControl);
        }
        serveResource(request, response);
    }

    public void serveResource(HttpServletRequest request, HttpServletResponse response) throws IOException {
        String requestedPath = request.getRequestURI().replace(request.getContextPath(), "");

        File f = new File(this.publicDir.getAbsoluteFile(), requestedPath);
        if (f.exists() && f.isFile() && FileUtils.directoryContains(this.publicDir, f)) {

            Map<String, String[]> params = new HashMap<String, String[]>();
            RequestUtil.parseParameters(params, request.getQueryString(), "UTF-8");

            if (params.containsKey("download")) {
                response.setHeader("Content-Disposition", "attachment; filename=\"" + f.getName() + "\"");
            }

            FileUtils.copyFile(f, response.getOutputStream());
        } else {
            response.setStatus(404);
        }
    }

    public static boolean isDataDirPublicFileRequest(String requestURI) {
        return dataDirRegex.matcher(requestURI).matches();
    }

    public void setPublicDir(File dir) {
        this.publicDir = dir;
    }
}
