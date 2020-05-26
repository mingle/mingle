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
import org.elasticsearch.ElasticsearchException;
import org.elasticsearch.action.admin.cluster.health.ClusterHealthStatus;
import org.elasticsearch.client.Client;
import org.elasticsearch.common.settings.ImmutableSettings;
import org.elasticsearch.node.Node;
import org.elasticsearch.node.NodeBuilder;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.Map;

public class ElasticSearch implements Service {
    private Logger logger = LoggerFactory.getLogger("Elastic Search");

    private final String CONFIG_FILE_NAME = "elasticsearch.yml";

    private static Node node;
    private static boolean ready = false, exists = false;

    public static Node currentNode() {
        return node;
    }

    @Override
    public void start() {
        exists = true;

        try {
            File configFile = findConfig();
            logger.info("Initializing ElasticSearch Service with configuration from file: " + configFile.getCanonicalPath());
            initializeNode(configFile);
            logger.info("Starting ElasticSearch Service");
            startServer();
            setSearchLocation();
        } catch (IOException e) {
            shutdownOnError(e);
        } catch (ElasticsearchException e) {
            shutdownOnError(e);
        }
    }

    @Override
    public void stop() {
        logger.info("Elastic Search server is stopping.");
        node.close();
        ready = exists = false;
    }

    public void setSearchLocation() {
        Map<String, String> config = getConfig();
        System.setProperty(MingleProperties.MINGLE_SEARCH_PORT, config.get("http.port"));
        String host = config.get("network.host");
        System.setProperty(MingleProperties.MINGLE_SEARCH_HOST, host == null ? "127.0.0.1" : host);
    }

    public ImmutableSettings.Builder createBuilderFromConfiguration(File file) throws FileNotFoundException {
        return ImmutableSettings.settingsBuilder()
                .loadFromStream(file.getName(), new FileInputStream(file));
    }

    public File findConfig() {
        File configFile = MingleConfigUtils.configFile(CONFIG_FILE_NAME);
        logger.info("Using elastic search config at: " + configFile);
        return configFile;
    }

    protected void checkServerStatus() {
        ClusterHealthStatus status = getHealthStatus();

        // Check the current status of the ES cluster.
        if (ClusterHealthStatus.RED.equals(status)) {
            logger.info("ES cluster status is " + status + ". Waiting for ES recovery.");

            // Waits at most 30 seconds to make sure the cluster health is at least yellow.
            getClient().admin().cluster().prepareHealth()
                    .setWaitForYellowStatus()
                    .setTimeout("30s")
                    .execute().actionGet();
        }

        // Check the cluster health for a final time.
        status = getHealthStatus();
        logger.info("ES cluster status is " + status);

        // If we are still in red status, then we cannot proceed.
        if (ClusterHealthStatus.RED.equals(status)) {
            throw new RuntimeException("ES cluster health status is RED. Server is not able to start.");
        }

        ready = true;
    }

    protected ClusterHealthStatus getHealthStatus() {
        return getClient().admin().cluster().prepareHealth().execute().actionGet().getStatus();
    }

    protected static String getValue(Map<String, String> map, String key) {
        if (key.startsWith("cloud.aws.secret")) return "<HIDDEN>";
        return map.get(key);
    }

    private void shutdownOnError(Throwable e) {
        logger.error("Shutting down Mingle due to error starting ElasticSearch Service:", e);
        new Thread(new Runnable() {
            @Override
            public void run() {
                System.exit(1);
            }
        }).start();
    }

    private Client getClient() {
        return node.client();
    }

    private void startServer() {
        displayConfiguration();
        node.start();

        checkServerStatus();

        logger.info("Elastic Search server is started.");
    }

    private void displayConfiguration() {
        logger.info("ElasticSearch is configured with the following settings:");
        final Map<String, String> map = getConfig();
        final List<String> keys = new ArrayList<String>(map.keySet());
        Collections.sort(keys);
        for (String key : keys) {
            logger.info("    " + key + " : " + getValue(map, key));
        }
    }

    private Map<String, String> getConfig() {
        return node.settings().getAsMap();
    }

    public void initializeNode(File configFile) throws IOException {
        if (null != node) {
            logger.warn("ElasticSearch node previously initialized - closing and recreating.");
            node.close();
        }

        ImmutableSettings.Builder builder = createBuilderFromConfiguration(configFile);
        boolean skipLoadingConfigFromClasspath = false;
        node = new NodeBuilder().loadConfigSettings(skipLoadingConfigFromClasspath).settings(builder).build();
    }

    public static boolean isEnabled() {
        return exists;
    }

    public static boolean isReady() {
        return exists && ready;
    }
}
