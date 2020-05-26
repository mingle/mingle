#  Copyright 2020 ThoughtWorks, Inc.
#  
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU Affero General Public License as
#  published by the Free Software Foundation, either version 3 of the
#  License, or (at your option) any later version.
#  
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU Affero General Public License for more details.
#  
#  You should have received a copy of the GNU Affero General Public License
#  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.


# we need to delete a message after it is received
# because these jobs may need 20+ hours to process one message,
# and sqs message has a limit (12 hours) of visibility_timeout
# for a message in processing
# see sqs document for more details
Messaging::Adapters::SQS.queues_deleting_message_on_receive = [
                                                               ProjectExportProcessor,
                                                               ProjectImportProcessor,
                                                               ProjectHistoryDataExportProcessor,
                                                               ProgramExportProcessor,
                                                               ProgramImportProcessor,
                                                               CardImportPreviewProcessor,
                                                               CardImportProcessor,
                                                               ProjectDataExportProcessor,
                                                               MergeExportDataProcessor,
                                                               InstanceDataExportProcessor,
                                                               DependencyDataExportProcessor,
                                                               ProgramDataExportProcessor,
                                                               IntegrationsExportProcessor
                                                              ].map {|processor| processor::QUEUE}
