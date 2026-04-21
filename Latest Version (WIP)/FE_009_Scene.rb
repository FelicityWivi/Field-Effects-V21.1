#===============================================================================
# Field Effects Plugin — Scene and UI
# File: FE_009_Scene.rb
#
# Uses their 005_Battle.rb's Battle::Scene#set_fieldback implementation.
# We only need to ensure fieldback strings are provided on our field objects
# (done via @fieldback in Battle::Field_RejuvData) and add the field indicator
# UI (effectiveness icons, field name display in the fight menu).
#
# NO set_fieldback override — we rely on theirs completely to avoid conflict 10.
#===============================================================================

#===============================================================================
# FIELD INDICATOR IN FIGHT MENU
# Displays the active field name and a colour-coded effectiveness hint when
# the player opens the move selection menu.
#===============================================================================
class Battle::Scene
  # Called when the fight menu refreshes. Overlays the current field name
  # and a simple type-effectiveness hint on the bottom of the screen.
  def fe_refreshFieldIndicator
    return unless @battle.has_field?
    field_name = @battle.current_field.name
    return if field_name.nil? || field_name.empty?

    # Draw field name in a subtle overlay on the fight panel.
    # The exact sprite/bitmap calls depend on the UI framework in use;
    # this is a safe no-op if the sprite doesn't exist.
    spr = @sprites["fe_indicator"] rescue nil
    return unless spr

    bitmap = spr.bitmap
    return unless bitmap

    bitmap.clear
    bitmap.font.size  = 18
    bitmap.font.color = Color.new(255, 255, 255)
    bitmap.draw_text(4, 2, bitmap.width - 8, 20, field_name, 0)
  rescue
    # Silently ignore UI errors — the battle proceeds regardless.
  end
end

#===============================================================================
# MOVE EFFECTIVENESS ICON HELPER
# Returns a colour symbol (:red, :yellow, :green) representing how the
# currently highlighted move interacts with the active field.
# Intended for use by custom UI overlays.
#===============================================================================
module FieldEffect
  module Scene
    module_function

    def move_field_color(battle, move_id)
      return :white unless battle.has_field?
      data = FIELDEFFECTS[battle.FE] rescue nil
      return :white unless data

      # Check damageMods
      (data[:damageMods] || {}).each do |mult, moves|
        next unless Array(moves).include?(move_id)
        return :green if mult.to_f > 1.0
        return :red   if mult.to_f < 1.0 && mult.to_f > 0
        return :grey  if mult.to_f == 0
      end

      # Check statusMods (boosted status moves)
      return :green if Array(data[:statusMods]).include?(move_id)

      :white
    end
  end
end
