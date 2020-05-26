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


import com.thoughtworks.mingle.services.ElasticSearch;
import org.elasticsearch.common.settings.ImmutableSettings;
import org.junit.After;
import org.junit.Before;
import org.junit.Test;

import java.io.File;
import java.io.FileWriter;

import static org.junit.Assert.*;

public class ElasticSearchTest {

    private File testDir;
    private File configFile;

    private ElasticSearch elasticSearch;

    @Before
    public void setup() throws Exception {
        testDir = new File("tmp", "test_data_dir");
        configFile = new File(testDir, "elasticsearch.yml");

        new File(testDir, "elastic_search").mkdirs();
        configFileWithContents("port: 3000\ncluster.name: mingle_test\nhttp.port: 9288");

        System.setProperty(MingleProperties.CONFIG_DIR_KEY, testDir.getPath());
        System.setProperty(MingleProperties.LOG_DIR_KEY, testDir.getPath());
        System.setProperty(MingleProperties.DATA_DIR_KEY, testDir.getPath());
        elasticSearch = new ElasticSearch();
    }

    @After
    public void teardown() {
        testDir.delete();
        System.clearProperty(MingleProperties.CONFIG_DIR_KEY);
        System.clearProperty(MingleProperties.LOG_DIR_KEY);
        System.clearProperty(MingleProperties.DATA_DIR_KEY);
    }

    @Test
    public void canReadConfigurationFromFile() throws Exception {
        configFileWithContents("port: 3000\ncluster.name: mingle_test\nhttp.port: 9288");

        ImmutableSettings.Builder builder = elasticSearch.createBuilderFromConfiguration(configFile);

        assertEquals("3000", builder.get("port"));
        assertEquals("mingle_test", builder.get("cluster.name"));
        assertNull(builder.get("does.not.exist"));
    }

    @Test
    public void findsConfigInConfigDirectory() throws Exception {
        File config = elasticSearch.findConfig();
        assertEquals(configFile.getPath(), config.getPath());
    }

    @Test
    public void findsConfigInInstallDirectorWhenNoConfigDirSpecified() throws Exception {
        System.setProperty(MingleProperties.CONFIG_DIR_KEY, "./config_dir_does_not_exist");
        elasticSearch = new ElasticSearch();
        File config = elasticSearch.findConfig();
        assertEquals(new File("config", "elasticsearch.yml").getCanonicalPath(), config.getCanonicalPath());
    }

    @Test
    public void setsSearchPortToHttpPortInESConfig() throws Exception {
        configFileWithContents("port: 3000\ncluster.name: mingle_test\nhttp.port: 9288");

        elasticSearch.initializeNode(configFile);
        elasticSearch.setSearchLocation();

        assertEquals("9288", System.getProperty(MingleProperties.MINGLE_SEARCH_PORT));
    }

    @Test
    public void setsSearchHostToLocalhostIfThereIsNoNetworkHostInESConfig() throws Exception {
        configFileWithContents("port: 3000\ncluster.name: mingle_test\nhttp.port: 9288");

        elasticSearch.initializeNode(configFile);
        elasticSearch.setSearchLocation();

        assertEquals("127.0.0.1", System.getProperty(MingleProperties.MINGLE_SEARCH_HOST));
    }

    @Test
    public void shouldSetSearchHostDefaultToESNetworkHost() throws Exception {
        configFileWithContents("port: 3000\ncluster.name: mingle_test\nhttp.port: 9288\nnetwork.host: sfstdmngpair.thoughtworks.com");
        elasticSearch.initializeNode(configFile);
        elasticSearch.setSearchLocation();

        assertEquals("sfstdmngpair.thoughtworks.com", System.getProperty(MingleProperties.MINGLE_SEARCH_HOST));
    }

    @Test
    public void shouldReportServiceIsDisabledWhenNotInUse() {
        assertFalse(ElasticSearch.isEnabled());
    }

    private void configFileWithContents(String contents) throws Exception {
        FileWriter writer = new FileWriter(configFile);
        writer.write(contents);
        writer.close();
    }
}
