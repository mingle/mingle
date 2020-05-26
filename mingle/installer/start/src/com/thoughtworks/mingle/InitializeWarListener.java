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

import com.thoughtworks.mingle.util.MingleConfigUtils;
import org.apache.commons.io.FileUtils;
import javax.servlet.ServletContext;
import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;
import java.io.File;
import java.net.URL;

public class InitializeWarListener implements ServletContextListener {
    @Override
    public void contextInitialized(ServletContextEvent event) {
        String warPackaged = event.getServletContext().getInitParameter("war.packaged");
        if ("true".equals(warPackaged)) {
            loadProperties(event);
        }
    }

    private void loadProperties(ServletContextEvent event) {
        ServletContext context = event.getServletContext();
        String webAppBasePath = context.getRealPath("/WEB-INF");
        String dataDir = System.getProperty(MingleProperties.DATA_DIR_KEY, webAppBasePath);
        MingleConfigUtils.setBaseDir(webAppBasePath);
        try {
            String minglePropertiesUrl = System.getProperty("MINGLE_PROPERTIES_URL");
            if (minglePropertiesUrl != null) {
                FileUtils.copyURLToFile(new URL(minglePropertiesUrl), new File(webAppBasePath, "config/mingle.properties"));
            }
            MingleProperties mingleProperties = new MinglePropertiesFactory().loadMingleProperties(dataDir);
            context.setAttribute(MingleProperties.MINGLE_PROPERTIES_KEY, mingleProperties);
            mingleProperties.configureSystemProperties();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    public void contextDestroyed(ServletContextEvent servletContextEvent) {

    }
}
