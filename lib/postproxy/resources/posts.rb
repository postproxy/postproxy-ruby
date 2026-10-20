module PostProxy
  module Resources
    class Posts
      def initialize(client)
        @client = client
      end

      def list(page: nil, per_page: nil, status: nil, platforms: nil, scheduled_after: nil, profile_group_id: nil)
        params = {}
        params[:page] = page if page
        params[:per_page] = per_page if per_page
        params[:status] = status if status
        params[:platforms] = platforms.join(",") if platforms
        params[:scheduled_after] = format_time(scheduled_after) if scheduled_after

        result = @client.request(:get, "/posts", params: params, profile_group_id: profile_group_id)
        posts = (result[:data] || []).map { |p| Post.new(**p) }
        PaginatedResponse.new(
          data: posts,
          total: result[:total],
          page: result[:page],
          per_page: result[:per_page]
        )
      end

      def get(id, profile_group_id: nil)
        result = @client.request(:get, "/posts/#{id}", profile_group_id: profile_group_id)
        Post.new(**result)
      end

      # `media` items are URL strings or `{ url: }` hashes. A local
      # `cover_file` in `platforms` (Instagram, TikTok, YouTube, Pinterest) is
      # uploaded with the post, switching the request to multipart; a base64
      # data URL is sent as-is. `skip_duplicate_check: true` publishes even if
      # an identical post was just submitted (no ConflictError).
      def create(body, profiles:, media: nil, media_files: nil, platforms: nil,
                 thread: nil, scheduled_at: nil, draft: nil, queue_id: nil,
                 queue_priority: nil, profile_group_id: nil, idempotency_key: nil,
                 skip_duplicate_check: nil)
        has_files = media_files && !media_files.empty?
        has_thread_files = thread&.any? { |t| t[:media_files]&.any? }
        headers = skip_duplicate_check ? { "X-Skip-Duplicate-Check" => "true" } : nil

        if has_files || has_thread_files || local_cover_file?(platforms)
          form_data = { "post[body]" => body }
          form_data["post[scheduled_at]"] = format_time(scheduled_at) if scheduled_at
          form_data["post[draft]"] = draft.to_s if !draft.nil?
          form_data["queue_id"] = queue_id if queue_id
          form_data["queue_priority"] = queue_priority if queue_priority

          files = []

          profiles.each do |p|
            files << ["profiles[]", nil, p, "text/plain"]
          end

          media&.each do |m|
            files << ["media[]", nil, media_url(m), "text/plain"]
          end

          append_platform_params(files, platforms) if platforms

          media_files&.each do |path|
            path = path.to_s
            filename = File.basename(path)
            content_type = mime_type_for(filename)
            io = File.open(path, "rb")
            files << ["media[]", filename, io, content_type]
          end

          thread&.each_with_index do |t, i|
            form_data["thread[#{i}][body]"] = t[:body] if t[:body]

            t[:media]&.each do |m|
              files << ["thread[#{i}][media][]", nil, media_url(m), "text/plain"]
            end

            t[:media_files]&.each do |path|
              path = path.to_s
              filename = File.basename(path)
              content_type = mime_type_for(filename)
              io = File.open(path, "rb")
              files << ["thread[#{i}][media][]", filename, io, content_type]
            end
          end

          result = @client.request(:post, "/posts",
            data: form_data,
            files: files,
            profile_group_id: profile_group_id,
            idempotency_key: idempotency_key,
            headers: headers
          )
        else
          post_payload = { body: body }
          post_payload[:scheduled_at] = format_time(scheduled_at) if scheduled_at
          post_payload[:draft] = draft unless draft.nil?

          json_body = { post: post_payload, profiles: profiles }
          json_body[:platforms] = platforms.is_a?(PlatformParams) ? platforms.to_h : platforms if platforms
          json_body[:media] = media if media
          json_body[:thread] = thread if thread
          json_body[:queue_id] = queue_id if queue_id
          json_body[:queue_priority] = queue_priority if queue_priority

          result = @client.request(:post, "/posts",
            json: json_body,
            profile_group_id: profile_group_id,
            idempotency_key: idempotency_key,
            headers: headers
          )
        end

        Post.new(**result)
      end

      # On a published post only `body`, `platforms.youtube.title`,
      # `platforms.pinterest.title` and `platforms.pinterest.destination_link`
      # can change; the edit is pushed to the platforms in the background
      # (`platform_post.edited` / `platform_post.edit_failed` webhooks).
      def update(id, body: nil, profiles: nil, media: nil, media_files: nil, platforms: nil,
                 thread: nil, scheduled_at: nil, draft: nil, queue_id: nil,
                 queue_priority: nil, profile_group_id: nil, idempotency_key: nil)
        has_files = media_files && !media_files.empty?
        has_thread_files = thread&.any? { |t| t[:media_files]&.any? }

        if has_files || has_thread_files || local_cover_file?(platforms)
          form_data = {}
          form_data["post[body]"] = body if body
          form_data["post[scheduled_at]"] = format_time(scheduled_at) if scheduled_at
          form_data["post[draft]"] = draft.to_s if !draft.nil?
          form_data["queue_id"] = queue_id if queue_id
          form_data["queue_priority"] = queue_priority if queue_priority

          files = []

          profiles&.each do |p|
            files << ["profiles[]", nil, p, "text/plain"]
          end

          media&.each do |m|
            files << ["media[]", nil, media_url(m), "text/plain"]
          end

          append_platform_params(files, platforms) if platforms

          media_files&.each do |path|
            path = path.to_s
            filename = File.basename(path)
            content_type = mime_type_for(filename)
            io = File.open(path, "rb")
            files << ["media[]", filename, io, content_type]
          end

          thread&.each_with_index do |t, i|
            form_data["thread[#{i}][body]"] = t[:body] if t[:body]

            t[:media]&.each do |m|
              files << ["thread[#{i}][media][]", nil, media_url(m), "text/plain"]
            end

            t[:media_files]&.each do |path|
              path = path.to_s
              filename = File.basename(path)
              content_type = mime_type_for(filename)
              io = File.open(path, "rb")
              files << ["thread[#{i}][media][]", filename, io, content_type]
            end
          end

          result = @client.request(:patch, "/posts/#{id}",
            data: form_data,
            files: files,
            profile_group_id: profile_group_id,
            idempotency_key: idempotency_key
          )
        else
          json_body = {}

          post_payload = {}
          post_payload[:body] = body if body
          post_payload[:scheduled_at] = format_time(scheduled_at) if scheduled_at
          post_payload[:draft] = draft unless draft.nil?
          json_body[:post] = post_payload unless post_payload.empty?

          json_body[:profiles] = profiles if profiles
          json_body[:platforms] = platforms.is_a?(PlatformParams) ? platforms.to_h : platforms if platforms
          json_body[:media] = media if media
          json_body[:thread] = thread if thread
          json_body[:queue_id] = queue_id if queue_id
          json_body[:queue_priority] = queue_priority if queue_priority

          result = @client.request(:patch, "/posts/#{id}",
            json: json_body,
            profile_group_id: profile_group_id,
            idempotency_key: idempotency_key
          )
        end

        Post.new(**result)
      end

      def publish_draft(id, profile_group_id: nil, idempotency_key: nil)
        result = @client.request(:post, "/posts/#{id}/publish",
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        Post.new(**result)
      end

      def stats(post_ids, profiles: nil, from: nil, to: nil)
        params = { post_ids: post_ids.is_a?(Array) ? post_ids.join(",") : post_ids }
        params[:profiles] = profiles.is_a?(Array) ? profiles.join(",") : profiles if profiles
        params[:from] = format_time(from) if from
        params[:to] = format_time(to) if to

        result = @client.request(:get, "/posts/stats", params: params)
        posts = (result[:data] || {}).each_with_object({}) do |(post_id, post_data), hash|
          hash[post_id.to_s] = PostStats.new(**post_data.transform_keys(&:to_sym))
        end
        StatsResponse.new(data: posts)
      end

      def delete(id, delete_on_platform: nil, profile_group_id: nil, idempotency_key: nil)
        params = {}
        params[:delete_on_platform] = delete_on_platform unless delete_on_platform.nil?
        result = @client.request(:delete, "/posts/#{id}",
          params: params.empty? ? nil : params,
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        DeleteResponse.new(**result)
      end

      def delete_on_platform(id, post_profile_id: nil, profile_id: nil, network: nil, profile_group_id: nil,
        idempotency_key: nil)
        json_body = {}
        json_body[:post_profile_id] = post_profile_id if post_profile_id
        json_body[:profile_id] = profile_id if profile_id
        json_body[:network] = network if network
        result = @client.request(:post, "/posts/#{id}/delete_on_platform",
          json: json_body.empty? ? nil : json_body,
          profile_group_id: profile_group_id,
          idempotency_key: idempotency_key
        )
        DeleteOnPlatformResponse.new(**result)
      end

      private

      def media_url(item)
        return item unless item.is_a?(Hash)

        item[:url] || item["url"]
      end

      # `cover_file` is a local path unless it's a base64 data URL, which the
      # API takes as a plain string.
      def local_cover_file_value?(key, value)
        key.to_s == "cover_file" && value.is_a?(String) && !value.start_with?("data:")
      end

      def local_cover_file?(platforms)
        return false unless platforms

        params_hash = platforms.is_a?(PlatformParams) ? platforms.to_h : platforms
        params_hash.any? do |_, platform_params|
          platform_params = platform_params.to_h if platform_params.is_a?(Model)
          platform_params.is_a?(Hash) && platform_params.any? { |k, v| local_cover_file_value?(k, v) }
        end
      end

      # Platform params as flat form fields; a local `cover_file` is attached
      # as a file.
      def append_platform_params(files, platforms)
        params_hash = platforms.is_a?(PlatformParams) ? platforms.to_h : platforms
        params_hash.each do |platform, platform_params|
          next if platform_params.nil?

          platform_params = platform_params.to_h if platform_params.is_a?(Model)
          platform_params.each do |key, value|
            next if value.nil?

            field = "platforms[#{platform}][#{key}]"
            if local_cover_file_value?(key, value)
              filename = File.basename(value)
              files << [field, filename, File.open(value, "rb"), mime_type_for(filename)]
            else
              append_form_value(files, field, value)
            end
          end
        end
      end

      def append_form_value(files, field, value)
        case value
        when Array
          # Hashes (e.g. Instagram user tags) get an index so their fields stay
          # grouped; Rails reads numeric keys back as an array.
          value.each_with_index do |item, i|
            nested = item.is_a?(Hash) || item.is_a?(Model)
            append_form_value(files, nested ? "#{field}[#{i}]" : "#{field}[]", item)
          end
        when Hash
          value.each { |k, v| append_form_value(files, "#{field}[#{k}]", v) unless v.nil? }
        when Model
          append_form_value(files, field, value.to_h)
        else
          files << [field, nil, value.to_s, "text/plain"]
        end
      end

      def format_time(value)
        return value if value.is_a?(String)
        value.iso8601
      end

      def mime_type_for(filename)
        case File.extname(filename).downcase
        when ".jpg", ".jpeg" then "image/jpeg"
        when ".png" then "image/png"
        when ".gif" then "image/gif"
        when ".webp" then "image/webp"
        when ".mp4" then "video/mp4"
        when ".mov" then "video/quicktime"
        when ".avi" then "video/x-msvideo"
        when ".webm" then "video/webm"
        else "application/octet-stream"
        end
      end
    end
  end
end
