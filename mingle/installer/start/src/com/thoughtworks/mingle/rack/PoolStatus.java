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

/** Simple POJO representing statistical information from the application pool */
public class PoolStatus {
    private int minApps;
    private int maxApps;
    private int idleApps;
    private int activeApps;
    private int poolSize;

    public PoolStatus(Integer minApps, Integer maxApps, int idleApps, int availablePermits) {
        this.minApps = minApps == null ? 0 : minApps;
        this.maxApps = maxApps == null ? 0 : maxApps;
        this.idleApps = idleApps;
        this.activeApps = this.maxApps - availablePermits;
        this.poolSize = this.idleApps + this.activeApps;
    }

    public int getMaxApplications() {
        return this.maxApps;
    }

    public int getMinApplications() {
        return this.minApps;
    }

    public int getActiveApplications() {
        return this.activeApps;
    }

    public int getIdleApplications() {
        return this.idleApps;
    }

    public int getPoolSize() {
        return this.poolSize;
    }
}
