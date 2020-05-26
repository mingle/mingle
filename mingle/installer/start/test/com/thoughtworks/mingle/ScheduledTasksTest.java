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

import com.thoughtworks.mingle.util.MingleConfigUtils;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import java.io.File;
import java.util.ArrayList;
import java.util.List;
import java.util.Map;

import static org.junit.Assert.*;

public class ScheduledTasksTest {

    private SimpleTaskFactory factory;

    public static void clearMingleSystemProperties() {
        for (String prop : System.getProperties().stringPropertyNames()) {
            if (prop.startsWith("mingle.")) {
                System.out.println("Clearing Mingle system property: " + prop);
                System.clearProperty(prop);
            }
        }
    }

    @Before
    public void setUp() {
        clearMingleSystemProperties();
        System.setProperty(MingleProperties.CONFIG_DIR_KEY, "test" + File.separator + "data");
        factory = new SimpleTaskFactory();
        SimpleTask.started = 0;
    }

    @After
    public void tearDown() {
        clearMingleSystemProperties();
    }

    @Test
    public void readConfig() {
        ScheduledTasks tasks = new ScheduledTasks(MingleConfigUtils.configFile("periodical_tasks.yml"), factory);
        Map<String, Map<String, Object>> config = tasks.loadConfigFromYaml();
        assertNotNull(config);
        assertNotNull(config.get("daily_history_processing"));
    }

    @Test(expected = ConfigFileNotFoundException.class)
    public void shouldRaiseErrorWhenConfigFileDoesNotExist() {
        ScheduledTasks tasks = new ScheduledTasks(MingleConfigUtils.configFile("hello.yml"), factory);
        tasks.loadConfigFromYaml();
    }

    @Test
    public void shouldFallbackToWorkingConfigDirIfNoConfigFoundInConfigDir() {
        System.setProperty(MingleProperties.CONFIG_DIR_KEY, "tmp");
        ScheduledTasks tasks = new ScheduledTasks(MingleConfigUtils.configFile("periodical_tasks.yml"), factory);
        Map<String, Map<String, Object>> config = tasks.loadConfigFromYaml();
        assertNotNull(config);
    }

    @Test
    public void disableTasksBySystemProperty() {
        System.setProperty(MingleProperties.NO_BACKGROUND_JOB_KEY, "true");
        try {
            ScheduledTasks tasks = new ScheduledTasks(MingleConfigUtils.configFile("periodical_tasks.yml"), factory);
            assertEquals(0, tasks.launch());
        } finally {
            System.setProperty(MingleProperties.NO_BACKGROUND_JOB_KEY, "");
        }
    }

    @Test
    public void launchAndShutdownTasks() {
        ScheduledTasks tasks = new ScheduledTasks(MingleConfigUtils.configFile("periodical_tasks.yml"), factory);
        assertEquals(18, tasks.launch());
        assertEquals(18, SimpleTask.started);
        tasks.shutdown();
        assertEquals(0, SimpleTask.started);
    }

    @Test
    public void launchMultiTaskWorkersForSameTask() {
        ScheduledTasks tasks = new ScheduledTasks(MingleConfigUtils.configFile("periodical_tasks.yml"), factory);
        System.setProperty(ScheduledTasks.taskWorkerCountPropertyKey("daily_history_processing"), "2");
        try {
            assertEquals(19, tasks.launch());
        } finally {
            System.setProperty(ScheduledTasks.taskWorkerCountPropertyKey("daily_history_processing"), "");
        }
    }

    @Test
    public void ignoreWrongConfigForWorkerCount() {
        ScheduledTasks tasks = new ScheduledTasks(MingleConfigUtils.configFile("periodical_tasks.yml"), factory);
        System.setProperty(ScheduledTasks.taskWorkerCountPropertyKey("daily_history_processing"), "hello");
        try {
            assertEquals(18, tasks.launch());
        } finally {
            System.setProperty(ScheduledTasks.taskWorkerCountPropertyKey("daily_history_processing"), "");
        }
    }

    @Test
    public void noWorkerStartWhenWorkerCountIsLessThanOne() {
        ScheduledTasks tasks = new ScheduledTasks(MingleConfigUtils.configFile("periodical_tasks.yml"), factory);
        System.setProperty(ScheduledTasks.taskWorkerCountPropertyKey("daily_history_processing"), "0");
        try {
            assertEquals(17, tasks.launch());
        } finally {
            System.setProperty(ScheduledTasks.taskWorkerCountPropertyKey("daily_history_processing"), "");
        }

        tasks.shutdown();

        System.setProperty(ScheduledTasks.taskWorkerCountPropertyKey("daily_history_processing"), "-1");
        try {
            assertEquals(17, tasks.launch());
        } finally {
            System.setProperty(ScheduledTasks.taskWorkerCountPropertyKey("daily_history_processing"), "");
        }
    }

    @Test
    public void workerCountIsProvidedInTheConfig() {
        ScheduledTasks tasks = new ScheduledTasks(MingleConfigUtils.configFile("periodical_tasks_workers_count.yml"), factory);
        assertNull(System.getProperty(ScheduledTasks.taskWorkerCountPropertyKey("take_objective_snapshots")));
        assertNull(System.getProperty(ScheduledTasks.taskWorkerCountPropertyKey("daily_history_processing")));

        assertEquals(3, tasks.launch());
        List<String> names = extractTaskNames(tasks);
        assertTrue(names.contains("daily_history_processing-0"));
        assertTrue(names.contains("daily_history_processing-1"));
        assertTrue(names.contains("take_objective_snapshots-0"));
        tasks.shutdown();
    }

    @Test
    public void workerCountInSystemPropertyOverridesTheOneProvidedInTheConfig() {
        ScheduledTasks tasks = new ScheduledTasks(MingleConfigUtils.configFile("periodical_tasks_workers_count.yml"), factory);
        assertNull(System.getProperty(ScheduledTasks.taskWorkerCountPropertyKey("take_objective_snapshots")));
        System.setProperty(ScheduledTasks.taskWorkerCountPropertyKey("daily_history_processing"), "0");

        assertEquals(1, tasks.launch());
        List<String> names = extractTaskNames(tasks);
        assertTrue(names.contains("take_objective_snapshots-0"));
        tasks.shutdown();
    }

    @Test
    public void readSystemPropertiesTaskConfig() {
        System.setProperty("mingle.task.task_name.command", "RubyScript");
        System.setProperty("mingle.task.task_name.interval", "10");
        System.setProperty("mingle.task.task_name.minIdle", "1");
        System.setProperty("mingle.task.task_name.runOnce", "true");
        ScheduledTasks tasks = new ScheduledTasks(MingleConfigUtils.configFile("periodical_tasks_empty.yml"), factory);
        assertEquals(1, tasks.launch());
        assertEquals("task_name-0", tasks.getTasks().get(0).getName());
        assertEquals("RubyScript", tasks.getTasks().get(0).getConfig().getCommand());
        assertEquals((Integer) 10, tasks.getTasks().get(0).getConfig().getInterval());
        assertEquals((Integer) 1, tasks.getTasks().get(0).getConfig().getMinIdle());
        assertEquals(true, tasks.getTasks().get(0).getConfig().getRunOnce());
    }

    @Test
    public void runOneIsOptional() {
        System.setProperty("mingle.task.task_name.command", "RubyScript");
        System.setProperty("mingle.task.task_name.interval", "10");
        System.setProperty("mingle.task.task_name.minIdle", "1");
        ScheduledTasks tasks = new ScheduledTasks(MingleConfigUtils.configFile("periodical_tasks_empty.yml"), factory);
        assertEquals(1, tasks.launch());
        assertEquals("task_name-0", tasks.getTasks().get(0).getName());
        assertEquals("RubyScript", tasks.getTasks().get(0).getConfig().getCommand());
        assertEquals((Integer) 10, tasks.getTasks().get(0).getConfig().getInterval());
        assertEquals((Integer) 1, tasks.getTasks().get(0).getConfig().getMinIdle());
        assertEquals(false, tasks.getTasks().get(0).getConfig().getRunOnce());
    }

    @Test
    public void systemPropertiesOverridesYamlConfig() {
        System.setProperty("mingle.task.daily_history_processing.command", "RubyScript");
        System.setProperty("mingle.task.daily_history_processing.interval", "10");
        System.setProperty("mingle.task.daily_history_processing.minIdle", "1");
        System.setProperty("mingle.task.daily_history_processing.runOnce", "true");
        ScheduledTasks tasks = new ScheduledTasks(MingleConfigUtils.configFile("one_periodical_task.yml"), factory);
        assertEquals(1, tasks.launch());
        assertEquals("daily_history_processing-0", tasks.getTasks().get(0).getName());
        assertEquals("RubyScript", tasks.getTasks().get(0).getConfig().getCommand());
        assertEquals((Integer) 10, tasks.getTasks().get(0).getConfig().getInterval());
        assertEquals((Integer) 1, tasks.getTasks().get(0).getConfig().getMinIdle());
        assertEquals(true, tasks.getTasks().get(0).getConfig().getRunOnce());
    }

    @Test
    public void shouldThrowMeaningfullErrorWhenSystemPropertiesConfigIsInvalid() {
        System.setProperty("mingle.task.daily_history_processing", "true");
        ScheduledTasks tasks = new ScheduledTasks(MingleConfigUtils.configFile("periodical_tasks_empty.yml"), factory);
        try {
            tasks.launch();
            fail("should have given exception");
        } catch (IllegalStateException ex) {
            assertEquals("Invalid task config property name: mingle.task.daily_history_processing", ex.getMessage());
        }
    }

    private static List<String> extractTaskNames(ScheduledTasks scheduledTasks) {
        List<String> taskNames = new ArrayList<String>();

        for (Task t : scheduledTasks.getTasks()) {
            taskNames.add(t.getName());
        }

        return taskNames;
    }

    public static class SimpleTask implements Task {
        public TaskConfig config;
        public static int started;

        public SimpleTask(TaskConfig config) {
            this.config = config;
        }

        @Override
        public void start() {
            started++;
        }

        @Override
        public String getName() {
            return config.getName();
        }

        @Override
        public void destroy() {
            started--;
        }

        @Override
        public void disable() {
        }

        @Override
        public TaskConfig getConfig() {
            return config;
        }

        @Override
        public Status state() {
            return null;
        }

        @Override
        public void enable() {

        }
    }

    public static class SimpleTaskFactory implements ScheduledTasks.Factory {
        @Override
        public Task create(TaskConfig taskConfig) {
            return new SimpleTask(taskConfig);
        }
    }
}
