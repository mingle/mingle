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

import com.thoughtworks.mingle.rack.LoggedPool;
import com.thoughtworks.mingle.rack.MingleApplication;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.Serializable;
import java.util.concurrent.ThreadLocalRandom;

public class PeriodicalTask implements Serializable, Runnable, Task {
    private Status currentState = Status.IDLE;
    private boolean hasAlreadyRun = false;

    public static class Factory implements ScheduledTasks.Factory {

        private LoggedPool runtimePool;

        public Factory(LoggedPool runtimePool) {
            this.runtimePool = runtimePool;
        }

        @Override
        public Task create(TaskConfig config) {
            return new PeriodicalTask(config, runtimePool);
        }
    }

    private static Logger logger = LoggerFactory.getLogger("Task");

    private TaskConfig config;

    private Thread thread = null;

    private int interval = 60;

    private int minIdle = 0;
    private LoggedPool pool;
    private Boolean runOnce;
    private String name;
    private String command;
    private static final int TWO_MINUTES_IN_MILLIS = 1000 * 60 * 2;

    public String getName() {
        return name;
    }

    public PeriodicalTask(TaskConfig config, LoggedPool pool) {
        this.config = config;
        this.name = config.getName();
        this.command = config.getCommand();
        this.interval = parseInterval(config.getInterval(), config.getIntervalSystemProperty());
        this.minIdle = parseMinIdle(config.getName(), config.getMinIdle(), pool);
        this.pool = pool;
        this.runOnce = config.getRunOnce();
    }

    public TaskConfig getConfig() {
        return config;
    }

    public void start() {
        thread = new Thread(this);
        thread.setName(this.name + "[Thread-" + thread.getId() + "]");
        thread.start();
    }

    private void shutdownOnError(Throwable e, String message) {
        logError(message, e);
        new Thread(new Runnable() {
            @Override
            public void run() {
                System.exit(1);
            }
        }).start();
    }

    private void runOnce() throws Exception {
        MingleApplication mingleApplication = null;
        try {
            long heapStart = -1;
            long startTime = -1;
            boolean captureStats = logger.isDebugEnabled();

            if (captureStats) {
                heapStart = Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory();
                startTime = System.currentTimeMillis();
            }

            mingleApplication = (MingleApplication) pool.borrowApplication("Task: " + thread.getName());
            mingleApplication.evalScriptlet(backgroundJobScript());
            pool.finishedWithApplication(mingleApplication);

            hasAlreadyRun = true;

            if (captureStats) {
                long heapDiff = ((Runtime.getRuntime().totalMemory() - Runtime.getRuntime().freeMemory()) - heapStart) / 1000000;
                long duration = System.currentTimeMillis() - startTime;
                if (duration > 25 || Math.abs(heapDiff) > 5) {
                    logDebug("job complete (duration=" + duration + " msecs, heap diff=" + heapDiff + " MB)");
                }
            }
        } catch (Exception e) {
            if (state().equals(Status.HALTING)) {
                throw new InterruptedException("This task should be stopped.");
            }
            logError("Could not execute: " + command, e);
            pool.finishedWithApplication(mingleApplication);
            logInfo(command + " returning JRuby runtime access to pool and will restart this job in 2 minutes.");
            try {
                Thread.sleep(TWO_MINUTES_IN_MILLIS);
            } catch (InterruptedException ex) {
                // can't do much here ...
            }
        }
    }

    public void destroy() {
        disable();
        thread.interrupt();
        try {
            thread.join(1000 * 2); // wait for 2 sec for thread stop
            logInfo("stopped.");
        } catch (InterruptedException e) {
            logError("Problem stopping");
        }
    }

    protected String backgroundJobScript() {
        return "BackgroundJob.new(lambda { " + command + " }, '" + name + "').run_once";
    }

    private boolean isPoolIdleEnoughToRun() {
        return pool.getStatus().getIdleApplications() >= minIdle;
    }

    @Override
    public void run() {
        logInfo(" initialized to only run when " + String.valueOf(minIdle) + " threads or more can access jruby runtime, interval: " + String.valueOf(this.interval));
        try {
            int jitter = ThreadLocalRandom.current().nextInt(500, 16000);
            logInfo("   " + name + " => jitter: " + jitter);
            Thread.sleep(jitter);
        } catch (InterruptedException e) {
            // ignore
        }
        try {
            while (!thread.isInterrupted()) {
                if (isEnabled() && isPoolIdleEnoughToRun()) {
                    markAs(Status.RUNNING);
                    runOnce();
                    if (state().equals(Status.RUNNING)) {
                        markAs(Status.IDLE);
                    }
                    if (shouldOnlyRunOnce()) {
                        logInfo("Job has run once and now stopping");
                        disable();
                    }
                    if (state().equals(Status.HALTING)) {
                        markAs(Status.DISABLED);
                    }
                } else {
                    if (!isEnabled()) {
                        logDebug("Skipping run because " + minIdle + " idle threads not available");
                    }
                }
                Thread.sleep(this.interval * 1000); // wait for interval
            }
        } catch (InterruptedException e) {
            // break out of loop
        } catch (Exception e) {
            logError("Could not start " + this.command, e);
        } catch (Throwable t) {
            String message = "Error caught while running " + this.command + ". We're sorry but Mingle found a problem it couldn't fix. Please contact your Mingle administrator to resolve this issue.";
            PeriodicalTask.this.shutdownOnError(t, message);
        }
        logInfo("Job has completed its run");
    }

    private boolean isEnabled() {
        return state().compareTo(Status.RUNNING) <= 0;
    }

    private boolean shouldOnlyRunOnce() {
        return runOnce != null && runOnce;
    }

    public void disable() {
        switch (state()) {
            case RUNNING:
                markAs(Status.HALTING);
                break;
            case IDLE:
                markAs(Status.DISABLED);
                break;
            default:
                break;
        }

        logInfo("Disabled: " + getName());
    }

    protected synchronized void markAs(Status state) {
        logDebug("task: " + getName() + ", state: " + state);
        currentState = state;
    }

    public synchronized Status state() {
        return currentState;
    }

    @Override
    public void enable() {
        if (shouldOnlyRunOnce() && hasRunAtLeastOnce()) {
            logInfo("Not enabling " + getName() + " because it is configured to only run once and has already run.");
            return;
        }

        switch (state()) {
            case HALTING:
                markAs(Status.RUNNING);
                break;
            case DISABLED:
                markAs(Status.IDLE);
                break;
            default:
                break;
        }

        logInfo("Enabled: " + getName());
    }

    private boolean hasRunAtLeastOnce() {
        return hasAlreadyRun;
    }

    private int parseMinIdle(String name, Integer minIdleFromParam, LoggedPool pool) {
        int minIdleFromPool = pool.getStatus().getMinApplications();
        int minIdle;
        if (minIdleFromParam != null) {
            try {
                if (minIdleFromParam == 0) {
                    logInfo("0 is not a valid value for " + name + " job minIdle");
                }
                minIdle = Math.max(minIdleFromParam, 1);
                if (minIdleFromParam > minIdleFromPool) {
                    logInfo(String.valueOf(minIdleFromParam) + " is not  valid value for minIdle for " + name + " job because it cannot be greater than jruby.max.access.threads");
                }
                minIdle = Math.min(minIdleFromPool, minIdle);
            } catch (Exception e) {
                minIdle = minIdleFromPool;
            }
        } else {
            minIdle = minIdleFromPool;
        }
        return minIdle;
    }

    private int parseInterval(Integer intervalSeconds, String intervalSystemProperty) {
        if (intervalSystemProperty != null && System.getProperty(intervalSystemProperty) != null) {
            intervalSeconds = Integer.parseInt(System.getProperty(intervalSystemProperty));
        }

        if (intervalSeconds != null) {
            return intervalSeconds;
        }
        return 100;
    }

    private static void logError(String msg, Throwable t) {
        logger.error(msg, t);
    }

    private static void logError(String msg) {
        logger.error(msg);
    }

    private static void logInfo(String msg) {
        logger.info(msg);
    }

    private static void logDebug(String msg) {
        logger.debug(msg);
    }

}
