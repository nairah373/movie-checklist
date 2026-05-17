class CreateMovies < ActiveRecord::Migration[8.1]
  def change
    create_table :movies do |t|
      t.string :title, null: false
      t.integer :year
      t.string :genre
      t.boolean :watched, null: false, default: false
      t.string :color

      t.timestamps
    end
  end
end
