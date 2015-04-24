module Jobs
  class PostWasSpam < Jobs::Base

    def execute(args)
      raise Discourse::InvalidParameters.new(:post_id) unless args[:post_id].present?

      return unless SiteSetting.akismet_enabled?

      post = Post.with_deleted.where(id: args[:post_id]).first
      return unless post.present?

      DiscourseAkismet.with_client do |client|
        client.submit_spam(nil, nil, DiscourseAkismet.args_for_post(post))
      end
    end
  end
end

