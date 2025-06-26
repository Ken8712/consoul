class Echo < ApplicationRecord
  self.table_name = "echoes"
  
  belongs_to :user
  has_many :echo_lights, dependent: :destroy
  has_many :light_definitions, through: :echo_lights

  validates :title, presence: true
end