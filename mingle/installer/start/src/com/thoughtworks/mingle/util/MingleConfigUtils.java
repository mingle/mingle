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

package com.thoughtworks.mingle.util;

import com.thoughtworks.mingle.ConfigFileNotFoundException;
import com.thoughtworks.mingle.MingleProperties;
import org.jruby.Ruby;
import org.jruby.javasupport.JavaEmbedUtils;

import javax.servlet.ServletContext;
import java.io.File;
import java.net.InetSocketAddress;
import java.util.*;

public class MingleConfigUtils {

    public static final String DEFAULT_MEMCACHED_HOST = "127.0.0.1";
    public static final int DEFAULT_MEMCACHED_PORT = 11211;
    private static String _baseDir = ".";

    public static File configFile(String name) {
        String configDirName = currentConfigDir();
        File configFileInConfigDir = new File(configDirName, name);
        if (configFileInConfigDir.exists()) {
            return configFileInConfigDir;
        }

        File configFile = new File(new File(_baseDir, "config").getAbsolutePath(), name);
        if (configFile.exists()) {
            return configFile;
        }

        throw new ConfigFileNotFoundException("Could not find config file[" + name + "] in Mingle config dir[" + configDirName + "] and the config dir inside web app base [" + _baseDir + "].");
    }

    public static void setBaseDir(String baseDir) {
        _baseDir = baseDir;
    }

    public static String currentConfigDir() {
        return System.getProperty(MingleProperties.CONFIG_DIR_KEY);
    }

    public static List<InetSocketAddress> memcachedInetAddresses(String hosts, String ports) {
        String splitRegex = "\\s*,\\s*";
        ArrayList<InetSocketAddress> result = new ArrayList<>();
        if(hosts == null) {
            result.add(new InetSocketAddress(DEFAULT_MEMCACHED_HOST, DEFAULT_MEMCACHED_PORT));
        } else {
            String[] hostNames = hosts.split(splitRegex);
            String[] portsValues = ports.split(splitRegex);
            for (int i = 0; i < hostNames.length; i++) {
                result.add(new InetSocketAddress(hostNames[i], Integer.parseInt(portsValues[i])));
            }
        }
        return result;
    }

    public static boolean isTruthy(String val) {
      switch (val.toLowerCase()) {
        case "t":
        case "true":
        case "1":
        case "y":
        case "yes": return true;

        default: return false;
      }
    }

    public static String railsRoot(ServletContext context) {
        String appRootDir = context.getRealPath("/WEB-INF");
        if (!new File(appRootDir).exists())
            appRootDir = "";
        return appRootDir;
    }

    public static class HashMapWithDefaultValue<KeyType, ValueType> extends HashMap<KeyType, ValueType> {
        private ValueType defaultValue;


        public HashMapWithDefaultValue(ValueType defaultValue) {
            super();
            this.defaultValue = defaultValue;
        }

        public ValueType get(Object key) {
            if (containsKey(key)) {
                return super.get(key);
            }
            return this.defaultValue;
        }
    }

    public static Map loadPropertiesFromYaml(String pathToYAML) {
        Ruby runtime = Ruby.newInstance();
        String script = "require 'yaml'\n" +
                "require 'erb'\n" +
                "file_path =  File.expand_path('" + pathToYAML + "');\n" +
                "substituted_file = ERB::new(IO.read(file_path)).result;\n" +
                "YAML::load(substituted_file)";
        return (Map) JavaEmbedUtils.rubyToJava(runtime, runtime.evalScriptlet(script), Map.class);
    }

}
