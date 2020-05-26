README 
------
This tool only supports importing projects that were exported from Mingle 3.3.1 or later.  Importing projects from earlier versions of Mingle is not supported.

The tools export_all_projects.rb and import_projects.rb can be used together to perform a bulk export and import of all projects in a Mingle instance. This can be helpful when migrating from one database to another database. If you need any assistance using this tool please contact ThoughtWorks Studios Support at http://studios.thoughtworks.com/mingle-agile-project-management/support-requests

*NOTE* 

* If you get a NoClassDefFoundError that is typically because too many arguments were passed or your data directory has spaces in it. Currently for these scripts, spaces are not allowed in the data directory. On all platforms you can get around this by replacing spaces with underscores. You can remove the underscores after using these scripts if you prefer not to have them. For Windows, see the note about using the 8 character folder names.
* These scripts do not access the Mingle swap directory. Please ignore any references to the swap directory.
* If you have any issues using either of these scripts please contact Mingle Support at http://studios.thoughtworks.com/support


How to use export_all_projects.rb
---------------------------------

The instructions to use this tool vary slightly across different platforms, and are as follows:

Windows
-------

* Identify the directory where Mingle is installed. Typically this is under C:\Program files\Mingle. Let's call this MINGLE_HOME.
* Identify the Mingle data directory. Typically this is C:\Documents and Settings\<USER>\Mingle. Let's call this MINGLE_DATA_DIR.
** Because this tool is a DOS batch script, you will need to use the 8 character file and folder names. E.g., C:\Documents and Settings\Mingle User\Mingle would be C:\Docume~1\Mingle~1\Mingle
* If the Mingle config directory is not inside the data directory then identify the Mingle config directory. Let's call this MINGLE_CONFIG_DIR.
* On the command line, navigate to <MINGLE_HOME>
* Use run.bat to start export_all_projects.rb running by using the following command: tools\run.bat tools\export_import\export_all_projects.rb --mingle.dataDir=<MINGLE_DATA_DIR>
* If the Mingle config directory is not inside the data directory then use run.bat to start export_all_projects.rb running by using the following command: tools\run.bat tools\export_import\export_all_projects.rb --mingle.dataDir=<MINGLE_DATA_DIR> --mingle.configDir=<MINGLE_CONFIG_DIR>
* JVM options can be set via the JAVA_OPTS environment variable e.g. set JAVA_OPTS=-Xmx718m
* This tool will place an export of the projects (in .mingle format) in the <MINGLE_HOME>\exported_projects directory

UNIX (including Solaris and OSX)
------------------------

* Identify the directory where Mingle is installed. Let's call this MINGLE_HOME.
* Identify the Mingle data directory. This is the --mingle.dataDir property that is supplied when starting the Mingle server. Let's call this MINGLE_DATA_DIR.
* If the Mingle config directory is not inside the data directory then identify the Mingle config directory. Let's call this MINGLE_CONFIG_DIR.
* At the terminal, navigate to <MINGLE_HOME>.
* Make the tools/run file executable with this command: chmod +x tools/run
* Use the run script to start export_all_projects.rb running by using the following command: tools/run tools/export_import/export_all_projects.rb --mingle.dataDir=<MINGLE_DATA_DIR>
* If the Mingle config directory is not inside the data directory then use the run script to start export_all_projects.rb running by using the following command: tools/run tools/export_import/export_all_projects.rb --mingle.dataDir=<MINGLE_DATA_DIR> --mingle.configDir=<MINGLE_CONFIG_DIR>
* JVM options can be set via the JAVA_OPTS environment variable e.g. JAVA_OPTS=-Xmx718m tools/run tools/export_import/export_all_projects.rb 
* This tool will place an export of the projects (in .mingle format) in the <MINGLE_HOME>/exported_projects directory

----------------------------------------------------------------

How to use import_projects.rb (after using export_projects.rb)
--------------------------------------------------------------

BEFORE USING import_projects.rb PLEASE READ THE FOLLOWING CAREFULLY:

*NOTE* Importing a large project can take a long time. You may want to run this tool during a period when there is limited Mingle activity and anticipate that the imported projects may be unavailable for some time. You can import all projects at once or a single project at a time.

*NOTE* If you are using this tool to migrate to another database you should:
* complete the Mingle installation process using the new database settings completely, including creation of an initial user, before running this tool
* license the new instance
* create any users who are not associated with a project manually using Mingle as they will not be imported with the projects 
* review the templates after the import has completed to remove any duplicates of the standard templates that may have been installed

*NOTE* All files to be imported need to be in <MINGLE_HOME>/exported_projects. When importing a single file only filenames, not full paths, are expected as values of --filename=<FILE_NAME>.

The instructions to use this tool vary slightly across different platforms, and are as follows:

Windows
-------

* Identify the directory where Mingle is installed. Typically this is under C:\Program files\Mingle. Let's call this MINGLE_HOME.
* Identify the Mingle data directory. Typically this is C:\Documents and Settings\<USER>\Mingle. Let's call this MINGLE_DATA_DIR.
** As this tool is a DOS batch script, you will need to use the 8 character file and folder names. E.g., C:\Documents and Settings\Mingle User\Mingle would be C:\Docume~1\Mingle~1\Mingle
 If the Mingle config directory is not inside the data directory then identify the Mingle config directory. Let's call this MINGLE_CONFIG_DIR.
* On the command line, navigate to <MINGLE_HOME>
* Use run.bat to start import_projects.rb running by using the following command: tools\run.bat tools\export_import\import_projects.rb --mingle.dataDir=<MINGLE_DATA_DIR>
** That will import all .mingle projects in the <MINGLE_HOME>\exported_projects directory. 
* If the Mingle config directory is not inside the data directory then use run.bat to start import_projects.rb running by using the following command: tools\run.bat tools\export_import\import_projects.rb --mingle.dataDir=<MINGLE_DATA_DIR> --mingle.configDir=<MINGLE_CONFIG_DIR>
** That will import all .mingle projects in the <MINGLE_HOME>\exported_projects directory. 
* To only import a single project, you can also add a project file name to the command: tools\run.bat tools\export_import\import_projects.rb --mingle.dataDir=<MINGLE_DATA_DIR> --filename=<FILE_NAME>. 

UNIX (including Solaris and OSX)
------------------------

* Identify the directory where Mingle is installed. Let's call this MINGLE_HOME.
* Identify the Mingle data directory. This is the --mingle.dataDir property is supplied when starting the Mingle server. Let's call this MINGLE_DATA_DIR.
* If the Mingle config directory is not inside the data directory then identify the Mingle config directory. Let's call this MINGLE_CONFIG_DIR.
* At the terminal, navigate to <MINGLE_HOME>
* Use the run script to start import_projects.rb running by using the following command: tools/run tools/export_import/import_projects.rb --mingle.dataDir=<MINGLE_DATA_DIR>
** That will import all .mingle projects in the <MINGLE_HOME>/exported_projects directory. 
* If the Mingle config directory is not inside the data directory then use the run script to start import_projects.rb running by using the following command: tools/run tools/export_import/import_projects.rb --mingle.dataDir=<MINGLE_DATA_DIR> --mingle.configDir=<MINGLE_CONFIG_DIR>
** That will import all .mingle projects in the <MINGLE_HOME>/exported_projects directory. 
* To only import a single project, you can also add a project file name to the command: tools/run tools/export_import/import_projects.rb --mingle.dataDir=<MINGLE_DATA_DIR> --filename=<FILE_NAME>. 

----------------------------------------------------------------

How to use import_projects.rb (without using export_projects.rb first)
----------------------------------------------------------------------

You can use import_projects.rb without running export_projects.rb first. This allows you to import .mingle files exported from other instances of Mingle. 

To do this you will need to create a folder called exported_projects. This should be created at <MINGLE_HOME>/exported_projects. Add all .mingle files you wish to import into this folder and follow the instructions above ("How to use import_projects.rb (after using export_projects.rb)") to import them.



