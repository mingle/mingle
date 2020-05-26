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

class User
  module HistorySubscriber
    # perhaps this belongs elsewhere, but for now the user must send the notifications since
    # the user owns the intersection of his events and subscriptions and can therefore
    # eliminate duplicates.  please volunteer a better location for this!!
    def send_history_notifications_for(project, options = {})
      if email.blank?
        hs = HistorySubscription.new
        project.make_history_subscription_current(hs)
        project.history_subscriptions.update_all({:last_max_card_version_id => hs.last_max_card_version_id,
                                                 :last_max_page_version_id => hs.last_max_page_version_id,
                                                 :last_max_revision_id => hs.last_max_revision_id},
                                                 "user_id = #{self.id}")
        return
      end

      # put in transaction and lock all subscriptions_for_project so that we won't
      # send out duplicated emails when we run multiple worker for history notifications
      HistorySubscription.transaction do
        subscriptions_for_project = project.history_subscriptions.find(:all, :conditions => {:user_id => self.id}, :lock => true)
        do_send_history_notifications(subscriptions_for_project, project, options)
      end
    end

    def has_subscribed_history?(project, filter_params)
      filter_params = nil if filter_params.blank?
      serialized_params = HistoryFilterParams.new(filter_params).serialize
      history_subscriptions.count(:conditions => {:project_id => project.id, :hashed_filter_params => HistorySubscription.param_hash(filter_params)}) > 0
    end

    def destroy_subscriptions_by_event_cache!
      @subscriptions_by_event = nil
    end

    private

    def do_send_history_notifications(subscriptions_for_project, project, options)
      subscriptions_by_event = history_subscriptions_by_event(subscriptions_for_project, options)
      events_in_delivery_order = subscriptions_by_event.keys.sort_by{|key| [key.event_type.to_s, key.id]}
      events_in_delivery_order.each do |event|
        begin
          subscriptions_for_project.each{ |subscription| subscription.update_last_notification(event) }
          HistoryMailer.send("deliver_#{event.event_type}_notification", event, subscriptions_by_event[event])
        rescue Exception => e
          log_error(e, %{
            Error while delivering history notification (project: #{project.identifier}, event: #{event.event}, user: #{self.login}
          })
          break  # don't attempt to delivery any more notifications to this subscriber this time around
        end
      end
    end

    def history_subscriptions_by_event(subscriptions_for_project, options)
      @subscriptions_by_event ||= subscriptions_for_project.inject({}) do |result, subscription|
        begin
          subscription.fresh_events(options).each do |event|
            (result[event] ||= []) << subscription
          end
          subscription.update_attribute :error_message, nil if subscription.processing_error?
        rescue Exception => e
          subscription.update_attribute :error_message, e.message.truncate_with_ellipses(255)
          log_error(e, %{
            Error while processing history subscription (project: #{subscription.project.identifier}, subscription: #{subscription.id}, user: #{self.login}
          })
        end
        result
      end
    end
  end
end
