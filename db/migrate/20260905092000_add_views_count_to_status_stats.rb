# frozen_string_literal: true

class AddViewsCountToStatusStats < ActiveRecord::Migration[8.1]
  def change
    add_column :status_stats, :views_count, :bigint, null: false, default: 0
    add_check_constraint :status_stats, 'views_count >= 0', name: :status_stats_views_count_nonnegative, validate: false
  end
end
