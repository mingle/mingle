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
import com.thoughtworks.mingle.rack.PoolStatus;
import com.thoughtworks.mingle.services.ElasticSearch;
import com.thoughtworks.mingle.ManifestUtil;
import org.apache.activemq.broker.BrokerRegistry;
import org.apache.activemq.broker.BrokerService;
import org.apache.activemq.broker.region.Destination;
import org.apache.activemq.broker.region.DestinationStatistics;
import org.apache.activemq.command.ActiveMQDestination;
import org.apache.activemq.usage.SystemUsage;
import org.apache.activemq.usage.Usage;
import org.elasticsearch.common.collect.ImmutableMap;
import org.elasticsearch.node.Node;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import javax.servlet.ServletConfig;
import javax.servlet.ServletContext;
import javax.servlet.ServletException;
import javax.servlet.ServletOutputStream;
import javax.servlet.http.HttpServlet;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import java.io.FileNotFoundException;
import java.io.IOException;
import java.lang.management.ManagementFactory;
import java.lang.management.MemoryMXBean;
import java.lang.management.MemoryUsage;
import java.lang.management.RuntimeMXBean;
import java.net.InetSocketAddress;
import java.net.Socket;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;

public class RuntimeStatusServlet extends HttpServlet {

    private static final Map<String, String> JAVA_PROPERTIES_TO_DISPLAY_NAMES = new LinkedHashMap<String, String>();

    static {
        JAVA_PROPERTIES_TO_DISPLAY_NAMES.put("java.vm.name", "JRE Name");
        JAVA_PROPERTIES_TO_DISPLAY_NAMES.put("java.runtime.version", "JRE Version");
        JAVA_PROPERTIES_TO_DISPLAY_NAMES.put("os.name", "OS");
        JAVA_PROPERTIES_TO_DISPLAY_NAMES.put("os.arch", "Processor Type");
        JAVA_PROPERTIES_TO_DISPLAY_NAMES.put("sun.arch.data.model", "Processor Bit");
    }

    private JdbcConnection connection;
    private ServletContext servletContext;


    private static Logger logger = LoggerFactory.getLogger("com.thoughtworks.mingle.RuntimeStatusServlet");
    private boolean removePublicStatusPage;

    public void init(ServletConfig servletConfig) throws ServletException {
        super.init(servletConfig);
        String config = System.getProperty("mingle.statusPage");
        removePublicStatusPage = "false".equalsIgnoreCase(config);
        if (config != null) {
            logger.info("mingle.statusPage is configured: " + config);
        }
        if (removePublicStatusPage) {
            return;
        }

        this.servletContext = servletConfig.getServletContext();
        this.connection = new JdbcConnection(new DatabaseConfiguration("production"));
    }

    protected void doGet(HttpServletRequest req, HttpServletResponse resp) throws ServletException, IOException {
        healthCheck();
        if (removePublicStatusPage) {
            return;
        }
        if (Boolean.getBoolean("mingle.gc.allow") && Boolean.parseBoolean(req.getParameter("gc"))) {
            System.gc();
        }

        ServletOutputStream outputStream = resp.getOutputStream();
        resp.setContentType("text/html");

        renderContent(outputStream);

        outputStream.flush();
    }

    private void healthCheck() throws ServletException {
        new RubyExpression(getServletContext(), "HealthCheck.run").evaluateWithRuntimeException("HealthCheck");
    }

    private void renderContent(ServletOutputStream outputStream) throws IOException, ServletException {
        renderOpening(outputStream);
        renderTimestamp(outputStream);
        renderEnvironmentInfo(outputStream);
        renderVersionInfo(outputStream);
        renderPoolReport(outputStream);
        renderMemoryReport(outputStream);
        renderElasticSearchStatus(outputStream);
        renderActiveMQReport(outputStream);
        renderDatabaseReport(outputStream);
        renderSystemReportLinks(outputStream);

        renderClosing(outputStream);
    }

    private void renderVersionInfo(ServletOutputStream out) throws IOException {
        out.println("<h4>Mingle Version</h4>");
        out.println("<pre>");
        out.println("Version: " + ManifestUtil.findKeyInClassPath("Mingle-Version"));
        out.println("Revision: " + ManifestUtil.findKeyInClassPath("Mingle-Revision"));
        out.println("</pre>");
    }

    private void renderTimestamp(ServletOutputStream out) throws IOException {
        out.println("<p>" + java.util.Calendar.getInstance().getTime() + "</p>");
    }

    private void renderEnvironmentInfo(ServletOutputStream out) throws IOException {
        out.println("<h4> Environment Information </h4>");
        out.println("<table>");
        for (String javaPropertyName : JAVA_PROPERTIES_TO_DISPLAY_NAMES.keySet()) {
            tableRow(JAVA_PROPERTIES_TO_DISPLAY_NAMES.get(javaPropertyName), System.getProperty(javaPropertyName), out);
        }
        RuntimeMXBean RuntimemxBean = ManagementFactory.getRuntimeMXBean();
        tableRow("JVM Arguments", jvmArguments(RuntimemxBean), out);
        out.println("</table>");
    }

    private String jvmArguments(RuntimeMXBean runtimemxBean) {
        List<String> arguments = runtimemxBean.getInputArguments();
        List<String> safeArguments = new ArrayList<String>();
        for (String arg : arguments) {
            if (arg.toLowerCase().contains("password")) {
                String[] tmp = arg.split("=");
                safeArguments.add(tmp[0] + "=[FILTERED]");
            } else {
                safeArguments.add(arg);
            }
        }
        return safeArguments.toString();
    }

    private void renderSystemReportLinks(ServletOutputStream out) throws IOException {
        out.println("<a href='" + getServletContext().getContextPath() + "/system_monitor/thread_dump'> <h4> JRuby runtime threads dump </h4> </a>");
        out.println("<a href='" + getServletContext().getContextPath() + "/system_monitor/caching'> <h4> Caching stats (Memcached servers and ProjectCache) </h4> </a>");
        out.println("<a href='" + getServletContext().getContextPath() + "/background_status'> <h4>Background Jobs status</h4> </a>");
    }

    private void printStylesheets(ServletOutputStream out) throws IOException {
        out.println("<style type='text/css'");
        printStyleLine(out, "body {font-family: monospace;}");
        printStyleLine(out, "table {border-width: 0px; border-color: gray;}");
        printStyleLine(out, "td {padding: 2px; border-width: 1px; border-style: solid;}");
        printStyleLine(out, "th {padding: 2px; font-weight: bold; border-width: 1px; border-style: solid;}");
        printStyleLine(out, "h4 {margin-bottom: 3px;}");
        out.println("</style>");
    }

    private void printStyleLine(ServletOutputStream out, String line) throws IOException {
        out.println("<!-- " + line + " -->");
    }

    protected LoggedPool getRuntimePool() throws ServletException {
        LoggedPool runtimePool = new PoolServletStore(this.servletContext).getInitializedRuntimePool();
        if (runtimePool == null) {
            throw new ServletException("No runtime pool is available, please check RailsContextListener");
        }
        return runtimePool;
    }

    private void renderMemoryReport(ServletOutputStream out) throws IOException {
        MemoryMXBean memoryMXBean = ManagementFactory.getMemoryMXBean();
        out.println("<h4>JVM Memory Summary</h4>");
        out.println("<table>");
        out.println("<tr><td>Type</td><td>Init</td><td>Used</td><td>Committed</td><td>Max</td></tr>");
        MemoryUsage heap = memoryMXBean.getHeapMemoryUsage();
        MemoryUsage nonHeap = memoryMXBean.getNonHeapMemoryUsage();
        out.println("<tr>" +
                "<td>Heap Memory Usage</td>" +
                "<td>" + heap.getInit() + "</td>" +
                "<td>" + heap.getUsed() + "</td>" +
                "<td>" + heap.getCommitted() + "</td>" +
                "<td>" + heap.getMax() + "</td>" +
                "</tr>");
        out.println("<tr>" +
                "<td>Non-Heap Memory Usage</td>" +
                "<td>" + nonHeap.getInit() + "</td>" +
                "<td>" + nonHeap.getUsed() + "</td>" +
                "<td>" + nonHeap.getCommitted() + "</td>" +
                "<td>" + nonHeap.getMax() + "</td>" +
                "</tr>");

        out.println("</table>");
    }

    private void renderPoolReport(ServletOutputStream out) throws IOException, ServletException {
        out.println("<h4>JRuby Runtime Summary</h4>");
        out.println("<table>");
        PoolStatus poolStatus = getRuntimePool().getStatus();
        tableRow("Max access thread size (as configured)", String.valueOf(poolStatus.getMaxApplications()), out);
        tableRow("Number of threads accessing the runtime", String.valueOf(poolStatus.getActiveApplications()), out);
        tableRow("Number of threads can access the runtime", String.valueOf(poolStatus.getIdleApplications()), out);
        out.println("</table>");

        Map<Integer, String> borrowers = getRuntimePool().borrowers();
        Set<Integer> objects = new HashSet<Integer>(borrowers.keySet());
        out.println("<h4>JRuby Runtime Detail</h4>");
        out.println("<table>");
        out.println("<tr><th>ID</th><th>Borrower</th></tr>");
        for (Integer object : objects) {
            tableRow(String.valueOf(object), borrowers.get(object), out);
        }
        out.println("</table>");
    }

    private void renderDatabaseReport(ServletOutputStream out) throws IOException, ServletException {
        out.println("<h4>Database Connectivity</h4>");
        out.println("<table>");

        try {
            renderDatabaseReportForConfiguration(out);
        } catch (FileNotFoundException e) {
            tableRow("Could not find database configuration file. Is the database configured?", "", out);
        } catch (Exception e) {
            logger.debug(e.getMessage());
            logger.debug("what is the exception class : " + e.getClass());
            e.printStackTrace();
            tableRow("Could not read database configuration file. Is it configured correctly?", "", out);
        }

        out.println("</table>");
    }

    private boolean renderActiveMQReport(ServletOutputStream out) throws IOException, ServletException {
        try {
            BrokerService service = BrokerRegistry.getInstance().lookup("localhost");
            final Map<ActiveMQDestination, Destination> destinationMap = service.getBroker().getDestinationMap();
            ActiveMQDestination[] destinations = destinationMap.keySet().toArray(new ActiveMQDestination[destinationMap.keySet().size()]);
            Arrays.sort(destinations, new Comparator<ActiveMQDestination>() {
                public int compare(ActiveMQDestination o1, ActiveMQDestination o2) {
                    return o1.getQualifiedName().compareTo(o2.getQualifiedName());
                }
            });

            out.println("<h4>ActiveMQ Queue status</h4>");
            out.println("<table>");
            renderQueueHeader(out);

            for (ActiveMQDestination activeMQDestination : destinations)
                renderQueueStatusFor(activeMQDestination, destinationMap.get(activeMQDestination), out);
            renderActiveMQSystemUsage(out, service.getProducerSystemUsage());
            if (service.isSplitSystemUsageForProducersConsumers()) {
                renderActiveMQSystemUsage(out, service.getConsumerSystemUsage());
            }
            out.println("</table>");
            return true;
        } catch (Exception e) {
            return false;
        }
    }

    private void renderActiveMQSystemUsage(ServletOutputStream out, SystemUsage usage) throws IOException {
        String memoryDesc = usageDesc(usage.getMemoryUsage());
        String storeDesc = usageDesc(usage.getStoreUsage());
        String tempDesc = usageDesc(usage.getTempUsage());
        tableRow(String.format("<ul style='margin: 0px'>%s %s %s</ul>", memoryDesc, storeDesc, tempDesc), "", out);
    }

    private String usageDesc(Usage usage) {
        return "<li>" + usage.getName() + " usage: " + usage.getUsage() + " bytes (" + usage.getPercentUsage() + "%)</li>";
    }

    private void renderQueueHeader(ServletOutputStream out) throws IOException {
        out.println("<tr>");
        out.print("<td>Queue Name</td>");
        out.print("<td>Consumer Count</td>");
        out.print("<td>Queue Size</td>");
        out.print("<td>Enqueues</td>");
        out.print("<td>Dequeues</td>");
        out.print("<td>Process Rate (in messages/hour)</td>");
        out.println("</tr>");
    }

    private void renderQueueStatusFor(ActiveMQDestination activeMQDestination, Destination destination, ServletOutputStream out) throws IOException {
        if (activeMQDestination.getQualifiedName().startsWith("queue://mingle")) {
            out.println("<tr>");
            out.print("<td>" + destination.getName() + "</td>");
            DestinationStatistics stats = destination.getDestinationStatistics();
            out.print("<td>" + stats.getConsumers().getCount() + "</td>");
            out.print("<td>" + stats.getMessages().getCount() + "</td>");
            out.print("<td>" + stats.getEnqueues().getCount() + "</td>");
            out.print("<td>" + stats.getDequeues().getCount() + "</td>");
            out.print("<td>" + stats.getProcessTime().getAveragePerSecondExcludingMinMax() * 3600 + "</td>");
            out.println("</tr>");
        }
    }

    private void renderElasticSearchStatus(ServletOutputStream out) throws IOException {
        out.println("<h4>ElasticSearch</h4>");
        out.println("<pre>");
        Node node = ElasticSearch.currentNode();

        if (null != node) {
            ImmutableMap<String, String> config = node.settings().getAsMap();
            out.println("Server settings:");
            printMapEntry(out, config, "network.host");
            printMapEntry(out, config, "http.port");
            out.println();
        }

        Map<String, String> sys = new HashMap<String, String>();
        mapPropertiesWithDefaults(sys, "mingle.search.host", "localhost");
        mapPropertiesWithDefaults(sys, "mingle.search.port", "9200");

        out.println("Client settings:");
        printMapEntry(out, sys, "mingle.search.host");
        printMapEntry(out, sys, "mingle.search.port");
        out.println();

        String connectivity = checkConnection(sys.get("mingle.search.host"),
                Integer.valueOf(sys.get("mingle.search.port"))) ? "up" : "down";
        out.println("Client connectivity: " + connectivity);

        out.println("</pre>");
    }

    private void renderDatabaseReportForConfiguration(ServletOutputStream out) throws IOException, ServletException {
        try {
            this.connection.connect();

            if (this.connection.isConnected()) {
                boolean connectionIsClosed = this.connection.isClosed();
                tableRow("Connection active?", connectionIsClosed ? "No" : "Yes", out);
                tableRow("Database Type", this.connection.isPostgres() ? "PostgreSql" : "Oracle", out);
                tableRow("Database Version", getDatabaseVersion(), out);
            } else {
                tableRow("Unable to get a connection to the database(s) configured", "", out);
                logger.debug("Unable to get a connection to the database(s) configured");
            }

        } catch (SQLException e) {
            tableRow("Unable to get a connection to the database(s) configured: " + e.getMessage(), "", out);
            logger.debug("Unable to get a connection to the database(s) configured: " + e.getMessage());
        } catch (Exception e) {
            tableRow("Unable to get a connection to the database(s) configured: " + e.getMessage(), "", out);
            logger.debug("Unable to get a connection to the database(s) configured: " + e.getMessage());
        } finally {
            this.connection.close();
        }
    }


    private void renderOpening(ServletOutputStream outputStream) throws IOException {
        outputStream.println("<html>");
        outputStream.println("<head>");
        outputStream.println("<title>Mingle Status</title>");
        printStylesheets(outputStream);
        outputStream.println("</head>");
        outputStream.println("<body>");
    }

    private void renderClosing(ServletOutputStream outputStream) throws IOException {
        outputStream.println("<br/><br/><br/></body>");
        outputStream.println("</html>");
    }

    private String getDatabaseVersion() throws Exception {
        String selectDatabaseSql = this.connection.isPostgres() ? "SELECT version();" : "SELECT * FROM V$VERSION WHERE BANNER like 'Oracle%'";

        ResultSet rs = null;
        PreparedStatement statement = null;

        try {
            statement = this.connection.prepareStatement(selectDatabaseSql);
            rs = statement.executeQuery();
            if (rs.next()) {
                return rs.getString(1);
            }
            return "?";
        } finally {
            if (rs != null) {
                rs.close();
            }

            if (statement != null) {
                statement.close();
            }
        }
    }


    private void printMapEntry(ServletOutputStream out, Map map, String key) throws IOException {
        out.println("  " + key + ": " + map.get(key));
    }

    private void mapPropertiesWithDefaults(Map<String, String> map, String key, String defaultValue) {
        String value = System.getProperty(key);

        if (null == value && null != defaultValue) {
            value = defaultValue;
        }

        map.put(key, value);
    }

    private boolean checkConnection(String host, int port) {
        InetSocketAddress address = new InetSocketAddress(host, port);
        Socket socket = new Socket();
        try {
            socket.connect(address, 2000);
        } catch (IOException e) {
            return false;
        } finally {
            try {
                socket.close();
            } catch (IOException e) {
                logger.warn("Failed to close socket while testing connection to " + host + ":" + port, e);
            }
        }
        return true;
    }

    private void tableRow(String cell1, String cell2, ServletOutputStream out) throws IOException {
        out.println("<tr><td>" + cell1 + "</td><td>" + cell2 + "</td></tr>");
    }
}
