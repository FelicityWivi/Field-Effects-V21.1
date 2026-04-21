#===============================================================================
# Field Effects Plugin — Advanced Mechanics
# File: FE_010_AdvancedMechanics.rb
#
# Implements the five mechanics that required deeper game system knowledge:
#
#  1. CHESS BOARD — Chess piece role assignment and all per-role effects
#       Roles assigned at battle start based on party criteria (image spec).
#       Precedence: Queen > Pawn > King > Rook/Bishop/Knight
#
#  2. ALWAYS-ACTIVE ABILITIES — Blaze/Overgrow/Swarm on specific fields
#       The framework's :ability_activation hook already handles Overgrow/Swarm.
#       We register the hook for each field + add a direct pbCalcDamageMultipliers
#       patch for Blaze (which doesn't use the hook in v21.1).
#
#  3. EFFECT SPORE DOUBLED — BEWITCHED field raises chance 30% → 60%
#       An additional OnBeingHit handler fires at the same rate as the base
#       one, effectively doubling the chance (combined ≈ 51%, close to 60%).
#       A second attempt is made with the remaining gap to reach 60% exactly.
#
#  4. GORILLA TACTICS MISS RECOIL — ROCKY field doubles crash damage
#       CrashDamageIfFailsUnusableInGravity#pbCrashDamage is aliased to
#       double the HP loss when the user has Gorilla Tactics on Rocky.
#
#  5. GULP MISSILE / SCHOOLING form maintenance — WATERSURFACE field
#       An EOR hook keeps Wishiwashi in School form and Cramorant in
#       Arrokuda/Gorging form while they're on the Water Surface field.
#===============================================================================

#===============================================================================
# 1. CHESS BOARD — PIECE ROLE SYSTEM
#
# Roles are determined once per side at battle start and stored in
# @chess_pieces[side][party_index] = :pawn/:rook/:bishop/:knight/:queen/:king
# Active battlers look up their piece via their party position.
#
# Role determination (from the spec image, highest priority first):
#   Queen  — occupies the final slot of the team (1 per team max; overrides all)
#   Pawn   — sent out on the very first turn of battle (overrides King/Rook/Bishop/Knight)
#   King   — holds King's Rock or Razor Fang, OR has the lowest max HP (1 max; overrides Rook/Bishop/Knight)
#   Knight — highest stat is Speed
#   Rook   — highest stat is Defense or Special Defense
#   Bishop — highest stat is Attack or Special Attack
#===============================================================================

module ChessBoard
  ROLES = %i[queen pawn king rook bishop knight].freeze

  ROLE_MESSAGES = {
    pawn:   "%s became a Pawn and stormed up the board!",
    rook:   "%s became a Rook and took the open file!",
    bishop: "%s became a Bishop and took the diagonal!",
    knight: "%s became a Knight and readied its position!",
    queen:  "%s became a Queen and was placed on the center of the board!",
    king:   "%s became a King and exposed itself!"
  }.freeze

  module_function

  #-----------------------------------------------------------------------------
  # Assign chess pieces for both sides. Called when the Chess Board activates.
  # Returns a Hash: { side => { party_index => role_sym } }
  #-----------------------------------------------------------------------------
  def assign_all(battle)
    pieces = {}
    [0, 1].each { |side| pieces[side] = assign_side(battle, side) }
    battle.instance_variable_set(:@chess_pieces, pieces)
    pieces
  end

  def assign_side(battle, side)
    party = battle.pbParty(side)
    return {} unless party && !party.empty?

    alive_indices = party.each_index.select { |i| party[i] && party[i].hp > 0 }
    return {} if alive_indices.empty?

    result      = {}
    queen_set   = false
    king_set    = false
    pawn_index  = alive_indices.first   # first party slot = Pawn (sent out first)

    # Queen: last living slot (highest priority — overrides all other roles)
    queen_idx = alive_indices.last
    result[queen_idx] = :queen
    queen_set = true

    # King: King's Rock/Razor Fang holder, or lowest max HP (excluding Queen)
    candidate_indices = alive_indices.reject { |i| result[i] == :queen }
    kings_rock = candidate_indices.find { |i|
      item = party[i].item
      item == :KINGSROCK || item == :RAZORFANG
    }

    if kings_rock
      result[kings_rock] = :king
      king_set = true
    else
      lowest_hp_idx = candidate_indices.min_by { |i| party[i].totalhp }
      if lowest_hp_idx
        result[lowest_hp_idx] = :king
        king_set = true
      end
    end

    # Pawn: first slot (overrides Rook/Bishop/Knight but NOT King/Queen)
    if !result[pawn_index]
      result[pawn_index] = :pawn
    end

    # Rook / Bishop / Knight: based on each Pokémon's highest base stat
    alive_indices.each do |i|
      next if result[i]   # already assigned
      pkmn   = party[i]
      stats  = { atk: pkmn.attack, spatk: pkmn.spatk,
                 def: pkmn.defense, spdef: pkmn.spdef,
                 spd: pkmn.speed }
      highest = stats.max_by { |_, v| v }.first
      result[i] = case highest
                  when :spd           then :knight
                  when :def, :spdef   then :rook
                  else                     :bishop
                  end
    end

    result
  end

  #-----------------------------------------------------------------------------
  # Return the chess piece for a battler, or nil if Chess Board isn't active.
  #-----------------------------------------------------------------------------
  def piece_for(battler, battle)
    return nil unless battle.FE == :CHESS
    pieces = battle.instance_variable_get(:@chess_pieces) || {}
    side_pieces = pieces[battler.index & 1] || {}   # side 0 = player, 1 = opponent
    # Map battler to their party position
    party_idx = battle.pbPartyOrder(battler.index)&.first
    return nil unless party_idx
    side_pieces[party_idx]
  end

  #-----------------------------------------------------------------------------
  # Announce a battler's role when they switch in on the Chess Board.
  #-----------------------------------------------------------------------------
  def announce_role(battler, battle)
    piece = piece_for(battler, battle)
    return unless piece
    msg = ROLE_MESSAGES[piece]
    return unless msg
    battle.pbDisplay(_INTL(msg % battler.pbThis))
  end
end

# ── Assign pieces when Chess Board field is created ──────────────────────────
module Battle::ChessBoardHook
  def create_new_field(id, *args)
    super
    ChessBoard.assign_all(self) if id.to_sym == :CHESS
  end
end
Battle.prepend(Battle::ChessBoardHook)

# ── Announce role and apply switch-in effects when a battler enters ──────────
class Battle
  alias_method :chess_original_pbOnBattlerEnteringBattle, :pbOnBattlerEnteringBattle if method_defined?(:pbOnBattlerEnteringBattle)

  def pbOnBattlerEnteringBattle(idxBattler, *args)
    respond_to?(:chess_original_pbOnBattlerEnteringBattle) ?
      chess_original_pbOnBattlerEnteringBattle(idxBattler, *args) : super
    return unless self.FE == :CHESS
    battler = @battlers[idxBattler]
    return unless battler && !battler.fainted?

    ChessBoard.announce_role(battler, self)

    piece = ChessBoard.piece_for(battler, self)
    case piece
    when :pawn
      # Focus Sash effect — survives one hit from full HP
      battler.effects[PBEffects::Endure] = true if battler.hp == battler.totalhp
    when :rook
      battler.pbRaiseStatStageBasic(:DEFENSE, 1) if battler.pbCanRaiseStatStage?(:DEFENSE, battler)
      battler.pbRaiseStatStageBasic(:SPECIAL_DEFENSE,   1) if battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE,   battler)
    when :bishop
      battler.pbRaiseStatStageBasic(:ATTACK, 1) if battler.pbCanRaiseStatStage?(:ATTACK, battler)
      battler.pbRaiseStatStageBasic(:SPECIAL_ATTACK,  1) if battler.pbCanRaiseStatStage?(:SPECIAL_ATTACK,  battler)
    when :queen
      battler.pbRaiseStatStageBasic(:DEFENSE, 1) if battler.pbCanRaiseStatStage?(:DEFENSE, battler)
      battler.pbRaiseStatStageBasic(:SPECIAL_DEFENSE,   1) if battler.pbCanRaiseStatStage?(:SPECIAL_DEFENSE,   battler)
    end
    pbCommonAnimation("StatUp", battler, nil) if %i[rook bishop queen].include?(piece)
  end
end

# ── King: +1 priority on all moves ──────────────────────────────────────────
class Battle::Move
  alias_method :chess_king_original_pbPriority, :pbPriority

  def pbPriority(user)
    base = chess_king_original_pbPriority(user)
    return base unless @battle.FE == :CHESS
    piece = ChessBoard.piece_for(user, @battle)
    piece == :king ? base + 1 : base
  end
end

# ── Queen: all damage ×1.5 ──────────────────────────────────────────────────
# ── Knight: ×3 vs Queen target, ×1.25 when targeting both foes ─────────────
class Battle::Move
  alias_method :chess_roles_original_pbCalcDamageMultipliers, :pbCalcDamageMultipliers

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    chess_roles_original_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    return unless @battle.FE == :CHESS

    user_piece   = ChessBoard.piece_for(user,   @battle)
    target_piece = ChessBoard.piece_for(target, @battle)

    case user_piece
    when :queen
      multipliers[:power_multiplier] *= 1.5

    when :knight
      if target_piece == :queen
        multipliers[:power_multiplier] *= 3.0
      elsif numTargets > 1   # doubles move hitting both opponents
        multipliers[:power_multiplier] *= 1.25
      end
    end
  end
end

#===============================================================================
# 2. ALWAYS-ACTIVE ABILITIES (Blaze/Overgrow/Swarm)
#
# The framework's :ability_activation proc returns an array of abilities that
# should be considered "always on" for the current field. Overgrow and Swarm
# already check this hook in v21.1. Blaze requires a direct patch.
#
# We extend Battle::Field_RejuvData#register_set_field (via a module patch)
# to also register :ability_activation on the appropriate fields.
#===============================================================================

# Fields where each ability fires unconditionally.
FE_ABILITY_ALWAYS_ACTIVE = {
  VOLCANIC:    %i[BLAZE FLASHFIRE FLAREBOOST],
  VOLCANICTOP: %i[BLAZE FLASHFIRE],
  GRASSY:      %i[OVERGROW GRASSPELT LEAFGUARD],
  FOREST:      %i[OVERGROW SWARM GRASSPELT LEAFGUARD],
  CANYON:      %i[OVERGROW SWARM ROCKHEAD STURDY STEADFAST GORILLATACTICS],
  SWAMP:       %i[SWARM],
  CAVE:        %i[ROCKHEAD],
  ROCKY:       %i[ROCKHEAD STURDY STEADFAST GORILLATACTICS],
  CORROSIVE:   %i[POISONHEAL TOXICBOOST MERCILESS CORROSION],
  CORRUPTED:   %i[POISONHEAL TOXICBOOST MERCILESS CORROSION],
  DESERT:      %i[SOLARPOWER CHLOROPHYLL SANDRUSH SANDFORCE SANDVEIL],
  BEACH:       %i[SANDRUSH SANDFORCE SANDVEIL],
  WATERSURFACE:%i[SWIFTSWIM HYDRATION TORRENT SURGESURFER WATERVEIL DRYSKIN WATERABSORB WATERCOMPACTION SCHOOLING],
  UNDERWATER:  %i[SWIFTSWIM HYDRATION TORRENT SURGESURFER WATERVEIL DRYSKIN WATERABSORB],
  MURKWATERSURFACE:%i[POISONHEAL TOXICBOOST MERCILESS SWIFTSWIM SURGESURFER WATERCOMPACTION SCHOOLING],
}.freeze

# Extend FE_RejuvDataMethods to register :ability_activation on fields
# that need always-active abilities. This patches the module that gets
# included into Battle::Field_RejuvData when the class is created lazily,
# so no direct reference to Battle::Field_RejuvData is needed at parse time.
module FE_RejuvDataMethods
  alias_method :fe_adv_original_register_set_field, :register_set_field

  def register_set_field(data)
    fe_adv_original_register_set_field(data)
    always_active = FE_ABILITY_ALWAYS_ACTIVE[@id] || []
    return if always_active.empty?

    @effects[:ability_activation] = proc { |*args|
      always_active
    }
  end
end

# Direct patch for BLAZE (doesn't use :ability_activation in v21.1 by default).
class Battle::Move
  alias_method :fe_blaze_original_pbCalcDamageMultipliers, :pbCalcDamageMultipliers

  def pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    fe_blaze_original_pbCalcDamageMultipliers(user, target, numTargets, type, baseDmg, multipliers)
    return unless type == :FIRE && user.hasActiveAbility?(:BLAZE)
    return if user.hp <= user.totalhp / 3   # already triggered by base handler
    return unless FE_ABILITY_ALWAYS_ACTIVE[@battle.FE]&.include?(:BLAZE)
    # Field forces Blaze active at full HP too
    multipliers[:attack_multiplier] *= 1.5
  end
end

#===============================================================================
# 3. EFFECT SPORE DOUBLED — BEWITCHED field
#
# Base handler: 30% chance. On Bewitched we want 60%.
# Strategy: add a second handler that fires with 3/7 ≈ 42.9% chance.
# Combined: P(at least one fires) = 1 − (0.7 × 0.571) = 1 − 0.4 = 0.6 = 60%. ✓
#===============================================================================
Battle::AbilityEffects::OnBeingHit.add(:EFFECTSPORE_BEWITCHED,
  proc { |ability, user, target, move, battle|
    next unless battle.FE == :BEWITCHED
    next unless target.hasActiveAbility?(:EFFECTSPORE)
    next unless move.pbContactMove?(user)
    next unless user && !user.fainted?
    # Fire with 3/7 chance — combined with the base 30% gives ~60% total
    next if battle.pbRandom(7) >= 3
    r = battle.pbRandom(3)
    next if r == 0 && user.asleep?
    next if r == 1 && user.poisoned?
    next if r == 2 && user.paralyzed?
    battle.pbShowAbilitySplash(target)
    if user.affectedByPowder?(Battle::Scene::USE_ABILITY_SPLASH) &&
       user.affectedByContactEffect?(Battle::Scene::USE_ABILITY_SPLASH)
      case r
      when 0
        user.pbSleep(nil)     if user.pbCanSleep?(target, Battle::Scene::USE_ABILITY_SPLASH)
      when 1
        user.pbPoison(target) if user.pbCanPoison?(target, Battle::Scene::USE_ABILITY_SPLASH)
      when 2
        user.pbParalyze(target) if user.pbCanParalyze?(target, Battle::Scene::USE_ABILITY_SPLASH)
      end
    end
    battle.pbHideAbilitySplash(target)
  }
)

#===============================================================================
# 4. GORILLA TACTICS MISS RECOIL — ROCKY field
#
# Rocky Field: if a Pokémon with Gorilla Tactics uses a crash-damage move
# (High Jump Kick, Jump Kick) and misses/fails, it takes double crash damage.
# Rock Head on Rocky: crash damage is completely negated.
#===============================================================================
class Battle::Move::CrashDamageIfFailsUnusableInGravity
  alias_method :fe_rocky_crash_original, :pbCrashDamage

  def pbCrashDamage(user)
    # Rock Head: no crash damage on Rocky field
    if @battle.FE == :ROCKY && user.hasActiveAbility?(:ROCKHEAD)
      @battle.pbDisplay(_INTL("{1}'s Rock Head absorbed the crash!", user.pbThis))
      return
    end

    # Gorilla Tactics: double crash damage on Rocky field
    if @battle.FE == :ROCKY && user.hasActiveAbility?(:GORILLATACTICS)
      return unless user.takesIndirectDamage?
      @battle.pbDisplay(_INTL("{1} kept going and crashed hard!", user.pbThis))
      @battle.scene.pbDamageAnimation(user)
      user.pbReduceHP(user.totalhp, false)   # full HP loss (×2 of normal ½ = full)
      user.pbItemHPHealCheck
      user.pbFaint if user.fainted?
      return
    end

    fe_rocky_crash_original(user)
  end
end

#===============================================================================
# 5. GULP MISSILE / SCHOOLING — WATERSURFACE field
#
# On the Water Surface field:
#   Wishiwashi (Schooling): stays in School form (form 1) as long as HP > 25%.
#     Normally only activates via HP check in pbCheckForm.
#     We run the same check each EOR and on switch-in.
#
#   Cramorant (Gulp Missile): stays in Arrokuda form (form 1) at >50% HP or
#     Pikachu form (form 2) at ≤50% HP. Reverts to form 0 when HP is restored.
#
# Both are maintained via the existing EOR ability hook in FE_007.
#===============================================================================
module FieldEffect
  module EOR
    module_function

    # Called from process_ability_eor when field is :WATERSURFACE
    def maintain_water_forms(battler, battle)
      # Wishiwashi — Schooling
      if battler.isSpecies?(:WISHIWASHI) && battler.hasActiveAbility?(:SCHOOLING)
        if battler.level >= 20 && battler.hp > battler.totalhp / 4
          battler.pbChangeForm(1, _INTL("{1} formed a school!", battler.pbThis)) if battler.form != 1
        else
          battler.pbChangeForm(0, _INTL("{1} stopped schooling!", battler.pbThis)) if battler.form != 0
        end
      end

      # Cramorant — Gulp Missile: maintain loaded form
      if battler.isSpecies?(:CRAMORANT) && battler.hasActiveAbility?(:GULPMISSILE)
        if battler.form == 0 && battler.hp > 0
          # Restore appropriate loaded form based on HP
          new_form = (battler.hp > battler.totalhp / 2) ? 1 : 2
          battler.pbChangeForm(new_form, nil)
        end
      end
    end
  end
end

# Hook maintain_water_forms into EOR ability processing.
# We extend the existing process_ability_eor via a simple wrapper.
module FieldEffect
  module EOR
    class << self
      alias_method :adv_original_process_ability_eor, :process_ability_eor

      def process_ability_eor(battler, battle, field_id)
        adv_original_process_ability_eor(battler, battle, field_id)
        maintain_water_forms(battler, battle) if field_id == :WATERSURFACE
      end
    end
  end
end

# Also maintain forms on switch-in to Water Surface.
class Battle
  alias_method :fe_water_forms_original_pbOnBattlerEnteringBattle, :pbOnBattlerEnteringBattle

  def pbOnBattlerEnteringBattle(idxBattler, *args)
    fe_water_forms_original_pbOnBattlerEnteringBattle(idxBattler, *args)
    return unless self.FE == :WATERSURFACE
    battler = @battlers[idxBattler]
    return unless battler && !battler.fainted?
    FieldEffect::EOR.maintain_water_forms(battler, self)
  end
end
