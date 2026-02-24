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

      def create(body, profiles:, media: nil, media_files: nil, platforms: nil,
                 scheduled_at: nil, draft: nil, profile_group_id: nil)
        if media_files && !media_files.empty?
          form_data = { "post[body]" => body }
          form_data["post[scheduled_at]"] = format_time(scheduled_at) if scheduled_at
          form_data["post[draft]"] = draft.to_s if !draft.nil?

          files = []

          profiles.each do |p|
            files << ["profiles[]", nil, p, "text/plain"]
          end

          media&.each do |m|
            files << ["media[]", nil, m, "text/plain"]
          end

          if platforms
            params_hash = platforms.is_a?(PlatformParams) ? platforms.to_h : platforms
            params_hash.each do |platform, platform_params|
              platform_params.each do |key, value|
                files << ["platforms[#{platform}][#{key}]", nil, value.to_s, "text/plain"]
              end
            end
          end

          media_files.each do |path|
            path = path.to_s
            filename = File.basename(path)
            content_type = mime_type_for(filename)
            io = File.open(path, "rb")
            files << ["media[]", filename, io, content_type]
          end

          result = @client.request(:post, "/posts",
            data: form_data,
            files: files,
            profile_group_id: profile_group_id
          )
        else
          post_payload = { body: body }
          post_payload[:scheduled_at] = format_time(scheduled_at) if scheduled_at
          post_payload[:draft] = draft unless draft.nil?

          json_body = { post: post_payload, profiles: profiles }
          json_body[:platforms] = platforms.is_a?(PlatformParams) ? platforms.to_h : platforms if platforms
          json_body[:media] = media if media

          result = @client.request(:post, "/posts", json: json_body, profile_group_id: profile_group_id)
        end

        Post.new(**result)
      end

      def publish_draft(id, profile_group_id: nil)
        result = @client.request(:post, "/posts/#{id}/publish", profile_group_id: profile_group_id)
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

      def delete(id, profile_group_id: nil)
        result = @client.request(:delete, "/posts/#{id}", profile_group_id: profile_group_id)
        DeleteResponse.new(**result)
      end

      private

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
