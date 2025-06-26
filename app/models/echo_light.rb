class EchoLight < ApplicationRecord
  belongs_to :echo
  belongs_to :light_definition

  validates :amount, numericality: { greater_than: 0 }
  validates :light_definition_id, uniqueness: { scope: :echo_id }
end