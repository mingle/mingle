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

import com.google.gson.GsonBuilder;
import com.thoughtworks.mingle.bootstrap.utils.BootstrapChecks;
import com.thoughtworks.mingle.rack.LoggedPool;
import com.thoughtworks.mingle.security.TokenAuthFilter;
import com.thoughtworks.mingle.util.MingleConfigUtils;

import javax.servlet.ServletConfig;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.File;
import java.io.IOException;
import java.util.HashMap;

public class MinglePeriodicalTaskServlet extends HttpServlet {

    private static final String ENABLE_ACTION = "enable";
    private static final String DISABLE_ACTION = "disable";

    private ScheduledTasks tasks;
    private BootstrapChecks checks;
    private static String ENCODING = "UTF-8";
    private RailsPathHelper helper;


    public void init(final ServletConfig servletConfig) throws ServletException {
        super.init(servletConfig);
        helper = new RailsPathHelper(getServletContext());

        checks = new BootstrapChecks(getServletContext());
        String configFileName = System.getProperty("mingle.periodicalTaskConfigFile", servletConfig.getInitParameter("tasks.config"));
        File config = MingleConfigUtils.configFile(configFileName);
        tasks = new ScheduledTasks(config, new PeriodicalTask.Factory(getRuntimePool()));
        Thread thread = new Thread(new Runnable() {
            @Override
            public void run() {
                log("Wait until mingle is ready for running background jobs");
                waitUntilMingleInstalled();
                log("Launch periodical tasks");
                tasks.launch();
            }
        });
        thread.start();
    }

    private void waitUntilMingleInstalled() {
        while (true) {
            if (checks.isMingleReady()) {
                return;
            }
            try {
                Thread.sleep(1000);
            } catch (InterruptedException e) {
                // ignore
            }
        }
    }

    public void destroy() {
        if (tasks != null) {
            tasks.shutdown();
        }
    }


    private LoggedPool getRuntimePool() {
        try {
            return new PoolServletStore(this.getServletContext()).getInitializedRuntimePool();
        } catch (PoolWaitingTimeoutException e) {
            throw new RuntimeException(e);
        }
    }

    @Override
    protected void doGet(HttpServletRequest req, HttpServletResponse response) throws ServletException, IOException {
        response.setContentType("text/html");
        response.setCharacterEncoding(ENCODING);

        HashMap<String, String> status = new HashMap<String, String>();

        for (Task task : tasks.getTasks()) {
            status.put(task.getName(), String.valueOf(task.state()));
        }

        String json = new GsonBuilder().setPrettyPrinting().create().toJson(status);
        SimpleTemplateBinding binding = SimpleTemplateBinding.getInstance();

        String form = "";
        if ((Boolean) req.getAttribute(TokenAuthFilter.AUTHENTICATED_ATTR)) {
            binding.bind("action", tasks.isEnabled() ? DISABLE_ACTION : ENABLE_ACTION);
            form = binding.tokenize(helper.publicRealPath("background/_actions.html")).render();
        }
        binding.bind("form", form);
        binding.bind("status", json);

        response.getWriter().write(binding.tokenize(helper.publicRealPath("background/status.html")).render());
    }

    @Override
    protected void doPost(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        String action = req.getParameter("action");
        if (ENABLE_ACTION.equals(action)) {
            getServletContext().log("Enabling tasks");
            tasks.enableAll();
        } else if (DISABLE_ACTION.equals(action)) {
            getServletContext().log("Disabling tasks");
            tasks.disableAll();
        } else {
            resp.setStatus(HttpServletResponse.SC_BAD_REQUEST);
            resp.getWriter().write("Action not recognized: " + action);
            return;
        }

        resp.setHeader("Location", "/background_status");
        resp.setStatus(HttpServletResponse.SC_MOVED_TEMPORARILY);
    }
}
