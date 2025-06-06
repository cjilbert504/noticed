module Noticed
  class Ephemeral
    include ActiveModel::Model
    include ActiveModel::Attributes
    include Noticed::Deliverable
    include Noticed::Translation
    include Rails.application.routes.url_helpers

    attribute :record
    attribute :params, default: {}

    class Notification
      include ActiveModel::Model
      include ActiveModel::Attributes
      include Noticed::Translation
      include Rails.application.routes.url_helpers

      attribute :recipient
      attribute :event

      delegate :params, :record, to: :event

      def self.new_with_params(recipient, params)
        instance = new(recipient: recipient)
        instance.event = module_parent.new(params: params)
        instance
      end
    end

    # Dynamically define Notification on each Ephemeral Notifier
    def self.inherited(notifier)
      super
      notifier.const_set :Notification, Class.new(Noticed::Ephemeral::Notification)
    end

    def self.notification_methods(&block)
      const_get(:Notification).class_eval(&block)
    end

    def deliver(recipients = nil)
      recipients ||= evaluate_recipients
      recipients = Array.wrap(recipients)

      bulk_delivery_methods.each do |_, deliver_by|
        deliver_by.ephemeral_perform_later(self.class.name, recipients, params)
      end

      recipients.each do |recipient|
        delivery_methods.each do |_, deliver_by|
          deliver_by.ephemeral_perform_later(self.class.name, recipient, params)
        end
      end

      self
    end

    def record
      params[:record]
    end
  end
end

ActiveSupport.run_load_hooks :noticed_ephemeral, Noticed::Ephemeral
