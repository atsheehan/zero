class Question < ActiveRecord::Base
  has_many :answers

  validates :title, presence: true
  validates :body, presence: true, length: { maximum: 50_000 }

  def self.recent
    order(created_at: :desc)
  end
end
