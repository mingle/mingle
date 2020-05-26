;;  Copyright 2020 ThoughtWorks, Inc.
;;
;;  This program is free software: you can redistribute it and/or modify
;;  it under the terms of the GNU Affero General Public License as
;;  published by the Free Software Foundation, either version 3 of the
;;  License, or (at your option) any later version.
;;
;;  This program is distributed in the hope that it will be useful,
;;  but WITHOUT ANY WARRANTY; without even the implied warranty of
;;  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;;  GNU Affero General Public License for more details.
;;
;;  You should have received a copy of the GNU Affero General Public License
;;  along with this program.  If not, see <https://www.gnu.org/licenses/agpl-3.0.txt>.

;; For those using emacs and RVM...

(rvm-use "jruby-1.7.25" "mingle_development")
(setenv "JRUBY_OPTS" "--1.8")
(setenv "JAVA_OPTS" "-Xmx1024m -XX:MaxPermSize=256m -XX:PermSize=512m -XX:NewSize=128m -XX:+UseConcMarkSweepGC -XX:+HeapDumpOnOutOfMemoryError -Djava.util.logging.config.file=java_util_logging.properties -Dmingle.logDir=log -Dlog4j.configuration=log4j.properties.development -Duser.language=en -Duser.country=US -Djava.awt.headless=true -Dfile.encoding=UTF-8")
(setq js-indent-level 2)
(setq css-indent-offset 2)
