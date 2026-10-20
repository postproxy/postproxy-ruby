module PostProxy
  module Resources
    # Manages a Google Business Profile location's own data — hours,
    # attributes, services, menus, action links and photos — separate from
    # posting to it.
    #
    # `location_id` is the placement id from `profiles.placements(profile_id)`.
    # Google's payloads are camelCased and passed through untouched, so you can
    # PATCH back exactly what you GET; responses are returned as plain hashes.
    # Updates take a `fields` list naming which top-level fields to change
    # (Google's update mask).
    class GoogleBusiness
      def initialize(client)
        @client = client
      end

      # --- Location ---

      def location(profile_id, location_id, read_mask: nil, profile_group_id: nil)
        read(profile_id, "location", location_id, { read_mask: read_mask }, profile_group_id)
      end

      # `location` holds the Google fields to change (e.g. `title`,
      # `phoneNumbers`, `websiteUri`); `fields` names them.
      def update_location(profile_id, location_id, location, fields:, profile_group_id: nil, idempotency_key: nil)
        write(:patch, profile_id, "update_location", location_id,
          location.merge(fields: fields), profile_group_id, idempotency_key)
      end

      def available_location_categories(profile_id, location_id, region_code, language_code: nil, filter: nil,
        view: nil, page_size: nil, page_token: nil, profile_group_id: nil)
        read(profile_id, "available_location_categories", location_id, {
          region_code: region_code,
          language_code: language_code,
          filter: filter,
          view: view,
          page_size: page_size,
          page_token: page_token
        }, profile_group_id)
      end

      def update_hours(profile_id, location_id, fields: nil, regular_hours: nil, special_hours: nil,
        more_hours: nil, profile_group_id: nil, idempotency_key: nil)
        write(:patch, profile_id, "update_hours", location_id, {
          fields: fields,
          regularHours: regular_hours,
          specialHours: special_hours,
          moreHours: more_hours
        }, profile_group_id, idempotency_key)
      end

      # --- Attributes ---

      def attributes(profile_id, location_id, profile_group_id: nil)
        read(profile_id, "attributes", location_id, {}, profile_group_id)
      end

      def available_attributes(profile_id, location_id, category_name: nil, region_code: nil, language_code: nil,
        show_all: nil, page_size: nil, page_token: nil, profile_group_id: nil)
        read(profile_id, "available_attributes", location_id, {
          category_name: category_name,
          region_code: region_code,
          language_code: language_code,
          show_all: show_all,
          page_size: page_size,
          page_token: page_token
        }, profile_group_id)
      end

      def update_attributes(profile_id, location_id, attributes, attribute_mask: nil, profile_group_id: nil,
        idempotency_key: nil)
        write(:patch, profile_id, "update_attributes", location_id,
          { attributes: attributes, attribute_mask: attribute_mask }, profile_group_id, idempotency_key)
      end

      # --- Services & food menus ---

      def service_list(profile_id, location_id, profile_group_id: nil)
        read(profile_id, "service_list", location_id, {}, profile_group_id)
      end

      def update_service_list(profile_id, location_id, service_items, fields: nil, profile_group_id: nil,
        idempotency_key: nil)
        write(:patch, profile_id, "update_service_list", location_id,
          { serviceItems: service_items, fields: fields }, profile_group_id, idempotency_key)
      end

      def food_menus(profile_id, location_id, fields: nil, profile_group_id: nil)
        read(profile_id, "food_menus", location_id, { fields: fields && Array(fields).join(",") }, profile_group_id)
      end

      def update_food_menus(profile_id, location_id, menus, fields: nil, profile_group_id: nil,
        idempotency_key: nil)
        write(:patch, profile_id, "update_food_menus", location_id,
          { menus: menus, fields: fields }, profile_group_id, idempotency_key)
      end

      # --- Place action links (booking, ordering, ...) ---

      def place_action_links(profile_id, location_id, page_size: nil, page_token: nil, profile_group_id: nil)
        read(profile_id, "place_action_links", location_id,
          { page_size: page_size, page_token: page_token }, profile_group_id)
      end

      def available_place_action_types(profile_id, location_id, language_code: nil, page_size: nil,
        page_token: nil, profile_group_id: nil)
        read(profile_id, "available_place_action_types", location_id, {
          language_code: language_code,
          page_size: page_size,
          page_token: page_token
        }, profile_group_id)
      end

      # `place_action_type` is e.g. APPOINTMENT, ONLINE_APPOINTMENT,
      # DINING_RESERVATION, FOOD_ORDERING, FOOD_DELIVERY, FOOD_TAKEOUT,
      # SHOP_ONLINE.
      def create_place_action_link(profile_id, location_id, uri:, place_action_type:, is_preferred: nil,
        profile_group_id: nil, idempotency_key: nil)
        write(:post, profile_id, "create_place_action_link", location_id, {
          uri: uri,
          place_action_type: place_action_type,
          is_preferred: is_preferred
        }, profile_group_id, idempotency_key)
      end

      # `name` is the link's resource name from #place_action_links.
      def update_place_action_link(profile_id, location_id, name, fields:, uri: nil, place_action_type: nil,
        is_preferred: nil, profile_group_id: nil, idempotency_key: nil)
        write(:patch, profile_id, "update_place_action_link", location_id, {
          name: name,
          fields: fields,
          uri: uri,
          place_action_type: place_action_type,
          is_preferred: is_preferred
        }, profile_group_id, idempotency_key)
      end

      def delete_place_action_link(profile_id, location_id, name, profile_group_id: nil, idempotency_key: nil)
        remove(profile_id, "delete_place_action_link", location_id, { name: name }, profile_group_id, idempotency_key)
      end

      # --- Media ---

      def media(profile_id, location_id, page_size: nil, page_token: nil, profile_group_id: nil)
        read(profile_id, "media", location_id, { page_size: page_size, page_token: page_token }, profile_group_id)
      end

      # `category` is e.g. COVER, PROFILE, LOGO, EXTERIOR, INTERIOR, PRODUCT,
      # ADDITIONAL; `media_format` is PHOTO or VIDEO.
      def create_media(profile_id, location_id, media_url, category: nil, media_format: nil, description: nil,
        profile_group_id: nil, idempotency_key: nil)
        write(:post, profile_id, "create_media", location_id, {
          media_url: media_url,
          category: category,
          media_format: media_format,
          description: description
        }, profile_group_id, idempotency_key)
      end

      # `media_name` is the item's resource name from #media.
      def delete_media(profile_id, location_id, media_name, profile_group_id: nil, idempotency_key: nil)
        remove(profile_id, "delete_media", location_id, { media_name: media_name }, profile_group_id, idempotency_key)
      end

      private

      def path(profile_id, action)
        "/profiles/#{profile_id}/google_business/#{action}"
      end

      def read(profile_id, action, location_id, query, profile_group_id)
        params = { location_id: location_id }.merge(query.compact)
        @client.request(:get, path(profile_id, action), params: params, profile_group_id: profile_group_id)
      end

      def write(method, profile_id, action, location_id, body, profile_group_id, idempotency_key)
        json_body = { location_id: location_id }.merge(body.compact)
        @client.request(method, path(profile_id, action),
          json: json_body,
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
      end

      def remove(profile_id, action, location_id, query, profile_group_id, idempotency_key)
        @client.request(:delete, path(profile_id, action),
          params: { location_id: location_id }.merge(query),
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
      end
    end
  end
end
