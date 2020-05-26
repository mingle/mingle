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

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class Services {
    public class UnknownServiceException extends RuntimeException {
        public UnknownServiceException(String msg) {
            super(msg);
        }
    }

    private Map<String, Service> services = new HashMap<String, Service>();
    private List<Service> startedServices = new ArrayList<Service>();

    public void add(String name, Service service) {
        services.put(name, service);
    }

    public void start(String serviceNames) {
        if (strBlank(serviceNames)) {
            return;
        }
        for (String serviceName : serviceNames.split(",")) {
            Service service = services.get(serviceName.trim());
            if (service == null) {
                throw new UnknownServiceException("Unknown service name: " + serviceName.trim());
            }
            startedServices.add(0, service);
            service.start();
        }
    }

    public void stop() {
        for (Service service : startedServices) {
            service.stop();
        }
        startedServices.clear();
    }

    private boolean strBlank(String str) {
        return null == str || str.trim().equals("");
    }
}
