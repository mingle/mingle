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

package com.thoughtworks.mingle.rack;

import com.thoughtworks.mingle.MingleProperties;
import com.thoughtworks.mingle.security.crypto.MingleLoadService;
import org.jruby.Profile;
import org.jruby.Ruby;
import org.jruby.RubyInstanceConfig;
import org.jruby.rack.rails.RailsRackApplicationFactory;
import org.jruby.runtime.builtin.IRubyObject;
import org.jruby.runtime.load.LoadService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import static com.thoughtworks.mingle.multiapp.RouteConfigClient.MULTI_APP_ROUTING_DISABLED;

/**
 * MingleRuntimeFactory understands how to create a single JRuby runtime that can run Mingle.
 * Any constants or environment variables needed for Mingle to start correctly must be defined here.
 */
public class MingleRuntimeFactory extends RailsRackApplicationFactory {
    private String contextPath;
    private int dbConnectionPoolSize;
    private String appRootDir;
    private static Logger logger = LoggerFactory.getLogger("com.thoughtworks.mingle.rack");

    public MingleRuntimeFactory(String contextPath, int dbConnectionPoolSize, String appRootDir) {
        this.contextPath = contextPath;
        this.dbConnectionPoolSize = dbConnectionPoolSize;
        this.appRootDir = appRootDir;
    }

    @Override
    public RubyInstanceConfig createRuntimeConfig() {
        RubyInstanceConfig config = super.createRuntimeConfig();

        if ("true".equals(System.getProperty("mingle.profiling"))) {
            config.setProfile(Profile.ALL);
            config.setProfilingMode(RubyInstanceConfig.ProfilingMode.API);
            config.setProfileMaxMethods(10000000);
        }

        config.setLoadServiceCreator(new RubyInstanceConfig.LoadServiceCreator() {
            public LoadService create(Ruby runtime) {
                return new MingleLoadService(runtime, appRootDir);
            }
        });
        return config;
    }

    @SuppressWarnings({"StringConcatenationInsideStringBufferAppend"})
    @Override
    public IRubyObject createApplicationObject(Ruby ruby) {
        String dataDir = System.getProperty(MingleProperties.DATA_DIR_KEY);
        String configDir = System.getProperty(MingleProperties.CONFIG_DIR_KEY);
        String swapDir = System.getProperty(MingleProperties.SWAP_DIR_KEY);
        String memcachedPort = System.getProperty(MingleProperties.MEMCACHED_PORT_KEY);
        String memcachedHost = System.getProperty(MingleProperties.MEMCACHED_HOST_KEY);
        String sslPort = System.getProperty(MingleProperties.MINGLE_SSL_PORT_KEY);

        StringBuffer preloadScripts = new StringBuffer();
        preloadScripts.append("$LOAD_PATH.unshift File.expand_path(File.join('.', 'lib'));\n");
        if(dataDir != null)
            preloadScripts.append("MINGLE_DATA_DIR = File.expand_path('" + dataDir.replaceAll("'", "\\'") + "');\n");
        if(configDir != null)
            preloadScripts.append("MINGLE_CONFIG_DIR = File.expand_path('" + configDir.replaceAll("'", "\\'") + "');\n");
        if(swapDir != null)
            preloadScripts.append("MINGLE_SWAP_DIR = File.expand_path('" + swapDir.replaceAll("'", "\\'") + "');\n");
        if (memcachedHost != null) {
            preloadScripts.append("MINGLE_MEMCACHED_HOST = \"" + memcachedHost + "\";\n");
        }

        if (memcachedPort != null) {
            preloadScripts.append("MINGLE_MEMCACHED_PORT = \"" + memcachedPort + "\";\n");
        }

        preloadScripts.append("CONTEXT_PATH = '" + contextPath + "';\n");
        preloadScripts.append("MULTI_APP_ROUTING_DISABLED = '" + MULTI_APP_ROUTING_DISABLED + "';\n");

        if (sslPort != null) {
            preloadScripts.append("MINGLE_SSL_PORT = '" + sslPort + "';\n");
        }
        preloadScripts.append("$connection_pool_size = " + this.dbConnectionPoolSize + ";\n");

        try {
            ruby.evalScriptlet(preloadScripts.toString());
            return super.createApplicationObject(ruby);
        } catch (Exception e) {
            logger.error(String.format("Failed to create application object: %s", e.getMessage()), e);
            throw new RuntimeException(e);
        }
    }

}
