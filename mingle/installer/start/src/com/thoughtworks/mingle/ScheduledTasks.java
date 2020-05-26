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

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.yaml.snakeyaml.Yaml;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

public class ScheduledTasks {
    public interface Factory {
        Task create(TaskConfig taskConfig);
    }

    private static Logger logger = LoggerFactory.getLogger("Periodical ScheduledTasks");

    public static String taskWorkerCountPropertyKey(String name) {
        return "mingle." + name + ".workerCount";
    }

    public List<Task> getTasks() {
        return tasks;
    }

    private List<Task> tasks = new ArrayList<Task>();
    private File configFile;
    private Factory factory;
    private boolean enabled;

    public boolean isEnabled() {
        return enabled;
    }

    public void setEnabled(boolean enabled) {
        this.enabled = enabled;
    }

    public ScheduledTasks(File configFile, Factory factory) {
        this.configFile = configFile;
        this.factory = factory;
    }

    public int launch() {
        if (MingleProperties.isNoBackgroundJob()) {
            logger.info("No background job launched due to mingle property " + MingleProperties.NO_BACKGROUND_JOB_KEY + " is set to true");
            return 0;
        }
        Map<String, Map<String, Object>> config = loadConfigFromYaml();
        if (config == null) {
            config = new HashMap<String, Map<String, Object>>();
        }
        loadConfigFromSystemProperties(config);
        addTasks(config);

        setEnabled(true);
        return tasks.size();
    }

    private void loadConfigFromSystemProperties(Map<String, Map<String, Object>> config) {
        for (String name : System.getProperties().stringPropertyNames()) {
            if (!name.startsWith("mingle.task.")) {
                continue;
            }
            String[] nameParts = name.split("\\.");
            if (nameParts.length != 4) {
                throw new IllegalStateException("Invalid task config property name: " + name);
            }
            String taskName = nameParts[2];
            String taskProperty = nameParts[3];
            if (!config.keySet().contains(taskName)) {
                config.put(taskName, new HashMap<String, Object>());
            }

            Map<String, Object> taskConfig = config.get(taskName);
            taskConfig.put(taskProperty, System.getProperty(name));
        }
    }

    private void addTasks(Map<String, Map<String, Object>> config) {
        int k = 0;
        for (String name : config.keySet()) {
            Map<String, Object> settings = config.get(name);
            int size = lookupTaskSize(name, settings);
            if (size == 0) {
                logger.info("no worker started for " + name);
                continue;
            }
            for (int i = 0; i < size; i++) {
                Task task = factory.create(new TaskConfig(name + "-" + i, settings));
                System.out.println("adding task " + k + " : " + task.getName());
                k++;
                task.start();
                tasks.add(task);
            }
        }
    }

    private int lookupTaskSize(String name, Map<String, Object> config) {
        String property = taskWorkerCountPropertyKey(name);
        String size = System.getProperty(property);

        if (size != null && !"".equals(size)) {
            try {
                return Integer.parseInt(size);
            } catch (NumberFormatException e) {
                logger.error("Ignoring incorrect system property '" + property + "=" + size +
                        "' for task for task [" + name + "], defaulting to 1");
            }
        } else {
            Integer worker_count = null;
            try {
                worker_count = (Integer) config.get("worker_count");
                if (worker_count != null && worker_count > -1) {
                    return worker_count;
                }
            } catch (ClassCastException e) {
                logger.error("Ignoring incorrect worker_count configuration for task [" + name + "], defaulting to 1");
            }

        }

        return 1;
    }

    public void shutdown() {
        for (Task task : tasks) {
            task.destroy();
        }
        tasks.clear();
    }

    public void disableAll() {
        for (Task task : tasks) {
            task.disable();
        }
        setEnabled(false);
    }

    public void enableAll() {
        for (Task task: tasks) {
            task.enable();
        }
        setEnabled(true);
    }

    public Map<String, Map<String, Object>> loadConfigFromYaml() {
        Yaml yaml = new Yaml();
        logger.info("loading tasks configuration from " + configFile.getAbsolutePath());
        try {
            return (Map) yaml.load(new FileInputStream(configFile));
        } catch (FileNotFoundException e) {
            throw new ConfigFileNotFoundException("Could not read task config file: " + configFile.getAbsolutePath());
        }
    }
}
