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

package com.thoughtworks.mingle.services;

import com.thoughtworks.mingle.MingleProperties;
import com.thoughtworks.mingle.util.MingleConfigUtils;
import org.apache.activemq.ActiveMQConnectionFactory;
import org.apache.activemq.ActiveMQPrefetchPolicy;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.util.Map;

public class ActiveMQSupport implements Service {
    private static final String DEFAULT_BROKER_CONFIG_URI = "broker.yml";
    private static Logger logger = LoggerFactory.getLogger("ActiveMQ Connection");
    private static ActiveMQConnectionFactory connectionFactory;

    public static ActiveMQConnectionFactory getConnectionFactory() {
        return connectionFactory;
    }

    @Override
    public void start() {
        if (connectionFactory != null) {
            return;
        }
        try {
            connectionFactory = connectionFactory();
            // overwrite policy for all listeners, for pulling mode background jobs, we have another connection factory
            // inside jruby.
            connectionFactory.setPrefetchPolicy(new ActiveMQPrefetchPolicy());
        } catch (Exception e) {
            shutdownOnError(e, "Error caught while initializing jms connection factory and connection. We're sorry but Mingle found a problem it couldn't fix. Please contact your Mingle administrator to resolve this issue.");
        }

    }

    @Override
    public void stop() {
    }

    private ActiveMQConnectionFactory connectionFactory() {
        String brokerConfig = System.getProperty(MingleProperties.CONFIG_DIR_KEY) + File.separator + DEFAULT_BROKER_CONFIG_URI;
        logger.info("Loading broker config at: " + brokerConfig);
        try {
            final Map broker = loadYamlConfig(brokerConfig);
            String username = getValue(broker, "username");
            String password = getValue(broker, "password");
            String activemqURI = getValue(broker, "uri");
            logger.info("ActiveMQ connection username: " + username);
            logger.info("ActiveMQ connection URI: " + activemqURI);
            if ("".equals(activemqURI)) {
                logger.info("The broker config has no ActiveMQ connection URI configured, use default instead, and rename invalid broker file");
                renameBrokerConfigFile(brokerConfig);
                return defaultConfiguredActiveMQConnectionFactory();
            }
            return new ActiveMQConnectionFactory(username, password, activemqURI);
        } catch (RuntimeException e) {
            logger.info("Couldn't load broker config, use default config instead");
            return defaultConfiguredActiveMQConnectionFactory();
        }
    }

    private void shutdownOnError(Throwable e, String message) {
        logger.info(message, e);
        new Thread(new Runnable() {
            @Override
            public void run() {
                System.exit(1);
            }
        }).start();
    }

    private void renameBrokerConfigFile(String brokerConfig) {
        File file = new File(brokerConfig);
        int index = 0;
        File newFile;
        do {
            index++;
            newFile = new File(brokerConfig + "." + index);
        } while (newFile.exists());

        boolean success = file.renameTo(newFile);
        if (success) {
            logger.info("Renamed invalid broker config yml as " + newFile.getAbsolutePath());
        } else {
            logger.info("Couldn't rename invalid broker config to " + newFile.getAbsolutePath());
        }
    }

    private String getValue(Map broker, String propertyName) {
        return (String) broker.get(propertyName);
    }

    private Map loadYamlConfig(String file) {
        return MingleConfigUtils.loadPropertiesFromYaml(file);
    }

    private ActiveMQConnectionFactory defaultConfiguredActiveMQConnectionFactory() {
        return new ActiveMQConnectionFactory("mingle", "password", "vm://localhost?create=false");
    }

}
