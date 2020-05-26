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

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.sql.*;
import java.util.Properties;

public class JdbcConnection {
    private Connection connection = null;
    private DatabaseConfiguration configuration;

    private static Logger logger = LoggerFactory.getLogger("com.thoughtworks.mingle.murmurs");
    private boolean autoCommit;

    public JdbcConnection(DatabaseConfiguration configuration) {
        this(configuration, true);
    }

    public JdbcConnection(DatabaseConfiguration configuration, boolean autoCommit) {
        this.configuration = configuration;
        this.autoCommit = autoCommit;
    }

    public JdbcConnection connect() throws Exception {
        Class.forName(configuration.driver());
        Properties connectionProperties = new Properties();
        if (configuration.username() != null)
            connectionProperties.put("user", configuration.username());
        if (configuration.password() != null)
            connectionProperties.put("password", configuration.password());
        connectionProperties.put("SetBigStringTryClob", "true");

        this.connection = getConnectionWithRetry(connectionProperties);
        this.connection.setAutoCommit(this.autoCommit);
        return this;
    }

    private Connection getConnectionWithRetry(Properties connectionProperties) throws Exception {
        int tries = 3;
        while (true) {
            try {
                return DriverManager.getConnection(configuration.url(), connectionProperties);
            } catch (java.sql.SQLRecoverableException e) {
                tries--;
                if(tries <= 0) {
                    throw e;
                }
                logger.info("Trying to recover from a SQLRecoverableException[" + e.getMessage() + "] while getting database connection. " + tries + " tries remaining.");
            }
        }
    }

    public boolean isConnected() {
        return connection != null;
    }

    public boolean isClosed() throws SQLException {
        return this.connection.isClosed();
    }

    public void close() {
        if (!isConnected())
            return;
        try {
            this.connection.close();
        } catch (SQLException e) {
            logger.info("Unable to close the jdbc connection.");
        }
    }

    public void executeUpdate(String sql, Object... values) throws Exception {
        PreparedStatement s = null;
        try {
            s = prepareStatement(sql, values);
            s.executeUpdate();
        } finally {
            if (s != null)
                s.close();
        }
    }

    public long executeInsert(String postgresSequenceName, String oracleSequenceName, String sql, Object... values) throws Exception {
        PreparedStatement preparedStatement = null;
        ResultSet resultSet = null;
        long generatedId = -1;
        try {
            if (isPostgres()) {
                sql = sql + "; SELECT currval('" + postgresSequenceName + "');";
                preparedStatement = prepareStatement(sql, values);
                preparedStatement.execute();
                int nInserted = preparedStatement.getUpdateCount();
                if (nInserted == 1 && preparedStatement.getMoreResults()) {
                    resultSet = preparedStatement.getResultSet();
                    if (resultSet.next())
                        generatedId = resultSet.getLong(1);
                }
            } else {
                generatedId = getNexValFromSeqOracle(oracleSequenceName);

                Object[] preparedStatementValues = new Object[values.length + 1];
                preparedStatementValues[0] = generatedId;
                System.arraycopy(values, 0, preparedStatementValues, 1, values.length);
                preparedStatement = prepareStatement(sql, preparedStatementValues);
                preparedStatement.execute();
            }
            return generatedId;
        } finally {
            if (resultSet != null) {
                resultSet.close();
            }

            if (preparedStatement != null) {
                preparedStatement.close();
            }
        }
    }

    private long getNexValFromSeqOracle(String oracleSequenceName) throws Exception {
        PreparedStatement statement = null;
        ResultSet resultSet = null;
        try {
            String nextValueSQL = "SELECT " + oracleSequenceName + ".NEXTVAL FROM DUAL";
            statement = prepareStatement(nextValueSQL);
            resultSet = statement.executeQuery();
            resultSet.next();
            return resultSet.getLong(1);
        } finally {

            if (resultSet != null) {
                resultSet.close();
            }

            if (statement != null) {
                statement.close();
            }

        }
    }

    public PreparedStatement prepareStatement(String sql, Object... values) throws Exception {
        if (isClosed()) {
            this.connect();
        }
        PreparedStatement statement = this.connection.prepareStatement(sql);
        for (int i = 0; i < values.length; i++)
            statement.setObject(i + 1, values[i]);
        return statement;
    }

    public boolean isPostgres() {
        return this.configuration.isPostgres();
    }

    public void rollback() throws Exception {
        if (isClosed()) {
            this.connect();
        }
        this.connection.rollback();
    }

    public void executeDelete(String sql) throws Exception {
        if (isClosed()) {
            this.connect();
        }
        PreparedStatement statement = this.connection.prepareStatement(sql);
        statement.execute();
    }
}
