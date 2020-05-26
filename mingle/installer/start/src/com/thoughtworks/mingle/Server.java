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

import com.thoughtworks.mingle.security.MingleSSLValidations;
import org.apache.catalina.Context;
import org.apache.catalina.Globals;
import org.apache.catalina.connector.Connector;
import org.apache.catalina.core.StandardContext;
import org.apache.catalina.startup.Tomcat;
import org.apache.catalina.valves.AccessLogValve;
import org.apache.catalina.valves.Constants;
import org.apache.commons.lang.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.servlet.ServletException;
import java.io.File;
import java.io.IOException;
import java.util.Map;

public class Server {
    private final Logger logger = LoggerFactory.getLogger(Server.class);

    private Tomcat server;
    private MingleProperties mingleProperties;

    public Server() {
        this.mingleProperties = new MinglePropertiesFactory().loadMingleProperties(System.getProperty(MingleProperties.DATA_DIR_KEY));
    }

    public static void main(String[] args) throws InterruptedException {
        Server server = new Server();
        server.start();
        server.join();
    }

    public static Server testInstance(Map<String, String> systemProperties) {
        for (Map.Entry e : systemProperties.entrySet()) {
            System.setProperty((String) e.getKey(), (String) e.getValue());
        }

        return new Server();
    }

    public void start() {
        try {
            prepare();
            server.start();
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
    }

    public String getStatus() {
        return server.getServer().getState().toString();
    }

    public void prepare() throws MingleSSLValidations.ValidationException, ServletException, IOException {
        mingleProperties.configureSystemProperties();
        String rootDir = new File(".").getCanonicalPath();
        System.setProperty(Globals.CATALINA_HOME_PROP, rootDir);
        System.setProperty(Globals.CATALINA_BASE_PROP, rootDir);
        logger.info(Globals.CATALINA_HOME_PROP + ": " + rootDir);
        logger.info(Globals.CATALINA_BASE_PROP + ": " + rootDir);

        /*
         * Tomcat 5+, by default, prevents escaped slashes in the url to protect against directory traversal attacks.
         * We turn this off to maintain compatibility with Jetty 6 - the SourceController tests had issue with this
         * enabled, so we disable it here.
        */
        System.setProperty("org.apache.tomcat.util.buf.UDecoder.ALLOW_ENCODED_SLASH", "true");

        server = new Tomcat();
        configureWebappContext();
        configureConnector();
    }

    public void stop() throws Exception {
        server.stop();
    }

    void join() throws InterruptedException {
        server.getServer().await();
    }

    private void configureConnector() {

        String connectorType = System.getenv().get("TCCON");
        if ("bio".equalsIgnoreCase(connectorType)) {
            logger.info("*** Forcing bio connector");
            Connector connector = new Connector("org.apache.coyote.http11.Http11Protocol");
            server.setConnector(connector);
            server.getService().addConnector(connector);
        }

        configureListener();
        configureSSLIfNeeded();
        configureOtherConnectorOptions();
    }

    private void configureListener() {
        int port = portToUse();
        String bind = bindInterface();

        server.getConnector().setPort(port);
        server.getConnector().setAttribute("address", bind);

        logger.info("Setting up listener on inet[" + server.getConnector().getAttribute("address") + ":" + server.getConnector().getPort() + "]");
    }

    private void configureOtherConnectorOptions() {
      /* configure GZip compression */
        server.getConnector().setAttribute("compression", "on");
        server.getConnector().setAttribute("compressableMimeType",
                "text/html,text/plain,text/xml,text/css,text/javascript,application/xhtml+xml,application/x-javascript,application/javascript,image/svg+xml");
    }

    private void configureSSLIfNeeded() {

        if (StringUtils.isBlank(System.getProperty(MingleProperties.MINGLE_SSL_PORT_KEY))) {
            logger.info("SSL is disabled.");
            return;
        }

        Connector sslConnector = server.getConnector();
        sslConnector.setSecure(true);
        sslConnector.setScheme("https");
        sslConnector.setAttribute("clientAuth", false);
        sslConnector.setAttribute("sslEnabledProtocols", "TLSv1,TLSv1.1,TLSv1.2");
        sslConnector.setAttribute("SSLEnabled", true);
        sslConnector.setAttribute("keystoreFile", new File(System.getProperty(MingleProperties.MINGLE_SSL_KEYSTORE_KEY)).getAbsolutePath());
        sslConnector.setAttribute("keyPass", System.getProperty(MingleProperties.MINGLE_SSL_KEY_PASSWORD_KEY));
        sslConnector.setAttribute("keystorePass", System.getProperty(MingleProperties.MINGLE_SSL_KEYSTORE_PASSWORD_KEY));
        logger.info("SSL is enabled.");
    }

    private int portToUse() {
        String port = null;
        if (!StringUtils.isBlank(System.getProperty(MingleProperties.MINGLE_SSL_PORT_KEY))) {
            port = System.getProperty(MingleProperties.MINGLE_SSL_PORT_KEY);
        } else {
            port = System.getProperty(MingleProperties.MINGLE_PORT_KEY);
        }
        return Integer.valueOf(port);
    }

    private String bindInterface() {
        String ifc = null;
        if (!StringUtils.isBlank(System.getProperty(MingleProperties.MINGLE_BIND_INTERFACE_KEY ))) {
            ifc = System.getProperty(MingleProperties.MINGLE_BIND_INTERFACE_KEY);
        } else {
            ifc = "0.0.0.0";
        }
        return ifc;
    }

    protected void configureWebappContext() throws ServletException {
        String context = "";
        if (mingleProperties.appContext != null && !"/".equals(mingleProperties.appContext)) {
            context = mingleProperties.appContext;
        }
        String baseDir = new File("").getAbsolutePath();
        logger.info("Web context base dir: " + baseDir);

        Context webContext = server.addWebapp(context, baseDir);
        String webXmlLocation = System.getProperty("mingle.web.xml");
        if (StringUtils.isBlank(webXmlLocation)) {
            webXmlLocation = new File("config", "web.xml").getAbsolutePath();
        }
        logger.info("Loading web.xml from: " + webXmlLocation);
        webContext.getServletContext().setAttribute(Globals.ALT_DD_ATTR, webXmlLocation);
        configureRequestLogging((StandardContext) webContext);
    }

    protected void configureRequestLogging(StandardContext context) {
        AccessLogValve valve = new AccessLogValve();
        valve.setDirectory(System.getProperty(MingleProperties.LOG_DIR_KEY));
        valve.setPattern(Constants.AccessLog.COMBINED_ALIAS);
        context.addValve(valve);
    }
}
