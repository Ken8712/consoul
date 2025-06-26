class Light < ApplicationRecord
  belongs_to :user
  belongs_to :light_definition

  validates :amount, numericality: { greater_than_or_equal_to: 0 }
  validates :light_definition_id, uniqueness: { scope: :user_id }
end