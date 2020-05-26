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
import com.thoughtworks.mingle.util.MingleConfigUtils;
import org.apache.commons.io.FileUtils;
import org.apache.commons.lang.StringUtils;

import java.io.*;
import java.nio.file.Paths;
import java.util.*;

/**
 * MingleProperties understands the different configuration parameters for a Mingle instance
 */
public class MingleProperties {

    public static final String MINGLE_PROPERTIES_EXAMPLE_MESSAGE = "#Refer to the mingle.properties.example file in your Mingle installation folder to see other properties that can be set to configure Mingle";
    public static final String MULTI_APP_ROUTING_CONFIG = "mingle.multiAppRoutingConfig";
    public static final String MULTI_APP_ROUTING_ENABLED = "mingle.multiAppRoutingEnabled";
    public static final String FILE_NAME = "mingle.properties";
    public static final String MINGLE_PROPERTIES_KEY = FILE_NAME;
    /**
     * if jruby.min.runtimes is not specified, it will be set to Math.min(DEFAULT_INIT_RUNTIMES_LIMIT, jruby.max.runtimes)
     */
    public static int DEFAULT_INIT_RUNTIMES_LIMIT = 25;

    /**
     * default value for jruby.max.runtimes if not specified
     */
    public static int DEFAULT_MAX_RUNTIMES = 12;

    public static final String DATA_DIR_KEY = "mingle.dataDir";
    public static final String CONFIG_DIR_KEY = "mingle.configDir";
    public static final String SWAP_DIR_KEY = "mingle.swapDir";
    public static final String LOG_DIR_KEY = "mingle.logDir";

    public static final String MINGLE_PORT_KEY = "mingle.port";
    public static final String MINGLE_BIND_INTERFACE_KEY = "mingle.bindInterface";
    public static final String MEMCACHED_HOST_KEY = "mingle.memcachedHost";
    public static final String MEMCACHED_PORT_KEY = "mingle.memcachedPort";
    public static final String APP_CONTEXT_KEY = "mingle.appContext";

    public static final String MINGLE_SSL_PORT_KEY = "mingle.ssl.port";
    public static final String MINGLE_SSL_KEYSTORE_KEY = "mingle.ssl.keystore";
    public static final String MINGLE_SSL_KEYSTORE_PASSWORD_KEY = "mingle.ssl.keystorePassword";
    public static final String MINGLE_SSL_KEY_PASSWORD_KEY = "mingle.ssl.keyPassword";

    public static final String MINGLE_SITE_URL = "mingle.siteURL";
    public static final String MINGLE_SECURE_SITE_URL = "mingle.secureSiteURL";
    public static final String MINGLE_PROJECT_CACHE_MAX_SIZE = "mingle.projectCacheMaxSize";
    public static final String MINGLE_SEARCH_HOST = "mingle.search.host";
    public static final String MINGLE_SEARCH_PORT = "mingle.search.port";

    public static final String NO_BACKGROUND_JOB_KEY = "mingle.noBackgroundJob";
    public static final String DEPRECATED_JRUBY_MAX_ACCESS_THREADS_KEY = "mingle.jrubyMaxAccessThreads";
    public static final String JRUBY_MIN_RUNTIMES_KEY = "jruby.min.runtimes";
    public static final String JRUBY_MAX_RUNTIMES_KEY = "jruby.max.runtimes";
    public static final String SERVICES_KEY = "mingle.services";
    public static final String IN_PROGRESS_ROUTING_CONFIG = "mingle.inProgressRoutingConfig";

    private static final String[] deprecatedPropertiesToClear = {
        DEPRECATED_JRUBY_MAX_ACCESS_THREADS_KEY
    };

    private static final String[] propertiesRecognizedByMingle = {
        MINGLE_PROJECT_CACHE_MAX_SIZE,
        SWAP_DIR_KEY,
        MINGLE_PORT_KEY,
        LOG_DIR_KEY,
        MEMCACHED_HOST_KEY,
        MEMCACHED_PORT_KEY,
        APP_CONTEXT_KEY,
        MINGLE_SITE_URL,
        MINGLE_SECURE_SITE_URL
    };

    private Properties properties;

    public static boolean isNoBackgroundJob() {
        return "true".equalsIgnoreCase(System.getProperty(MingleProperties.NO_BACKGROUND_JOB_KEY));
    }

    public static int jrubyMaxRuntimes(Properties properties) {
        if (null == properties) {
            properties = System.getProperties();
        }

        // Configuration used by JRuby-Rack
        String num = properties.getProperty(MingleProperties.JRUBY_MAX_RUNTIMES_KEY);

        // backwards compatibility
        if (num == null || "".equals(num)) {
            num = properties.getProperty(DEPRECATED_JRUBY_MAX_ACCESS_THREADS_KEY);
            properties.remove(DEPRECATED_JRUBY_MAX_ACCESS_THREADS_KEY);

            if (num == null || "".equals(num)) {
                num = String.valueOf(DEFAULT_MAX_RUNTIMES);
            } else {
                System.err.println("[DEPRECATED] *** Property " + DEPRECATED_JRUBY_MAX_ACCESS_THREADS_KEY + " is DEPRECATED. Please use " + JRUBY_MAX_RUNTIMES_KEY + " and optionally " + JRUBY_MIN_RUNTIMES_KEY + " instead.");
            }
            properties.setProperty(MingleProperties.JRUBY_MAX_RUNTIMES_KEY, num);
        }

        try {
            return Integer.parseInt(num);
        } catch (NumberFormatException e) {
            throw new RuntimeException("no valid " + MingleProperties.JRUBY_MAX_RUNTIMES_KEY + " or " + DEPRECATED_JRUBY_MAX_ACCESS_THREADS_KEY + " number initialized: " + num);
        }
    }

    public static int jrubyMinRuntimes(Properties properties) {
        if (null == properties) {
            properties = System.getProperties();
        }

        // Configuration used by JRuby-Rack
        String num = properties.getProperty(MingleProperties.JRUBY_MIN_RUNTIMES_KEY);

        if (num == null || "".equals(num)) {
            num = String.valueOf(Math.min(jrubyMaxRuntimes(properties), DEFAULT_INIT_RUNTIMES_LIMIT));
            properties.setProperty(MingleProperties.JRUBY_MIN_RUNTIMES_KEY, num);
        }

        try {
            return Integer.parseInt(num);
        } catch (NumberFormatException e) {
            throw new RuntimeException("no valid " + MingleProperties.JRUBY_MIN_RUNTIMES_KEY + " number initialized: " + num);
        }
    }

    public String port;
    public SwapDirectory swapDir;
    public LogDirectory logDir;
    public String memcachedPort;
    public String memcachedHost;
    public String appContext;
    public DataDirectory dataDir;

    public String sslPort;
    public String sslKeystore;
    public String sslKeystorePassword;
    public String sslKeyPassword;
    public ConfigDirectory configDir;

    public String siteURL;
    public String secureSiteURL;

    public String projectCacheMaxSize;


    public MingleProperties(DataDirectory dataDir, ConfigDirectory configDir, Properties properties) {
        this.configDir = configDir;
        this.dataDir = dataDir;
        setPropertiesFrom(properties);
    }

    private void setPropertiesFrom(Properties properties) {
        this.properties = properties;
        this.swapDir = new SwapDirectory(getProperty(SWAP_DIR_KEY, properties));
        this.port = getProperty(MINGLE_PORT_KEY, properties);
        this.logDir = new LogDirectory(getProperty(LOG_DIR_KEY, properties));
        this.memcachedHost = getProperty(MEMCACHED_HOST_KEY, properties);
        this.memcachedPort = getProperty(MEMCACHED_PORT_KEY, properties);

        this.appContext = getProperty(APP_CONTEXT_KEY, properties);

        this.sslPort = getProperty(MINGLE_SSL_PORT_KEY, properties);
        this.sslKeystore = getProperty(MINGLE_SSL_KEYSTORE_KEY, properties);
        this.sslKeystorePassword = getProperty(MINGLE_SSL_KEYSTORE_PASSWORD_KEY, properties);
        this.sslKeyPassword = getProperty(MINGLE_SSL_KEY_PASSWORD_KEY, properties);

        this.siteURL = getProperty(MINGLE_SITE_URL, properties);
        this.secureSiteURL = getProperty(MINGLE_SECURE_SITE_URL, properties);
        this.projectCacheMaxSize = getProperty(MINGLE_PROJECT_CACHE_MAX_SIZE, properties);
    }

    public void storeMingleProperties(Properties properties) {
        ArrayList<String> storeLines = new ArrayList<String>();
        storeLines.add(MINGLE_PROPERTIES_EXAMPLE_MESSAGE);
        try {
            BufferedReader reader = new BufferedReader(new FileReader(minglePropertiesFileName()));
            String readline;
            while ((readline = reader.readLine()) != null) {
                if (lineIsNotRecognizedByMingle(readline) && !deprecatedSettingToRemove(readline)) {
                    storeLines.add(readline);
                }
            }
            reader.close();
        } catch (IOException ignore) {
        }

        for (Enumeration e = properties.propertyNames(); e.hasMoreElements(); ) {
            String propertyName = (String) e.nextElement();
            storeLines.add(addDashD(propertyName) + "=" + properties.getProperty(propertyName));
        }

        writeLinesToFile(storeLines);
    }

    private static String addDashD(String propKey) {
        return "-D" + propKey;
    }

    public void save() {
        Properties properties = new Properties();
        properties.setProperty(SWAP_DIR_KEY, swapDir.toString());

        if (logDir != null) {
            properties.setProperty(LOG_DIR_KEY, logDir.toString());
        }

        if (port != null) {
            properties.setProperty(MINGLE_PORT_KEY, String.valueOf(port));
        }
        if (memcachedHost != null) {
            properties.setProperty(MEMCACHED_HOST_KEY, memcachedHost);
        }
        if (memcachedPort != null) {
            properties.setProperty(MEMCACHED_PORT_KEY, memcachedPort);
        }
        if (appContext != null) {
            properties.setProperty(APP_CONTEXT_KEY, appContext);
        }

        if (siteURL != null) {
            properties.setProperty(MINGLE_SITE_URL, siteURL);
        }

        if (secureSiteURL != null) {
            properties.setProperty(MINGLE_SECURE_SITE_URL, secureSiteURL);
        }

        if (projectCacheMaxSize != null) {
            properties.setProperty(MINGLE_PROJECT_CACHE_MAX_SIZE, projectCacheMaxSize);
        }

        storeMingleProperties(properties);
    }

    private boolean lineIsNotRecognizedByMingle(String line) {
        if (line.startsWith(MINGLE_PROPERTIES_EXAMPLE_MESSAGE)) {
            return false;
        }
        for (String aPropertyRecognizedByMingle : propertiesRecognizedByMingle) {
            if (line.startsWith(addDashD(aPropertyRecognizedByMingle)))
                return false;
        }
        return true;
    }

    /**
     * tests if a line contains a deprecated property, which will be removed from mingle.properties. migrating the
     * value of the deprecated property should be handled in the parsing phase before writing back to file, and not
     * in this method
     * */
    private boolean deprecatedSettingToRemove(String line) {
        for (String deprecatedProperty : deprecatedPropertiesToClear) {
            if (line.startsWith(addDashD(deprecatedProperty)))
                return true;
        }
        return false;
    }

    private void writeLinesToFile(ArrayList<String> storeLines) {
        PrintStream ps = null;
        try {
            ps = new PrintStream(new FileOutputStream(new File(minglePropertiesFileName())));
            for (String line : storeLines) {
                ps.println(line);
            }
        } catch (Exception ignore) {
        } finally {
            if (ps != null) {
                ps.close();
            }
        }
    }

    private String minglePropertiesFileName() {
        return configDir.dir() + File.separator + MingleProperties.FILE_NAME;
    }

    private String getProperty(String propertyName, Properties properties) {
        if (System.getProperty(propertyName) != null) {
            return System.getProperty(propertyName);
        } else if (properties != null && properties.containsKey(propertyName)) {
            return properties.getProperty(propertyName);
        } else {
            return null;
        }
    }

    public void configureSystemProperties() throws MingleSSLValidations.ValidationException {
        for (String key : properties.stringPropertyNames()) {
            System.setProperty(key, properties.getProperty(key));
        }
        System.setProperty("jruby.objectspace.enabled", Boolean.FALSE.toString());
        if (port != null) {
            System.setProperty(MINGLE_PORT_KEY, String.valueOf(port));
        }
        System.setProperty(LOG_DIR_KEY, logDir.toString());
        System.setProperty(MEMCACHED_HOST_KEY, memcachedHost);
        System.setProperty(MEMCACHED_PORT_KEY, memcachedPort);
        System.setProperty(APP_CONTEXT_KEY, appContext);
        if (sslPort != null) {
            new MingleSSLValidations(sslProperties()).validate();
            System.setProperty(MINGLE_SSL_PORT_KEY, sslPort);
            System.setProperty(MINGLE_SSL_KEYSTORE_KEY, sslKeystore);
            System.setProperty(MINGLE_SSL_KEYSTORE_PASSWORD_KEY, sslKeystorePassword);
            System.setProperty(MINGLE_SSL_KEY_PASSWORD_KEY, sslKeyPassword);
        }

        if (!StringUtils.isEmpty(siteURL)) {
            System.setProperty(MINGLE_SITE_URL, siteURL);
        }

        if (!StringUtils.isEmpty(secureSiteURL)) {
            System.setProperty(MINGLE_SECURE_SITE_URL, secureSiteURL);
        }

        if (!StringUtils.isEmpty(projectCacheMaxSize)) {
            System.setProperty(MINGLE_PROJECT_CACHE_MAX_SIZE, projectCacheMaxSize);
        }
    }


    private Map<String, String> sslProperties() {
        Map<String, String> result = new HashMap<String, String>();
        result.put(MINGLE_SSL_PORT_KEY, sslPort);
        result.put(MINGLE_SSL_KEYSTORE_KEY, sslKeystore);
        result.put(MINGLE_SSL_KEYSTORE_PASSWORD_KEY, sslKeystorePassword);
        result.put(MINGLE_SSL_KEY_PASSWORD_KEY, sslKeyPassword);
        return result;
    }

    public boolean isMultiAppRoutingEnabled() {
        return MingleConfigUtils.isTruthy(System.getProperty(MULTI_APP_ROUTING_ENABLED,""));
  }

    public String multiAppRoutingConfig(String basepath) {
        String defaultValue = Paths.get(basepath, "config", "routes.yml").toString();
        String route_config_path = System.getProperty(MULTI_APP_ROUTING_CONFIG, defaultValue);
        if (MingleConfigUtils.isTruthy(System.getProperty(IN_PROGRESS_ROUTING_CONFIG, "")))
            return route_config_path.substring(0, route_config_path.lastIndexOf('/')+1) + "in_progress_routes.yml";
        return route_config_path;
  }
}
