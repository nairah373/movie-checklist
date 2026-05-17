module ApplicationHelper
  def lighten_color(hex, amount: 0.4)
    return "#cccccc" if hex.blank?
    hex = hex.delete_prefix("#")
    r, g, b = hex.scan(/../).map { |c| c.to_i(16) }
    mix = ->(c) { [(c + (255 - c) * amount).round, 255].min }
    format("#%02x%02x%02x", mix.call(r), mix.call(g), mix.call(b))
  end
end
