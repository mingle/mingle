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

import com.thoughtworks.mingle.bootstrap.CurrentBootstrapState;
import com.thoughtworks.mingle.bootstrap.utils.BootstrapChecks;
import com.thoughtworks.mingle.bootstrap.utils.MigrationRunner;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.File;
import java.io.FileNotFoundException;
import java.io.FileReader;
import java.io.FilenameFilter;
import java.io.IOException;
import java.io.PrintWriter;
import java.io.Reader;
import java.net.URI;
import java.util.Properties;

import static java.io.File.separator;

public class StartupServlet extends HttpServlet {
    final Logger logger = LoggerFactory.getLogger(StartupServlet.class);
    private String templatePath;
    private SimpleTemplateBinding binding;
    private BootstrapChecks checks;
    private RailsPathHelper helper;

    public void init(ServletConfig servletConfig) throws ServletException {
        super.init(servletConfig);
        helper = new RailsPathHelper(getServletContext());

        this.templatePath = helper.publicRealPath(servletConfig.getInitParameter("templatePath"));
        checks = new BootstrapChecks(getServletContext());
        binding = SimpleTemplateBinding.getInstance();

        bindTemplateVariables(servletConfig);
    }

    protected void doGet(HttpServletRequest request, HttpServletResponse response) throws ServletException, IOException {
        PrintWriter out = response.getWriter();
        response.setContentType("text/html");
        response.setHeader("Cache-Control", "no-cache");

        binding.bind("currentState", CurrentBootstrapState.get().toString());
        binding.bind("message", getMessage());

        out.print(binding.tokenize(templatePath).render());
    }

    protected void doPost(HttpServletRequest request, HttpServletResponse response) throws IOException, ServletException {
        try {
            if (checks.isSchemaCurrent()) {
                return;
            }
        } catch (Exception e) {
            throw new ServletException(e);
        }
        new MigrationRunner(getServletContext()).start();
    }

    private String getMessage() throws IOException {
        String currentState = CurrentBootstrapState.get().toString();
        String filename = getTemplateForCurrentState(currentState);
        logger.debug("Checking for message template for state " + currentState + " at: " + filename);

        if (new File(filename).exists()) {
            return binding.tokenize(filename).render();
        }

        logger.debug("No message template found for state: " + currentState);

        return currentState;
    }

    private String getQuotedSupportUrl() {
        Reader reader = null;
        try {
            reader = new FileReader(helper.railsRealPath("config/initializers/document.rb").replace("/", File.separator));
            Properties properties = new Properties();
            properties.load(reader);
            return properties.getProperty("THOUGHTWORKS_STUDIOS_SUPPORT_URL");
        } catch (FileNotFoundException e) {
            throw new RuntimeException(e);
        } catch (IOException e) {
            throw new RuntimeException(e);
        } finally {
            if (reader != null) {
                try {
                    reader.close();
                } catch (IOException e) {
                    throw new RuntimeException(e);
                }
            }
        }
    }

    private String getTemplateForCurrentState(String currentState) {
        String messageTemplates = new File(templatePath).getParent() + separator + "startup_messages";
        return messageTemplates + separator + currentState + ".html";
    }

    protected void bindTemplateVariables(ServletConfig servletConfig) {
        binding.bind("assetsJsLink", buildJsLinksFrom(scriptsIn("/assets")));
        binding.bind("stylesheetLinks", buildStylesheetLinksFrom(stylesheetsIn("/assets")));
        binding.bind("communityHome", getRubyProperty("COMMUNITY_HOME"));
        binding.bind("contextPath", getServletContext().getContextPath());
        binding.bind("supportUrl", getRubyProperty("THOUGHTWORKS_STUDIOS_SUPPORT_URL"));
        binding.bind("helpPath", getRubyProperty("ONLINE_HELP_DOC_DOMAIN"));
        binding.bind("helpPathDomain", getRubyProperty("HELP_DOC_DOMAIN"));
        binding.bind("quotedSupportUrl", getQuotedSupportUrl());
    }

    private String getRubyProperty(String name) {
        try {
            return new RubyExpression(getServletContext(), name).evaluateUsingBorrower("StartupServlet").asJavaString();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    protected File[] scriptsIn(final String folderName) {
        File dir = new File(helper.publicRealPath(folderName));
        if (!dir.exists()) {
            return new File[0];
        }

        FilenameFilter sprocketsJs = new FilenameFilter() {
            public boolean accept(File dir, String name) {
                return name.startsWith("sprockets_app-") && name.endsWith(".js");
            }
        };
        return dir.listFiles(sprocketsJs);
    }

    private File[] stylesheetsIn(final String folderName) {
        FilenameFilter sprocketsCss = new FilenameFilter() {
            public boolean accept(File dir, String name) {
                return name.startsWith("sprockets_app") && name.endsWith(".css");
            }
        };
        return new File(helper.publicRealPath(folderName)).listFiles(sprocketsCss);
    }

    private String buildJsLinksFrom(final File[] scripts) {
        StringBuffer result = new StringBuffer();
        for (File script : scripts) {
            result.append(jsLink(script)).append("\n");
        }
        return result.toString();
    }

    private String buildStylesheetLinksFrom(final File[] stylesheets) {
        StringBuffer result = new StringBuffer();
        for (File stylesheet : stylesheets) {
            result.append(stylesheetLink(stylesheet)).append("\n");
        }
        return result.toString();
    }

    protected String jsLink(File script) {
        String uri = uriPathFor("/assets/" + script.getName());
        return "<script src=\"" + uri + "\" type=\"text/javascript\"></script>";
    }

    protected String stylesheetLink(File stylesheet) {
        String uri = uriPathFor("assets/" + stylesheet.getName());

        return "<link href=\"" + uri + "\" media=\"screen\" rel=\"Stylesheet\" type=\"text/css\" />";
    }

    private String uriPathFor(String path) {
        return URI.create("http://doesnotmatter/" + getServletContext().getContextPath() + "/" + path).normalize().getPath();
    }
}
