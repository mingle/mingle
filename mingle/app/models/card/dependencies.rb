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

module Card::Dependencies
  def self.included(base)
    base.send :include, IndexableDependencyMethods
  end

  def raised_dependencies
    Dependency.from_raising_card(self)
  end

  def dependencies_resolving
    # SQL query assumes no duplicates, but does not make any guarantees on uniqueness. This is a fair assumption though,
    # given that a dependency should only be able to link a given card from its resolving_project exactly once, and that
    # we're ONLY looking at dependency_type = 'Dependency'.
    #
    # Performance Note:
    #
    # Initial profiling indicated that the alternative query using EXISTS clause yielded similar performance, but
    # an inferior execution plan (per EXPLAIN sql), which may indicate the EXISTS approach scales worse than this
    # implicit join with larger datasets compared with what I tested (300+ dependencies, 1200+ versions,
    # 100+ dependency_resolving cards). The JOIN may benefit more from adding indexes as well (be careful here,
    # indexing can cause negative performance issues). My recommendations for adding indexes, if at all, would be
    # only on dependency_id and card_number; the ** cardinalities of other columns are far too small to be beneficial, **
    # and will negatively impact insert/update and eat more disk space. Most likely the DB engine optimizer will
    # choose a full table scan instead of index scan for the other columns anyway.
    sql = SqlHelper.sanitize_sql(%Q{
      SELECT d.*
        FROM #{Dependency.table_name} d, #{DependencyResolvingCard.table_name} drc
       WHERE drc.dependency_id = d.id
         AND drc.dependency_type = 'Dependency'
         AND drc.card_number = ?
         AND drc.project_id = ?
    }, number, project_id)
    Dependency.find_by_sql(sql)
  end

  def raised_dependencies_status
    statuses_sql = SqlHelper.sanitize_sql(%Q{
      SELECT COUNT(status) AS total, status
        FROM #{Dependency.quoted_table_name} d
       WHERE d.raising_card_number = ?
         AND d.raising_project_id = ?
    GROUP BY status
    }, number, project_id)

    statuses = Dependency.connection.select_all(statuses_sql)

    return nil if statuses.empty?

    return Dependency::RESOLVED if statuses.size == 1 && statuses.first["status"] == Dependency::RESOLVED
    return Dependency::NEW if statuses.any? {|st| st["status"] == Dependency::NEW}
    Dependency::ACCEPTED
  end

  def dependencies_resolving_status
    statuses_sql = SqlHelper.sanitize_sql(%Q{
      SELECT COUNT(d.status) AS total, d.status AS status
        FROM #{Dependency.quoted_table_name} d, #{DependencyResolvingCard.quoted_table_name} drc
       WHERE drc.dependency_id = d.id
         AND drc.dependency_type = 'Dependency'
         AND drc.card_number = ?
         AND drc.project_id = ?
    GROUP BY status
    }, number, project_id)

    statuses = Dependency.connection.select_all(statuses_sql)

    return nil if statuses.empty?

    return Dependency::RESOLVED if statuses.size == 1 && statuses.first["status"] == Dependency::RESOLVED
    Dependency::ACCEPTED
  end

  def raise_dependency(attrs)
    raised_dependencies.build(attrs.merge(:raising_project_id => self.project_id, :raising_user_id => User.current.id, :raising_card_number => number))
  end

  module IndexableDependencyMethods
    def raises_dependencies
      raised_dependencies.map(&:number_and_name)
    end

    def resolves_dependencies
      dependencies_resolving.map(&:number_and_name)
    end
  end

  def before_destroy
    destroy_dependencies
  end

  def destroy_dependencies
    raised_dependencies.each(&:destroy)
    dependencies_resolving.each do |dependency|
      raise "failed to unlink dependency #{dependency.prefixed_number}" unless dependency.unlink_resolving_card_by_number(number)
    end
  end
end
