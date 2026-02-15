#===============================================================================
# Field Move Indicator (UI)
# Uses real field calc_damage pipeline for accurate boost/nerf arrows
#===============================================================================
class Battle
  def field_move_indicator(battler, move)
    multiplier = calculate_ui_field_multiplier(battler, move)
    return nil if multiplier.nil?
    return :boost if multiplier >= 1.1
    return :nerf if multiplier <= 0.9
    return nil
  end
  
  # Calculate the total field multiplier for a move
  def calculate_ui_field_multiplier(battler, move)
    return nil unless battler && move
    return 1.0 unless has_field?
    targets = battlers.select { |b| b && !b.fainted? && b.opposes?(battler) }
    return 1.0 unless move.damagingMove?
    return 1.0 if targets.empty?   
    target = targets.first
    type = move.pbCalcType(battler)
    mults = {
      :base_damage_multiplier    => 1.0,
      :attack_multiplier         => 1.0,
      :defense_multiplier        => 1.0,
      :final_damage_multiplier   => 1.0,
      :power_multiplier          => 1.0
    } 
    total_multiplier = 1.0
    field = @current_field
    if field.multipliers
      field.multipliers.each do |mult_data, calc_proc|
        base_mult = mult_data[1]
        next if base_mult == 1.0
        begin
          # Test if this multiplier applies
          applies = calc_proc&.call(battler, target, 1, move, type, move.baseDamage, mults)
          next unless applies
          
          # Apply the multiplier
          mult_type = mult_data[0]
          if mult_type == :defense_multiplier
            # Defense multiplier reduces effective damage
            total_multiplier *= (1.0 / base_mult)
          else
            total_multiplier *= base_mult
          end
        rescue => e
          # Skip multipliers that error
          next
        end
      end
    end
    
    return total_multiplier
  end
end

class Battle::Scene::FightMenu
  
  alias terrain_arrows_refresh_button_names refreshButtonNames
  def refreshButtonNames
    terrain_arrows_refresh_button_names
    imgPos = []
    icon_width = 26
    icon_height = 26
    moves = @battler.moves
    @buttons.each_with_index do |button, i|
      next if !@visibility["button_#{i}"]
      x = button.x - self.x + button.src_rect.width - icon_width
      y = button.y - self.y + button.src_rect.height - icon_height
      indicator = @battler.battle.field_move_indicator(@battler, moves[i])
      file = case indicator
      when :boost then "Graphics/UI/Battle/arrow_up"
      when :nerf then "Graphics/UI/Battle/arrow_down"
      else nil
      end
      imgPos.push([file, x, y]) if file
    end
    pbDrawImagePositions(@overlay.bitmap, imgPos)
  end
  
end
