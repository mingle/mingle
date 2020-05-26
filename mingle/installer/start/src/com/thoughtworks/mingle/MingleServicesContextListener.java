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

import com.thoughtworks.mingle.services.*;

import javax.servlet.ServletContextEvent;
import javax.servlet.ServletContextListener;

public class MingleServicesContextListener implements ServletContextListener {
    private final static String DEFAULT_START_SERVICES = "amq.broker, amq.connection.factory, memcached, elastic_search";
    private Services customServices;

    @Override
    public void contextInitialized(ServletContextEvent servletContextEvent) {
        customServices = new Services();
        customServices.add("amq.broker", new ActiveMQBroker());
        customServices.add("amq.nonblocking.broker", new ActiveMQNonblockingBroker());
        customServices.add("amq.connection.factory", new ActiveMQSupport());
        customServices.add("amq.camel", new ActiveMQCamel());
        customServices.add("memcached", new Memcached());
        customServices.add("elastic_search", new ElasticSearch());

        customServices.start(customServiceNames());
    }

    private String customServiceNames() {
        return System.getProperty(MingleProperties.SERVICES_KEY, DEFAULT_START_SERVICES);
    }

    @Override
    public void contextDestroyed(ServletContextEvent servletContextEvent) {
        customServices.stop();
    }
}
