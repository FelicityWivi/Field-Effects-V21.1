#===============================================================================
# Field Move Indicator (UI)
# Uses real field calc_damage pipeline for accurate boost/nerf arrows
# Updated for Unified Field System
#===============================================================================
class Battle
  def field_move_indicator(battler, move)
    return nil unless battler && move
    
    begin
      multiplier = calculate_ui_field_multiplier(battler, move)
      return nil if multiplier.nil?
      
      # Debug output
      if $DEBUG && multiplier != 1.0
        puts "Field Indicator: #{move.name} = #{multiplier}x"
      end
      
      return :boost if multiplier >= 1.1
      return :nerf if multiplier <= 0.9
      return nil
    rescue => e
      puts "Field indicator error: #{e.message}" if $DEBUG
      puts e.backtrace.first(3) if $DEBUG
      return nil
    end
  end
  
  # Calculate the total field multiplier for a move
  def calculate_ui_field_multiplier(battler, move)
    return nil unless battler && move
    return 1.0 unless @current_field
    return 1.0 if @current_field.is_base? # Skip if INDOOR field
    return 1.0 unless move.damagingMove?
    
    targets = battlers.select { |b| b && !b.fainted? && b.opposes?(battler) }
    return 1.0 if targets.empty?
    
    target = targets.first
    type = move.pbCalcType(battler)
    
    # Get field data
    field_data = @current_field.data
    return 1.0 unless field_data
    
    total_multiplier = 1.0
    attacker = battler
    opponent = target
    
    # Check move-specific damage modifiers
    if field_data[:damageMods]
      field_data[:damageMods].each do |multiplier, moves|
        next if multiplier == 1.0
        if moves.include?(move.id)
          total_multiplier *= multiplier
          break
        end
      end
    end
    
    # Check type-based damage modifiers
    if field_data[:typeBoosts]
      field_data[:typeBoosts].each do |multiplier, types|
        next if multiplier == 1.0
        next unless types.include?(type)
        
        # Check type condition if it exists
        if field_data[:typeCondition] && field_data[:typeCondition][type]
          condition = field_data[:typeCondition][type]
          begin
            next unless eval(condition)
          rescue => e
            # Skip if condition fails
            puts "Field indicator condition error: #{e.message}" if $DEBUG
            next
          end
        end
        
        total_multiplier *= multiplier
        break
      end
    end
    
    return total_multiplier
  end
end

class Battle::Scene::FightMenu
  
  alias terrain_arrows_refresh_button_names refreshButtonNames
  def refreshButtonNames
    terrain_arrows_refresh_button_names
    
    return unless @battler && @battler.battle && @battler.battle.respond_to?(:field_move_indicator)
    
    begin
      imgPos = []
      icon_width = 26
      icon_height = 26
      moves = @battler.moves
      
      @buttons.each_with_index do |button, i|
        next if !@visibility["button_#{i}"]
        next unless moves[i]
        
        x = button.x - self.x + button.src_rect.width - icon_width
        y = button.y - self.y + button.src_rect.height - icon_height
        
        indicator = @battler.battle.field_move_indicator(@battler, moves[i])
        
        file = case indicator
        when :boost then "Graphics/UI/Battle/arrow_up"
        when :nerf then "Graphics/UI/Battle/arrow_down"
        else nil
        end
        
        if file
          # Check if file exists before trying to draw
          if pbResolveBitmap(file)
            imgPos.push([file, x, y])
          elsif $DEBUG
            puts "Field indicator graphic not found: #{file}"
          end
        end
      end
      
      pbDrawImagePositions(@overlay.bitmap, imgPos) if imgPos.any?
    rescue => e
      puts "Field indicator UI error: #{e.message}" if $DEBUG
      puts e.backtrace.first(3) if $DEBUG
    end
  end
end

#===============================================================================
# USAGE NOTES
#===============================================================================

=begin

WHAT THIS DOES
==============

Shows arrows on move buttons to indicate if the current field boosts or nerfs the move:
- ↑ Green arrow = Move is boosted (1.1x or higher)
- ↓ Red arrow = Move is nerfed (0.9x or lower)
- No arrow = Normal damage (0.91x - 1.09x)

HOW IT WORKS
============

1. Checks if a field is active
2. Looks up move and type boosts from FIELDEFFECTS data
3. Calculates total multiplier
4. Shows appropriate arrow

EXAMPLES
========

On VOLCANIC field:
- Fire-type moves show ↑ (1.5x boost)
- Grass/Ice-type moves show ↓ (0.5x nerf)
- Flamethrower shows ↑ (boosted)
- Normal-type moves show no arrow

On SAHARA field:
- Physical moves show ↓ (0.8x nerf)
- Water moves show ↓ (0.8x nerf)
- Bug/Fire/Ground/Rock moves show ↑ (1.3x boost)

On ENCHANTEDFOREST:
- Fairy/Grass/Poison moves show ↑ (1.5x boost)
- Dark moves show ↑ (1.3x boost)
- Magical moves (Hex, Mystical Fire) show ↑ (1.5x boost)

REQUIRED GRAPHICS
=================

You need these image files in Graphics/UI/Battle/:
- arrow_up.png (green up arrow, 26x26 pixels)
- arrow_down.png (red down arrow, 26x26 pixels)

If you don't have these graphics, the system will just not show arrows
(no error will occur).

CUSTOMIZATION
=============

Threshold for showing arrows:
```ruby
return :boost if multiplier >= 1.1  # Change 1.1 to adjust
return :nerf if multiplier <= 0.9   # Change 0.9 to adjust
```

Arrow position:
```ruby
x = button.x - self.x + button.src_rect.width - icon_width
y = button.y - self.y + button.src_rect.height - icon_height
# Adjust icon_width and icon_height to move position
```

Arrow size:
```ruby
icon_width = 26   # Change to resize
icon_height = 26  # Change to resize
```

TROUBLESHOOTING
===============

Arrows not showing:
1. Check that Graphics/UI/Battle/arrow_up.png exists
2. Check that Graphics/UI/Battle/arrow_down.png exists
3. Verify field is active: @battle.has_field?
4. Check move is damaging: move.damagingMove?

Wrong arrows showing:
1. Check FIELDEFFECTS data for current field
2. Verify :damageMods and :typeBoosts are correct
3. Test multiplier calculation in debug:
   ```ruby
   mult = @battle.calculate_ui_field_multiplier(battler, move)
   puts "Multiplier: #{mult}"
   ```

Arrows in wrong position:
1. Adjust icon_width and icon_height values
2. Modify x and y calculation

COMPATIBILITY
=============

Works with:
- Unified Field System (FIELDEFFECTS.rb)
- Pokemon Essentials v20+
- All 45 included fields

Does NOT work with:
- Old field system (with @multipliers)
- If you see errors about "multipliers", this file needs updating

=end
