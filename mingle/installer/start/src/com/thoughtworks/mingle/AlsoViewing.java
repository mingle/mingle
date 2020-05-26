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


import org.apache.commons.lang.StringUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

public class AlsoViewing {
    public static final int DEFAULT_MARGIN = 4;
    private Map<String, ConcurrentHashMap<String, Long>> visitors = new ConcurrentHashMap<String, ConcurrentHashMap<String, Long>>();
    private Logger logger = LoggerFactory.getLogger(AlsoViewing.class);
    private int timeoutInMilliseconds;
    private int marginInMilliseconds;

    public AlsoViewing(int timeoutInSeconds, int marginInSeconds) {
        this.timeoutInMilliseconds = timeoutInSeconds * 1000;
        this.marginInMilliseconds = marginInSeconds * 1000;
    }

    public static AlsoViewing create() {
        String intervalProperty = System.getProperty("mingle.alsoViewing.interval");
        int interval = 5;
        if (intervalProperty != null) {
            interval = Integer.parseInt(intervalProperty);
        }

        return new AlsoViewing(interval, DEFAULT_MARGIN);
    }

    public void add(String url, String currentUser) {
        if (invalidParams(url, currentUser)) return;
        if (visitors.get(url) == null) {
            visitors.put(url, new ConcurrentHashMap<String, Long>());
        }
        visitors.get(url).put(currentUser, new Date().getTime());
    }

    public HashMap<String, ArrayList<String>> extractActiveUsersFor(String url, String currentUser) {
        long now = new Date().getTime();
        HashMap<String, ArrayList<String>> users = new HashMap<String, ArrayList<String>>();
        users.put("viewers", new ArrayList<String>());
        users.put("editors", new ArrayList<String>());
        if (invalidParams(url, currentUser)) return users;
        ArrayList<String> viewers = extractActiveUsers(StringUtils.removeEndIgnoreCase(url, "/edit"), currentUser, now);
        ArrayList<String> editors = null;
        if (url.endsWith("/edit")) {
            editors = extractActiveUsers(url, currentUser, now);
        } else {
            editors = extractActiveUsers(url + "/edit", currentUser, now);
        }
        viewers.removeAll(editors);
        users.put("viewers", viewers);
        users.put("editors", editors);
        return users;
    }

    private boolean invalidParams(String url, String currentUser) {
        if(StringUtils.isBlank(url) || StringUtils.isBlank(currentUser)){
            logger.debug("Should not give blank url or currentUser!");
            return true;
        }
        return false;
    }
    
    private ArrayList<String> extractActiveUsers(String url, String currentUser, long now) {
        ArrayList<String> users = new ArrayList<String>();
        if (visitors.containsKey(url)) {
            Set<Map.Entry<String, Long>> visitorsOfUrl = visitors.get(url).entrySet();
            for (Map.Entry<String, Long> visitor : visitorsOfUrl) {
                if (visitor.getKey().equalsIgnoreCase(currentUser)) continue;
                if (now - visitor.getValue() < timeoutInMilliseconds + marginInMilliseconds) {
                    users.add(visitor.getKey());
                } else {
                    visitorsOfUrl.remove(visitor);
                }
            }
        }
        return users;
    }
}
