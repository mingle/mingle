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

import com.thoughtworks.mingle.util.MingleConfigUtils;
import org.apache.activemq.broker.BrokerFactory;
import org.apache.activemq.broker.BrokerService;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;

public class ActiveMQBroker implements Service {
    public static final String DEFAULT_CONFIG_FILE_NAME = "activemq.xml";
    private static Logger logger = LoggerFactory.getLogger("ActiveMQ Broker");

    private BrokerService broker = null;

    public void start() {
        File configFile = MingleConfigUtils.configFile(DEFAULT_CONFIG_FILE_NAME);
        try {
            String brokerURI = "xbean:" + configFile.toURI();
            logger.info("Loading message broker from: " + brokerURI);
            this.broker = BrokerFactory.createBroker(brokerURI, true);
        } catch (Exception e) {
            shutdownOnError(e, "Error caught while starting ActiveMQ Server. We're sorry but Mingle found a problem it couldn't fix. Please contact your Mingle administrator to resolve this issue.");
        }
        logger.info("ActiveMQ Server started");
    }

    public void stop() {
        try {
            if (this.broker != null) {
                logger.info("Stopping ActiveMQ Broker.");
                this.broker.stop();
                logger.info("ActiveMQ Broker stopped.");
            }
        } catch (Exception e) {
            logger.info("Stop ActiveMQ broker service failed.", e);
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

}
