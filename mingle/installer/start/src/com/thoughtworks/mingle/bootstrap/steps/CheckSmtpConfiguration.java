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

package com.thoughtworks.mingle.bootstrap.steps;

import com.thoughtworks.mingle.bootstrap.BootstrapState;

import javax.servlet.ServletContext;

public class CheckSmtpConfiguration extends AbstractBootstrapStep {

    protected AbstractBootstrapStep process() {
        // The Mingle installation wizard treats these as the same step
        // and creates both configurations during smtp configuration page.
        // Not ideal, but it's better to keep parity with the wizard.
        if (checks().isAuthConfigured() && checks().isSmtpConfigured()) {
            setState(BootstrapState.SMTP_CONFIGURED);
            return new CheckEulaAcceptance(context);
        }

        setState(BootstrapState.SMTP_NOT_CONFIGURED);
        return this;
    }

    public CheckSmtpConfiguration(ServletContext context) {
        super(context);
    }

}
