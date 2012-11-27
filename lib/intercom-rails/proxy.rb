module IntercomRails

  module Proxy

    class Proxy

      def self.class_string
        self.to_s.split('::').last
      end

      def self.inherited(subclass)
        subclass.class_eval do
          attr_reader class_string.downcase.to_s 
        end
      end

      def self.current_in_context(search_object)
        potential_objects = const_get("POTENTIAL_#{class_string.upcase}_OBJECTS")
        potential_objects.each do |potential_object|
          begin
            proxy = new(search_object.instance_eval(&potential_object), search_object)
            return proxy if proxy.valid?
          rescue NameError
            next
          end
        end

        exception = IntercomRails.const_get("No#{class_string}FoundError")
        raise exception 
      end

      attr_reader :search_object, :proxied_object

      def initialize(object_to_proxy, search_object = nil)
        @search_object = search_object
        @proxied_object = instance_variable_set(:"@#{type}", object_to_proxy)
      end

      def to_hash
        hsh = {}

        hsh.merge! standard_data
        hsh[:custom_data] = custom_data
        hsh.delete(:custom_data) if hsh[:custom_data].blank?

        hsh
      end

      def custom_data
        custom_data_from_config.merge custom_data_from_request
      end

      def type
        self.class.class_string.downcase.to_sym
      end

      protected

      def attribute_present?(attribute)
        proxied_object.respond_to?(attribute) && proxied_object.send(attribute).present?
      end

      def config
        IntercomRails.config.send(type)
      end

      private

      def custom_data_from_request 
        search_object.intercom_custom_data.send(type)
      rescue NoMethodError
        {}
      end

      def custom_data_from_config 
        return {} if config.custom_data.blank?
        config.custom_data.reduce({}) do |custom_data, (k,v)|
          custom_data.merge(k => custom_data_value_from_proc_or_symbol(v))
        end
      end

      def custom_data_value_from_proc_or_symbol(proc_or_symbol)
        if proc_or_symbol.kind_of?(Symbol)
          proxied_object.send(proc_or_symbol)
        elsif proc_or_symbol.kind_of?(Proc)
          proc_or_symbol.call(user)
        end
      end

    end

  end

end
