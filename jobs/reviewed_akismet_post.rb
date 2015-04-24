module Jobs
  class ReviewedAkismetPost < Jobs::Base

    def execute(args)
      raise Discourse::InvalidParameters.new(:queued_post_id) unless args[:queued_post_id].present?
      return unless SiteSetting.akismet_enabled?

      qp = QueuedPost.where(id: args[:queued_post_id]).first
      return unless qp.present?

      DiscourseAkismet.with_client do |client|
        if qp.state == QueuedPost.states[:rejected]
          client.submit_spam(*DiscourseAkismet.args_for_queued_post(qp))
        elsif qp.state == QueuedPost.states[:approved]
          client.submit_ham(*DiscourseAkismet.args_for_queued_post(qp))
        end
      end
    end
  end
end

