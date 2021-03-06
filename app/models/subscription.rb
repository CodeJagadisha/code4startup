# == Schema Information
#
# Table name: subscriptions
#
#  id         :integer          not null, primary key
#  project_id :integer
#  user_id    :integer
#  created_at :datetime         not null
#  updated_at :datetime         not null
#  deleted_at :datetime
#
# Indexes
#
#  index_subscriptions_on_deleted_at  (deleted_at)
#  index_subscriptions_on_project_id  (project_id)
#  index_subscriptions_on_user_id     (user_id)
#
# Foreign Keys
#
#  fk_rails_933bdff476  (user_id => users.id)
#  fk_rails_d0c8bda804  (project_id => projects.id)
#

class Subscription < ActiveRecord::Base
  acts_as_paranoid
  belongs_to :project
  belongs_to :user

  def self.create_subscription(session, current_user)
    self.create(project_id: session, user_id: current_user.id)
    session = nil
  end
end
