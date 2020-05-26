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

package com.thoughtworks.mingle.bootstrap;

/**
 * Bootstrap states. The order should be preserved in order to support
 * broad comparisons (e.g. currentState >= DATABASE_CONFIGURED).
 */
public enum BootstrapState {
    BOOTSTRAP_INITIATED,

    INITIALIZING,
    INITIALIZED,

    // Mingle Rails code is loaded

    DATABASE_CONFIGURATION_REQUIRED,
    DATABASE_CONFIGURED,

    UNSUPPORTED_DATABASE,
    DATABASE_SUPPORTED,

    SCHEMA_VERSION_INCOMPATIBLE_WITH_INSTALLER,
    SCHEMA_VERSION_COMPATIBLE_WITH_INSTALLER,

    MIGRATION_REQUIRED,
    MIGRATING_DATABASE,
    MIGRATION_ERROR,
    SCHEMA_UP_TO_DATE,

    // Database ready

    SITE_URL_NOT_CONFIGURED,
    SITE_URL_CONFIGURED,

    SMTP_NOT_CONFIGURED,
    SMTP_CONFIGURED,

    EULA_NOT_ACCEPTED,
    EULA_ACCEPTED,

    ADMIN_USER_MISSING,
    ADMIN_USER_EXISTS,

    WAITING_FOR_SEARCH,
    SEARCH_AVAILABLE,

    BOOTSTRAP_COMPLETED,

    // Can reliable serve requests, setup is complete

    LICENSE_REQUIRED,
    LICENSED_AND_READY,

    // Can serve all content that requires a license (nearly everything useful)

    UNEXPECTED_FAILURE // fatal
}
