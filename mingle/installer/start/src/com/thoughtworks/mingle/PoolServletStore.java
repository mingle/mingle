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
import com.thoughtworks.mingle.rack.MingleRackServletContextListener;

import javax.servlet.ServletContext;

public class PoolServletStore {
    private ServletContext context;

    public PoolServletStore(ServletContext context) {
        this.context = context;
    }

    public LoggedPool getInitializedRuntimePool() throws PoolWaitingTimeoutException {
        LoggedPool runtimePool = MingleRackServletContextListener.getRuntimeObjectPool(context);
        if (runtimePool == null) {
            throw new PoolWaitingTimeoutException("No runtime pool is available, please check RailsContextListener");
        }
        return ready(runtimePool);
    }

    private LoggedPool ready(LoggedPool runtimePool) throws PoolWaitingTimeoutException {
        int waitCount = 0;
        while (!runtimePool.isReady()) {
            try {
                Thread.sleep(100);
            } catch (InterruptedException e) {
                throw new PoolWaitingTimeoutException("interrupted when waiting for runtime pool ready", e);
            }
            waitCount += 1;
            if (waitCount > (10 * 60 * 15)) {
                throw new PoolWaitingTimeoutException("Timeout when waiting for runtime pool ready");
            }
        }
        return runtimePool;
    }

}
