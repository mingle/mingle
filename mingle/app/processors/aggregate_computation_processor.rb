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

module AggregateComputation
  def run_once(options={})
    ProjectsProcessor.run_once(options)
    CardsProcessor.run_once(options)
  end
  module_function :run_once

  class AggregateProcessor < Messaging::UserAwareWithLegacyMessageHandlingProcessor
    protected
    def with_abort_if_necessary(message)
      project = Project.find_by_id(message[:project_id])
      return if project.nil?
      aggregate_property_definition = project.all_property_definitions.find(message[:aggregate_property_definition_id])
      return if aggregate_property_definition.nil?
      project.with_active_project do |proj|
        yield(aggregate_property_definition)
      end
    end
  end

  class ProjectsProcessor < AggregateProcessor
    QUEUE = 'mingle.compute_aggregates.projects'

    def on_message(message)
      with_abort_if_necessary(message) do |aggregate_property_definition|
        AggregatePublisher.new(aggregate_property_definition, User.current).publish_card_messages(aggregate_property_definition.card_ids_for_card_type_condition_sql)
      end
    end
  end

  class CardsProcessor < AggregateProcessor
    QUEUE = 'mingle.compute_aggregates.cards'

    def on_message(message)
      compute_aggregate(message)
    end

    private

    class ResolvedComputation
      attr_reader :result

      def initialize(result)
        @result = result
      end

      def unresolved?
        false
      end
    end

    class UnresolvedComputation
      def initialize(exception)
        @exception = exception
      end

      def unresolved?
        true
      end

      def log_info(aggregate_property_definition, card, project)
        base_msg = "\nUnable to compute aggregate #{aggregate_property_definition.name} for #{card.name} in project #{project.identifier}. It may be the case that the aggregate is invalid, and that this is not an error you need to be concerned about. The aggregate value will be set to (not set). Original stacktrace:\n"
        ActiveRecord::Base.logger.info(base_msg + @exception.backtrace.join("\n"))
      end

      def result
        nil
      end
    end

    def republish(message)
      with_abort_if_necessary(message) do |aggregate_property_definition|
        AggregatePublisher.new(aggregate_property_definition, User.current).publish_card_message(message[:card_id])
      end
    end

    def compute_aggregate(message)
      project = Project.find_by_id(message[:project_id])
      if project.nil?
        delete_stale_property_definitions_without_triggering_card_popup_data_cache_after_destroy_hook(message[:project_id], message[:aggregate_property_definition_id], message[:card_id])
        return
      end
      project.with_active_project do |proj|
        card = proj.cards.find_by_id(message[:card_id])
        if card.nil?
          delete_stale_property_definitions_without_triggering_card_popup_data_cache_after_destroy_hook(message[:project_id], message[:aggregate_property_definition_id], message[:card_id])
          return
        end

        destroy_stale_aggregate_indicators(proj, card, message[:aggregate_property_definition_id])

        aggregate_property_definition = proj.all_property_definitions.find_by_id(message[:aggregate_property_definition_id])
        return if aggregate_property_definition.nil?

        destroy_stale_formula_indicators(proj, card, aggregate_property_definition)

        begin
          return if card.card_type != aggregate_property_definition.aggregate_card_type

          computation = begin
            ResolvedComputation.new(aggregate_property_definition.compute_card_aggregate_value(card))
          rescue => e
            UnresolvedComputation.new(e)
          end
          update_aggregates(project, card, aggregate_property_definition.name => computation.result)
          computation.log_info(aggregate_property_definition, card, proj) if computation.unresolved?
        rescue TimeoutError => e
          republish(message)
          Kernel.log_error(e, "#{base_message(aggregate_property_definition, card, proj)} due to timeout. This request to compute the aggregate will be republished and the aggregate will be computed later.", :force_full_trace => true)
          return
        rescue StandardError => e
          if e.lock_wait_timeout?
            republish(message)
            Kernel.log_error(e, "#{base_message(aggregate_property_definition, card, proj)} due to lock wait timeout. This request to compute the aggregate will be republished and the aggregate will be computed later.", :force_full_trace => true)
          else
            Kernel.log_error(e, "#{base_message(aggregate_property_definition, card, proj)}. This request to compute aggregate #{aggregate_property_definition.name} for #{card.name} will be deleted. This might be OK, but you may need to recompute aggregates for your project (via the 'Advanced Admin' page) if you notice that the card related to this request does not show correct aggregate values.", :force_full_trace => true)
          end
          return
        end
      end
      ProjectCacheFacade.instance.clear_cache(project.identifier)
    end

    def update_aggregates(project, card, property_names_and_values)
      CardSelection.new(project, [card]).update_properties(property_names_and_values, {:bypass_versioning => true,
                                                                                       :bypass_update_properties_validation => true,
                                                                                       :increment_caching_stamp => true,
                                                                                       :compute_aggregates_using_card_ancestors => true
                                                                                       })
    end

    def delete_stale_property_definitions_without_triggering_card_popup_data_cache_after_destroy_hook(project_id, aggregate_property_definition_id, card_id)
      StalePropertyDefinition.delete_without_triggering_observers(project_id, aggregate_property_definition_id, card_id)
    end

    def destroy_stale_aggregate_indicators(project, card, prop_def_ids)
      StalePropertyDefinition.find_each(:conditions => { :prop_def_id => Array(prop_def_ids), :card_id => card.id, :project_id => project.id }) do |stale_property_definition|
        stale_property_definition.destroy_without_triggering_observers
      end
      CardCachingStamp.update([card.id])
    end

    def destroy_stale_formula_indicators(project, card, aggregate_property_definition)
      stale_dependent_formulas = aggregate_property_definition.dependant_formulas
      return if stale_dependent_formulas.blank?
      destroy_stale_aggregate_indicators(project, card, stale_dependent_formulas)
    end

    def base_message(aggregate_property_definition, card, project)
      "\nUnable to compute aggregate #{aggregate_property_definition.name} for #{card.name} in project #{project.identifier}"
    end
  end
end
