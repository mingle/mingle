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

import com.thoughtworks.mingle.bootstrap.BootstrapState;
import com.thoughtworks.mingle.bootstrap.CurrentBootstrapState;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.servlet.ServletContext;

public class MigrationRunner extends RailsConsoleEvaluator {
    private static final String BORROWER_NAME = "MigrationRunner";

    private final Logger logger = LoggerFactory.getLogger(MigrationRunner.class);

    public MigrationRunner(ServletContext context) {
        super(context);
    }

    public void start() {
        new Thread() {
            @Override
            public void run() {
                try {
                    setState(BootstrapState.MIGRATING_DATABASE);
                    doMigration();
                } catch (Exception e) {
                    logger.error("Error during migration", e);
                    setState(BootstrapState.MIGRATION_ERROR);
                }
            }
        }.start();
    }

    private void doMigration() throws Exception {
        evaluate("Database.migrate");
    }

    private void setState(BootstrapState state) {
        CurrentBootstrapState.set(state);
    }

    @Override
    public String getBorrowerName() {
        return BORROWER_NAME;
    }
}
