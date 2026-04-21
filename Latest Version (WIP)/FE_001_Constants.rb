#===============================================================================
# Field Effects Plugin — Constants and Battle Bridge
# File: FE_001_Constants.rb
#
# Provides:
#   • battle.fe      → FieldEffect::Proxy (counter / roll access)
#   • battle.FE      → current field symbol  (e.g. :VOLCANIC)
#   • All FE_* constants and roll tables
#   • Helper methods on Battle referenced by FIELDEFFECTS eval strings
#
# LOAD-ORDER SAFE: This file aliases ONLY methods defined in core v21.1.
# Methods from the FieldFramework plugin (has_field?, create_new_field, etc.)
# are never aliased here — they are handled in FE_002_Bridge.rb which loads
# after this file and after the framework has already registered those methods.
#===============================================================================

#===============================================================================
# LIGHTWEIGHT FIELD PROXY
# battle.fe returns this object. Tracks which field it was built for and
# self-invalidates if the field has changed — no create_new_field hook needed.
#===============================================================================
module FieldEffect
  class Proxy
    def initialize(battle)
      @battle   = battle
      @built_for = battle.current_field&.id
    end

    def stale?
      @battle.current_field&.id != @built_for
    end

    # Current active field symbol.
    def effect; @battle.current_field&.id || :INDOOR; end
    alias_method :FE, :effect

    # Named counter slots
    def counter;      @battle.get_field_counter(:c1);    end
    def counter=(v);  @battle.field_counters[:c1] = v;   end
    def counter2;     @battle.get_field_counter(:c2);    end
    def counter2=(v); @battle.field_counters[:c2] = v;   end
    def counter3;     @battle.get_field_counter(:c3);    end
    def counter3=(v); @battle.field_counters[:c3] = v;   end
    def counter4;     @battle.get_field_counter(:c4);    end
    def counter4=(v); @battle.field_counters[:c4] = v;   end

    # Terrain overlays
    def terrain_overlays
      { ELECTERRAIN: @battle.get_field_counter(:ol_electerrain),
        GRASSY:      @battle.get_field_counter(:ol_grassy),
        MISTY:       @battle.get_field_counter(:ol_misty),
        PSYTERRAIN:  @battle.get_field_counter(:ol_psyterrain) }
    end

    def roll; @battle.get_field_counter(:roll); end

    def getRoll(update_roll: true, maximize_roll: false)
      fid = @battle.current_field&.id
      case fid
      when :CRYSTALCAVERN
        choices = FE_CCROLLS
        idx     = @battle.get_field_counter(:roll) % choices.length
        result  = choices[idx]
        @battle.field_counters[:roll] = (idx + 1) % choices.length if update_roll
        result
      when :SHORTCIRCUIT
        choices = FE_SHORTCIRCUITROLLS
        if maximize_roll
          choices.last
        else
          idx    = @battle.get_field_counter(:roll) % choices.length
          result = choices[idx]
          @battle.field_counters[:roll] = (idx + 1) % choices.length if update_roll
          result
        end
      when :BIGTOP
        choices = FE_BIGTOPROLLS
        idx     = @battle.get_field_counter(:roll) % choices.length
        result  = choices[idx]
        @battle.field_counters[:roll] = (idx + 1) % choices.length if update_roll
        result
      when :GLITCH
        choices = FE_GLITCHROLLS
        idx     = @battle.get_field_counter(:roll) % choices.length
        result  = choices[idx]
        @battle.field_counters[:roll] = (idx + 1) % choices.length if update_roll
        result
      else
        1.0
      end
    end
  end
end

#===============================================================================
# BATTLE BRIDGE ACCESSORS
# Only aliases core v21.1 methods — NO framework method aliases here.
#===============================================================================
class Battle
  # Returns current field symbol. current_field is from the framework but is
  # called at runtime (not load time), so it's safe in a method body.
  def FE
    respond_to?(:current_field) ? (current_field&.id || :INDOOR) : :INDOOR
  end
  alias_method :fieldeffect, :FE

  # Returns proxy, auto-refreshed when field changes.
  def fe
    if @_fe_proxy.nil? || @_fe_proxy.stale?
      @_fe_proxy = FieldEffect::Proxy.new(self)
    end
    @_fe_proxy
  end

  # Safe wrapper — has_field? comes from the framework; guard with respond_to?.
  def has_field_effect?
    respond_to?(:has_field?) && has_field?
  end

  #-----------------------------------------------------------------------------
  # Helper predicates for FIELDEFFECTS :changeCondition eval strings.
  #-----------------------------------------------------------------------------
  def suncheck;       [:Sun, :HarshSun].include?(pbWeather);  end
  def raincheck;      [:Rain, :HeavyRain].include?(pbWeather); end
  def sandcheck;      pbWeather == :Sandstorm;                  end
  def hailcheck;      [:Hail, :Snow].include?(pbWeather);      end
  def noweathercheck; pbWeather == :None;                       end

  #-----------------------------------------------------------------------------
  # Delegate methods for FIELDEFFECTS :moveEffects eval strings.
  #-----------------------------------------------------------------------------
  def caveCollapse;              FieldEffect::PostMove.cave_collapse(self);   end
  def mistExplosion;             FieldEffect::PostMove.mist_explosion(self);  end
  def waterPollution;            FieldEffect::PostMove.water_pollution(self); end
  def eruptionChecker;           FieldEffect::PostMove.eruption_check(self);  end
  def ProgressiveFieldCheck(*a); FieldEffect::PostMove.progressive(self, *a); end
  def growField;                 FieldEffect::PostMove.grow_field(self);      end
  def reduceField;               FieldEffect::PostMove.reduce_field(self);    end
  def growDarkness;              FieldEffect::PostMove.grow_darkness(self);   end

  def seedCheck(battler); FieldEffect::Seeds.check(battler, self); end

  # Alias for create_new_field — used in move eval strings and scripts
  def setField(id); create_new_field(id) if respond_to?(:create_new_field); end

  # ICY Field — lay ice spikes (acts like Spikes on the opposing side)
  def iceSpikes
    side = @battlers[0]&.pbOwnSide
    return unless side
    side.effects[PBEffects::Spikes] = [side.effects[PBEffects::Spikes] + 1, 3].min
    pbDisplay(_INTL("Ice spikes were scattered on the field!"))
  end

  # MIRROR ARENA — shatter mirror when hit by listed moves (ends field)
  def mirrorShatter
    pbDisplay(_INTL("The mirrors shattered!"))
    create_new_field(:INDOOR) if respond_to?(:create_new_field)
  end

  # CONCERT VENUE — raise Hype by one stage
  def concertNoise
    @_concert_hype = [(@_concert_hype || 0) + 1, 3].min
  end

  # VOLCANIC TOP / WATER SURFACE — drop accuracy 1 stage for all active battlers
  def fieldAccuracyDrop
    allBattlers.each do |b|
      next if b.fainted?
      b.pbLowerStatStageBasic(:ACCURACY, 1)
    end
  end

  # CORRUPTED / DIMENSIONAL — check for a global ability (Neutralizing Gas etc.)
  def checkGlobalAbility(ability_sym)
    allBattlers.any? { |b| !b.fainted? && b.hasActiveAbility?(ability_sym) }
  end

  # Lay Stealth Rocks on the opposing side (used by EndureThenStealth seed effect)
  def pbStealth(idxBattler)
    battler = @battlers[idxBattler]
    return unless battler
    battler.pbOpposingSide.effects[PBEffects::StealthRock] = true
    pbDisplay(_INTL("Pointed stones float in the air around {1}!", battler.pbOpposing.pbThis(true)))
  end
end

#===============================================================================
# FIELD GROUPING ARRAYS
#===============================================================================
FE_FIRE_PASSIVE_FIELDS = %i[VOLCANIC SUPERHEATED INFERNAL VOLCANICTOP].freeze
FE_HAIL_PASSIVE_FIELDS = %i[ICY SNOWYMOUNTAIN].freeze
FE_EOR_PASSIVE_FIELDS  = (FE_FIRE_PASSIVE_FIELDS + FE_HAIL_PASSIVE_FIELDS +
                           %i[DESERT DRAGONSDEN UNDERWATER MURKWATERSURFACE
                              GRASSY MISTY]).freeze
FE_TWOTURNMOVES = %i[
  SOLARBEAM SOLARBLADE FLY BOUNCE DIG DIVE SKYDROP RAZORWIND
  SKYATTACK PHANTOMFORCE SHADOWFORCE METEORASSAULT METEORBEAM
  ICEBURN FREEZESHOCK GEOMANCY
].freeze

#===============================================================================
# ROLL TABLES
#===============================================================================
FE_CCROLLS           = %i[FIRE WATER GRASS PSYCHIC].freeze
FE_SHORTCIRCUITROLLS = [0.8, 1.5, 0.5, 1.2, 2.0].freeze
FE_BIGTOPROLLS       = [0.5, 1.0, 1.2, 1.5, 2.0].freeze
FE_GLITCHROLLS       = [0.0, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0].freeze

FE_SHORTCIRCUIT_MESSAGES = ["Bzzt.", "Bzzapp!", "Bzt...", "Bzap!", "BZZZAPP!"].freeze
FE_GLITCH_MESSAGES = [
  "A glitch absorbed all the damage!",
  "A glitch weakened the attack!",
  "A glitch weakened the attack slightly...",
  "",
  "A glitch strengthened the attack!",
  "A glitch boosted the attack!",
  "CRITICAL GLITCH!!!"
].freeze

FE_MAGIC_TIERS = {
  FIRE:     [[5,1.00,"Agi!"],[10,1.50,"Agirao!"],[14,2.00,"Agidyne!"]],
  ICE:      [[5,1.00,"Bufu!"],[10,1.50,"Bufula!"],[14,2.00,"Bufudyne!"]],
  ELECTRIC: [[5,1.00,"Zio!"],[10,1.50,"Zionga!"],[14,2.00,"Ziodyne!"]],
  FLYING:   [[5,1.00,"Garu!"],[10,1.50,"Garula!"],[14,2.00,"Garudyne!"]],
  WATER:    [[5,1.00,"Aqua!"],[10,1.50,"Aques!"],[14,2.00,"Aquadyne!"]],
  GROUND:   [[5,1.00,"Magna!"],[10,1.50,"Magnara!"],[14,2.00,"Magnadyne!"]],
  DARK:     [[5,1.30,"Mudo!"],[13,2.00,"Mudoon!"]],
  FAIRY:    [[5,1.30,"Hama!"],[13,2.00,"Hamaon!"]],
  PSYCHIC:  [[5,1.50,"The magical energy boosted the attack!"],
             [13,2.00,"The magical energy is overwhelming!"]],
}.freeze

FE_MAGIC_FIXED_MOVES = %i[
  ANCIENTPOWER MAGICALLEAF FLOWERTRICK POWERGEM AURASPHERE
  FOCUSBLAST HEX SECRETPOWER HIDDENPOWER
].freeze
