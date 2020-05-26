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
import org.jruby.rack.PoolingRackApplicationFactory;
import org.jruby.rack.RackApplication;
import org.jruby.rack.RackApplicationFactory;
import org.jruby.rack.RackInitializationException;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.util.Collections;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicBoolean;

import static com.thoughtworks.mingle.MingleProperties.DEFAULT_INIT_RUNTIMES_LIMIT;

public class MinglePoolingRackApplicationFactory extends PoolingRackApplicationFactory implements LoggedPool {
    /** borrower timeout is 30 sec */
    public static final float BORROWER_TIMEOUT = 30.0f;

    private static Logger logger = LoggerFactory.getLogger("com.thoughtworks.mingle.pool");
    private Map<Integer, String> borrowers = new ConcurrentHashMap<Integer, String>();
    private AtomicBoolean ready = new AtomicBoolean(false);

    public MinglePoolingRackApplicationFactory(RackApplicationFactory delegate) {
        super(delegate);
        configureSystemProperties();
    }

    public RackApplication borrowApplication(String borrower) throws Exception {
        if (logger.isDebugEnabled()) {
            logger.debug("Started borrowing a Runtime. " + borrower);
        }

        long start = System.currentTimeMillis();

        RackApplication rackApplication = this.getApplication();
        borrowers.put(rackApplication.hashCode(), borrower);

        logStatistics(borrower, start, getStatus());

        return rackApplication;
    }

    @Override
    public void fillInitialPool() throws RackInitializationException {
        super.fillInitialPool();
        logger.info("JRuby runtime pool initialized with effective max size: " + getMaximumSize());
        ready.set(true);
    }

    @Override
    public void finishedWithApplication(RackApplication app) {
        try {
            super.finishedWithApplication(app);
        } finally {
            borrowers.remove(app.hashCode());
            logger.debug("Finished borrowing a Runtime.");
        }
    }

    public Map<Integer, String> borrowers() {
        return Collections.unmodifiableMap(borrowers);
    }

    public PoolStatus getStatus() {
        int activeThreads = borrowers().size();
        int idleThreads = getMaximumSize() - activeThreads;
        return new PoolStatus(getMaximumSize(), getMaximumSize(), idleThreads, idleThreads);
    }

    @Override
    public boolean isReady() {
        return ready.get();
    }

    public static void setPropertyDefault(String property, Object defaultValue) {
        String currentValue = System.getProperty(property);
        if (null == currentValue || "".equals(currentValue)) {
            System.setProperty(property, String.valueOf(defaultValue));
        }
    }

    protected void configureSystemProperties() {
        setPropertyDefault("jruby.min.runtimes", Math.min(MingleProperties.jrubyMaxRuntimes(System.getProperties()), DEFAULT_INIT_RUNTIMES_LIMIT));
        setPropertyDefault("jruby.max.runtimes", MingleProperties.jrubyMaxRuntimes(System.getProperties()));
        setPropertyDefault("jruby.runtime.acquire.timeout", BORROWER_TIMEOUT);
    }

    private void logStatistics(String borrower, long start, PoolStatus status) {
        if (status.getIdleApplications() == 0 && status.getMaxApplications() > 1) {
            logger.info("Maximum thread limit: " + status.getMaxApplications() + " was hit trying to acquire [" + borrower + "]!");
            StringBuilder buf = new StringBuilder();
            buf.append("Current threadpool snapshot:\n");
            for (Integer borrowerId: borrowers.keySet()) {
                buf.append(String.valueOf(borrowerId) + ": " + borrowers.get(borrowerId) + "\n");
            }
            logger.info(buf.toString());
        }

        long split = System.currentTimeMillis() - start;
        if (split > 1000) {
            logger.info("Wait time for borrowing a Runtime exceeded " + split + " msecs. This time needs to be added to '" + borrower + "'.");
        } else if (logger.isDebugEnabled() && split > 10) {
            logger.debug("Wait time for borrowing a Runtime exceeded " + split + " msecs.");
        }
    }

}
