require "erb"

module PostProxy
  module Resources
    # WhatsApp message templates, which live on the WhatsApp Business account
    # (the profile). A template is addressed by its PostProxy id, Meta's id, or
    # its name — pass `language` with a name that exists in several languages.
    class WhatsAppTemplates
      def initialize(client)
        @client = client
      end

      # `refresh: true` re-reads the templates from Meta first.
      def list(profile_id, name: nil, language: nil, status: nil, refresh: nil, profile_group_id: nil)
        params = {}
        params[:name] = name if name
        params[:language] = language if language
        params[:status] = status if status
        params[:refresh] = refresh unless refresh.nil?

        result = @client.request(:get, path(profile_id),
          params: params.empty? ? nil : params,
          profile_group_id: profile_group_id
        )
        templates = (result[:data] || []).map { |t| WhatsAppTemplate.new(**t) }
        ListResponse.new(data: templates)
      end

      def get(profile_id, id, language: nil, profile_group_id: nil)
        result = @client.request(:get, path(profile_id, id),
          params: language ? { language: language } : nil,
          profile_group_id: profile_group_id
        )
        WhatsAppTemplate.new(**result)
      end

      # Submitted to Meta for review; follow `status` via #get or the
      # `message_template.status_updated` webhook. `category` is MARKETING,
      # UTILITY or AUTHENTICATION; `components` are Meta's component objects
      # (HEADER, BODY, FOOTER, BUTTONS). Pass `library_template_name` (and its
      # inputs) instead of `components` to create from Meta's template library.
      def create(profile_id, name:, category:, language:, parameter_format: nil, components: nil,
        library_template_name: nil, library_template_body_inputs: nil, library_template_button_inputs: nil,
        message_send_ttl_seconds: nil, profile_group_id: nil, idempotency_key: nil)
        json_body = {
          name: name,
          category: category,
          language: language,
          parameter_format: parameter_format,
          components: components,
          library_template_name: library_template_name,
          library_template_body_inputs: library_template_body_inputs,
          library_template_button_inputs: library_template_button_inputs,
          message_send_ttl_seconds: message_send_ttl_seconds
        }.compact

        result = @client.request(:post, path(profile_id),
          json: json_body,
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        WhatsAppTemplate.new(**result)
      end

      def update(profile_id, id, components: nil, message_send_ttl_seconds: nil, language: nil,
        profile_group_id: nil, idempotency_key: nil)
        json_body = { components: components, message_send_ttl_seconds: message_send_ttl_seconds }.compact

        result = @client.request(:patch, path(profile_id, id),
          params: language ? { language: language } : nil,
          json: json_body,
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        WhatsAppTemplate.new(**result)
      end

      # Deleting by name without `language` removes every language of the
      # template.
      def delete(profile_id, id, language: nil, profile_group_id: nil, idempotency_key: nil)
        @client.request(:delete, path(profile_id, id),
          params: language ? { language: language } : nil,
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
      end

      # Meta's ready-made template library.
      def library(profile_id, name: nil, language: nil, profile_group_id: nil)
        params = {}
        params[:name] = name if name
        params[:language] = language if language

        @client.request(:get, "#{path(profile_id)}/library",
          params: params.empty? ? nil : params,
          profile_group_id: profile_group_id
        )
      end

      private

      def path(profile_id, id = nil)
        base = "/profiles/#{profile_id}/templates"
        id.nil? ? base : "#{base}/#{ERB::Util.url_encode(id.to_s)}"
      end
    end
  end
end
