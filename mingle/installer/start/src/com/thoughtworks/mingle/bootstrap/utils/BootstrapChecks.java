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

package com.thoughtworks.mingle.bootstrap.utils;

import com.thoughtworks.mingle.MingleProperties;
import com.thoughtworks.mingle.util.MingleConfigUtils;
import com.thoughtworks.mingle.bootstrap.BootstrapState;
import com.thoughtworks.mingle.bootstrap.CurrentBootstrapState;
import org.yaml.snakeyaml.Yaml;

import javax.servlet.ServletContext;
import java.io.File;
import java.io.FileInputStream;
import java.io.FileNotFoundException;
import java.util.Map;

public class BootstrapChecks extends RailsConsoleEvaluator {
    private static final String BORROWER_NAME = "BootstrapChecks";

    public BootstrapChecks(ServletContext context) {
        super(context);
    }

    public boolean isPendingUpgrade() throws Exception {
        return isSchemaDefined() && !isSchemaCurrent();
    }

    public boolean isSchemaDefined() throws Exception {
        return evaluate("ActiveRecord::Migration.table_exists? ActiveRecord::Migrator.schema_migrations_table_name").isTrue();
    }

    public boolean adminUserCreated() throws Exception {
        return !evaluate("User.no_users?").isTrue();
    }

    public boolean isDatabaseConfigured() throws Exception {
        return !evaluate("Database.need_config?").isTrue();
    }

    public boolean isEulaAccepted() throws Exception {
        return evaluate("License.eula_accepted?").isTrue();
    }

    public boolean isDatabaseSupported() throws Exception {
        return !evaluate("Database.is_mysql?").isTrue();
    }

    public boolean isSiteUrlConfigured() {
        return System.getProperty(MingleProperties.MINGLE_SITE_URL) != null;
    }

    public boolean isAuthConfigured() {
        File authConfig = new File(MingleConfigUtils.currentConfigDir(), "auth_config.yml");
        return authConfig.exists() && loadYamlFile(authConfig).containsKey("authentication");
    }

    public boolean isSmtpConfigured() {
        File smtpConfig = new File(MingleConfigUtils.currentConfigDir(), "smtp_config.yml");
        return smtpConfig.exists() && loadYamlFile(smtpConfig).containsKey("smtp_settings");
    }

    public boolean isSchemaCurrent() throws Exception {
        return !evaluate("Database.need_migration? || Install::PluginMigrations.new.need_migration?").isTrue();
    }

    public boolean isCurrentlyMigrating() {
        return BootstrapState.MIGRATING_DATABASE == currentState();
    }

    public boolean schemaCompatibleWithInstaller() throws Exception {
        return !evaluate("Database.newer_than_installer?").isTrue();
    }

    public boolean isRailsInitialized() throws Exception {
        return !evaluate("defined?(Rails) && Rails.booted?").isNil();
    }

    private BootstrapState currentState() {
        return CurrentBootstrapState.get();
    }

    public boolean isMingleReady() {
        return CurrentBootstrapState.hasReached(BootstrapState.BOOTSTRAP_COMPLETED)
                && CurrentBootstrapState.hasNotReached(BootstrapState.UNEXPECTED_FAILURE);
    }

    public boolean isMingleLicensed() throws Exception {
        return evaluate("Rails.env.test? || CurrentLicense.refresh_status.valid?").isTrue();
    }

    @Override
    public String getBorrowerName() {
        return BORROWER_NAME;
    }

    public Map loadYamlFile(File file) {
        Yaml yaml = new Yaml();
        try {
            return (Map) yaml.load(new FileInputStream(file));
        } catch (FileNotFoundException e) {
            context.log("Failed to load non-existent YAML file: " + file.getPath());
            return null;
        }
    }
}
