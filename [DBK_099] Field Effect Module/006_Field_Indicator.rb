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
    # Safety check - ensure multipliers exists and is a hash
    if field.multipliers && field.multipliers.is_a?(Hash) && !field.multipliers.empty?
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
  
  alias combined_indicators_refresh_button_names refreshButtonNames
  def refreshButtonNames
    combined_indicators_refresh_button_names
    return if !@overlay || !@overlay.bitmap
    
    imgPos = []
    icon_width = 26
    icon_height = 26
    padding = 8
    left_shift = 10   # how far left to move the effectiveness icon
    
    moves = @battler.moves
    target = @battler.battle.battlers.find { |b| b && b.opposes?(@battler) && !b.fainted? }
    
    @buttons.each_with_index do |button, i|
      next if !@visibility["button_#{i}"]
      move = moves[i]
      next if !move
      
      # Field indicator (bottom-right corner)
      begin
        field_x = button.x - self.x + button.src_rect.width - icon_width
        field_y = button.y - self.y + button.src_rect.height - icon_height
        indicator = @battler.battle.field_move_indicator(@battler, move)
        field_file = case indicator
        when :boost then "Graphics/UI/Battle/arrow_up"
        when :nerf then "Graphics/UI/Battle/arrow_down"
        else nil
        end
        imgPos.push([field_file, field_x, field_y]) if field_file && pbResolveBitmap(field_file)
      rescue => e
        # Silent fail for field indicator
      end
      
      # Effectiveness indicator (top-right corner)
      begin
        next unless target
        next unless move.damagingMove?

        eff_x = button.x - self.x + button.src_rect.width - icon_width - padding - left_shift
        eff_y = button.y - self.y + padding

        # Use pbCalcType to get the actual in-battle type (accounts for abilities/field effects)
        move_type = move.pbCalcType(@battler)
        next unless move_type && GameData::Type.exists?(move_type)

        # Strip nil/invalid entries that pbTypes(true) can return (e.g. Forest's Curse edge cases)
        target_types = target.pbTypes(true).select { |t| t && GameData::Type.exists?(t) }
        next if target_types.empty?

        # eff = nil MUST be set before calculate so a rescued error can't carry a stale value forward
        eff = nil
        effectiveness = Effectiveness.calculate(move_type, *target_types)
        eff = :super  if Effectiveness.super_effective?(effectiveness)
        eff = :resist if Effectiveness.not_very_effective?(effectiveness)
        eff = :immune if Effectiveness.ineffective?(effectiveness)
        next if !eff

        eff_file = case eff
        when :super  then "Graphics/UI/Battle/type_super"
        when :resist then "Graphics/UI/Battle/type_resist"
        when :immune then "Graphics/UI/Battle/type_immune"
        else nil
        end

        imgPos.push([eff_file, eff_x, eff_y]) if eff_file && pbResolveBitmap(eff_file)
      rescue => e
        # Silent fail for effectiveness indicator
      end
    end
    
    pbDrawImagePositions(@overlay.bitmap, imgPos) if imgPos.any?
  end
  
end
