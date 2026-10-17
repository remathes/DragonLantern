// Dragon's Lantern - a Dragon's Dogma style belt lantern for The Witcher 3 Remastered (5.0).
//
// Behaviour:
//   * Owning the "DDL Belt Lantern" item hangs the lantern on Geralt's hip.
//   * Using it from a quickslot lights / douses it (it never goes to his hand).
//   * A lit lantern burns oil. Carried "DDL Lantern Oil" flasks refill it
//     automatically when it runs dry, or you can top up by using the lantern
//     while it is unlit with an empty reservoir.
//   * Swimming or diving puts the flame out; you relight it yourself.
//   * Hidden in cutscenes and dialogue, swings as Geralt moves.
//
// Entity contract (built in REDkit, see docs/REDKIT_ASSET_GUIDE.md):
//   mods\dragons_lantern\ddl_lantern.w2ent, a copy of the vanilla
//   items\work\lantern_dwarf_01\lantern_dwarf_01.w2ent, keeping its names:
//     "lantern_dwarf_base"     rig component; the script moves/rotates it (carrier)
//     "lantern_dwarf"          body mesh, skinned to / attached to the carrier
//     "CPointLightComponent0"  the light, attached to the carrier in the editor
//     "hinge_lantern_dwarf"    vanilla dangle; disabled so it can't fight the swing
//     "ddl_flame"              optional extra flame / glow mesh

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

function DDL_Group() : name { return 'DDLantern'; }
function DDL_LanternItem() : name { return 'DDL Belt Lantern'; }
function DDL_OilItem() : name { return 'DDL Lantern Oil'; }
function DDL_Template() : string { return "mods\dragons_lantern\ddl_lantern.w2ent"; }
function DDL_CarrierName() : string { return "lantern_dwarf_base"; }
function DDL_BodyName() : string { return "lantern_dwarf"; }
function DDL_LightName() : string { return "CPointLightComponent0"; }
function DDL_HingeName() : string { return "hinge_lantern_dwarf"; }
function DDL_FlameName() : string { return "ddl_flame"; }

// Pelvis bone axes on Geralt's rig: -X forward, -Y up, -Z his left.
function DDL_AttachBone() : name { return 'pelvis'; }

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

@addField(W3PlayerWitcher) saved var ddlLit : bool;
@addField(W3PlayerWitcher) saved var ddlOilMinutes : float;     // game minutes of burn left
@addField(W3PlayerWitcher) saved var ddlInitialized : bool;

@addField(W3PlayerWitcher) var ddlEntity : CEntity;
@addField(W3PlayerWitcher) var ddlCarrier : CComponent;
@addField(W3PlayerWitcher) var ddlBody : CDrawableComponent;
@addField(W3PlayerWitcher) var ddlPoint : CLightComponent;
@addField(W3PlayerWitcher) var ddlFlame : CDrawableComponent;
@addField(W3PlayerWitcher) var ddlShown : bool;
@addField(W3PlayerWitcher) var ddlFlameOn : bool;
@addField(W3PlayerWitcher) var ddlLastGameSeconds : int;
@addField(W3PlayerWitcher) var ddlLastToggleAt : float;
@addField(W3PlayerWitcher) var ddlWasInWater : bool;
@addField(W3PlayerWitcher) var ddlAutoReady : bool;
@addField(W3PlayerWitcher) var ddlSettingsSeen : string;
@addField(W3PlayerWitcher) var ddlWasEquipped : bool;
@addField(W3PlayerWitcher) var ddlWasNight : bool;
@addField(W3PlayerWitcher) var ddlSpawnRetryAt : float;
@addField(W3PlayerWitcher) var ddlBasePosition : Vector;
@addField(W3PlayerWitcher) var ddlBaseRotation : EulerAngles;

// Live tuning from the console (ddlpos / ddlrot). Centimetres and degrees,
// relative to the chosen position preset; saved so they survive reloads.
@addField(W3PlayerWitcher) saved var ddlTuneForward : float;
@addField(W3PlayerWitcher) saved var ddlTuneUp : float;
@addField(W3PlayerWitcher) saved var ddlTuneOut : float;
@addField(W3PlayerWitcher) saved var ddlTunePitch : float;
@addField(W3PlayerWitcher) saved var ddlTuneYaw : float;
@addField(W3PlayerWitcher) saved var ddlTuneRoll : float;
@addField(W3PlayerWitcher) saved var ddlTwistPitch : float;
@addField(W3PlayerWitcher) saved var ddlTwistYaw : float;
@addField(W3PlayerWitcher) saved var ddlTwistRoll : float;

// Pendulum: two angles (degrees) and their rates, driven by pelvis acceleration.
@addField(W3PlayerWitcher) var ddlSwingFwd : float;
@addField(W3PlayerWitcher) var ddlSwingSide : float;
@addField(W3PlayerWitcher) var ddlSwingFwdRate : float;
@addField(W3PlayerWitcher) var ddlSwingSideRate : float;
@addField(W3PlayerWitcher) var ddlSwingPrevPos : Vector;
@addField(W3PlayerWitcher) var ddlSwingPrevVel : Vector;
@addField(W3PlayerWitcher) var ddlSwingReady : bool;
@addField(W3PlayerWitcher) var ddlSwingRunning : bool;

// ---------------------------------------------------------------------------
// Settings helpers (fall back to defaults when the menu XML is not installed)
// ---------------------------------------------------------------------------

function DDL_Raw(id : name) : string
{
    var config : CInGameConfigWrapper;
    config = theGame.GetInGameConfigWrapper();
    if (!config)
        return "";
    return config.GetVarValue(DDL_Group(), id);
}

function DDL_Bool(id : name, fallback : bool) : bool
{
    var raw : string;
    raw = DDL_Raw(id);
    if (raw == "true") return true;
    if (raw == "false") return false;
    return fallback;
}

function DDL_Num(id : name, fallback, minimum, maximum : float) : float
{
    var raw : string;
    var value : float;
    raw = DDL_Raw(id);
    if (raw == "")
        return fallback;
    value = StringToFloat(raw, fallback);
    return ClampF(value, minimum, maximum);
}

function DDL_Option(id : name, fallback : int) : int
{
    var raw : string;
    raw = DDL_Raw(id);
    if (raw == "")
        return fallback;
    return StringToInt(raw, fallback);
}

function DDL_BoolText(value : bool) : string
{
    if (value)
        return "yes";
    return "no";
}

function DDL_Notify(key : string)
{
    if (theGame.GetGuiManager())
        theGame.GetGuiManager().ShowNotification(GetLocStringByKeyExt(key));
}

// ---------------------------------------------------------------------------
// Inventory
// ---------------------------------------------------------------------------

@addMethod(W3PlayerWitcher)
function DDL_OwnsLantern() : bool
{
    var inv : CInventoryComponent;
    inv = GetInventory();
    return inv && inv.GetItemQuantityByName(DDL_LanternItem(), false) > 0;
}

// True while the lantern sits in one of the two usable-item quick slots.
@addMethod(W3PlayerWitcher)
function DDL_IsEquipped() : bool
{
    var item : SItemUniqueId;
    // The Pockets slots in the inventory screen are EES_Quickslot1/2.
    if (GetItemEquippedOnSlot(EES_Quickslot1, item) && GetInventory().GetItemName(item) == DDL_LanternItem())
        return true;
    return GetItemEquippedOnSlot(EES_Quickslot2, item) && GetInventory().GetItemName(item) == DDL_LanternItem();
}

@addMethod(W3PlayerWitcher)
function DDL_IsNight() : bool
{
    var hour : int;
    hour = GameTimeHours(theGame.GetGameTime());
    return hour >= 20 || hour < 6;
}

// Auto light: 0 = manual only, 1 = lit while in a quick slot,
// 2 = lit while in a quick slot at night (20:00-06:00).
// Acts only on changes, so a manual toggle in between is respected.
@addMethod(W3PlayerWitcher)
function DDL_AutoLight()
{
    var mode : int;
    var equipped, night, want, changed : bool;

    mode = DDL_Option('autoLight', 1);
    equipped = DDL_IsEquipped();
    night = DDL_IsNight();
    if (!ddlAutoReady)
    {
        // First tick after load: adopt the current state, don't fight the save.
        ddlAutoReady = true;
        ddlWasEquipped = equipped;
        ddlWasNight = night;
        return;
    }
    changed = equipped != ddlWasEquipped || (mode == 2 && night != ddlWasNight);
    ddlWasEquipped = equipped;
    ddlWasNight = night;
    if (mode == 0 || !changed)
        return;

    want = equipped && (mode == 1 || night);
    if (want == ddlLit)
        return;
    if (want)
    {
        if (DDL_InWater())
            return;
        if (!DDL_HasFuel() && !DDL_Refill())
        {
            DDL_Notify("ddl_note_no_oil");
            return;
        }
    }
    ddlLit = want;
}

@addMethod(W3PlayerWitcher)
function DDL_BurnMinutesPerFlask() : float
{
    return DDL_Num('burnHours', 8.0, 1.0, 48.0) * 60.0;
}

// Pours one flask from the inventory into the reservoir. Returns false if none.
@addMethod(W3PlayerWitcher)
function DDL_Refill() : bool
{
    var inv : CInventoryComponent;
    inv = GetInventory();
    if (!inv || inv.GetItemQuantityByName(DDL_OilItem(), false) <= 0)
        return false;
    inv.RemoveItemByName(DDL_OilItem(), 1);
    ddlOilMinutes = DDL_BurnMinutesPerFlask();
    DDL_Notify("ddl_note_refilled");
    return true;
}

@addMethod(W3PlayerWitcher)
function DDL_HasFuel() : bool
{
    return !DDL_Bool('requireOil', true) || ddlOilMinutes > 0.0;
}

// ---------------------------------------------------------------------------
// Entity lifecycle
// ---------------------------------------------------------------------------

@addMethod(W3PlayerWitcher)
function DDL_Spawn() : bool
{
    var template : CEntityTemplate;
    var bone : int;
    var position : Vector;
    var rotation : EulerAngles;
    var hinge : CComponent;

    if (ddlEntity)
        return true;
    if (theGame.GetEngineTimeAsSeconds() < ddlSpawnRetryAt)
        return false;
    // Avoid hammering a broken install: retry every few seconds at most.
    ddlSpawnRetryAt = theGame.GetEngineTimeAsSeconds() + 5.0;

    bone = GetBoneIndex(DDL_AttachBone());
    if (bone < 0)
        return false;
    template = (CEntityTemplate)LoadResource(DDL_Template(), true);
    if (!template)
    {
        LogChannel('DDLantern', "template missing: " + DDL_Template());
        return false;
    }

    position = GetBoneWorldPositionByIndex(bone);
    rotation = GetBoneWorldRotationByIndex(bone);
    ddlEntity = theGame.CreateEntity(template, position, rotation, false, false, true, PM_DontPersist);
    if (!ddlEntity)
        return false;
    if (!ddlEntity.CreateAttachmentAtBoneWS(this, DDL_AttachBone(), position, rotation))
    {
        LogChannel('DDLantern', "attachment to pelvis rejected");
        DDL_Despawn();
        return false;
    }

    ddlCarrier = ddlEntity.GetComponent(DDL_CarrierName());
    ddlBody = (CDrawableComponent)ddlEntity.GetComponent(DDL_BodyName());
    ddlPoint = (CLightComponent)ddlEntity.GetComponent(DDL_LightName());
    ddlFlame = (CDrawableComponent)ddlEntity.GetComponent(DDL_FlameName());
    if (!ddlCarrier || !ddlBody || !ddlPoint)
    {
        LogChannel('DDLantern', "entity is missing " + DDL_CarrierName() + ", " + DDL_BodyName() + " or " + DDL_LightName());
        DDL_Despawn();
        return false;
    }
    // The vanilla dangle would fight our pendulum; we own the motion.
    hinge = ddlEntity.GetComponent(DDL_HingeName());
    if (hinge)
        hinge.SetEnabled(false);

    ddlShown = true;
    ddlFlameOn = true;
    DDL_ApplyPlacement();
    DDL_ApplyLightSettings();
    // Force the first Sync to push real visibility / flame state.
    DDL_SetShown(false);
    DDL_SetFlame(false);
    return true;
}

@addMethod(W3PlayerWitcher)
function DDL_HasEntity() : bool
{
    if (ddlEntity)
        return true;
    return false;
}

@addMethod(W3PlayerWitcher)
function DDL_Despawn()
{
    DDL_StopSwing();
    if (ddlEntity)
    {
        ddlEntity.StopAllEffects();
        ddlEntity.BreakAttachment();
        ddlEntity.Destroy();
    }
    ddlEntity = NULL;
    ddlCarrier = NULL;
    ddlBody = NULL;
    ddlPoint = NULL;
    ddlFlame = NULL;
    ddlShown = false;
    ddlFlameOn = false;
    ddlSettingsSeen = "";
}

// Places the carrier relative to the pelvis from the position option plus
// the user's fine-tune offsets (centimetres).
@addMethod(W3PlayerWitcher)
function DDL_ApplyPlacement()
{
    var offset : Vector;
    var yaw, lean, twist : float;

    if (!ddlCarrier)
        return;
    switch (DDL_Option('position', 0))
    {
        // Tuned in game on the left hip (8 fwd, 20 up, 8 in, lean -30, door
        // turned 45 to face forward); the others mirror or shift it.
        case 1:  offset = Vector(-0.12, -0.14, 0.13);  yaw = 0.0;   lean = 30.0;  twist = -45.0; break; // right hip
        case 2:  offset = Vector(0.14, -0.14, -0.08);  yaw = 180.0; lean = 0.0;   twist = 0.0;   break; // small of the back
        case 3:  offset = Vector(-0.18, -0.14, -0.10); yaw = 0.0;   lean = -15.0; twist = 45.0;  break; // front left
        default: offset = Vector(-0.12, -0.14, -0.13); yaw = 0.0;   lean = -30.0; twist = 45.0;  break; // left hip (Dragon's Dogma)
    }
    offset.X += DDL_Num('offsetForward', 0.0, -20.0, 20.0) * -0.01;
    offset.Y += DDL_Num('offsetUp', 0.0, -20.0, 20.0) * -0.01;
    offset.Z += DDL_Num('offsetOut', 0.0, -20.0, 20.0) * -0.01 * DDL_SideSign();
    offset.X += ddlTuneForward * -0.01;
    offset.Y += ddlTuneUp * -0.01;
    offset.Z += ddlTuneOut * -0.01 * DDL_SideSign();

    ddlBasePosition = offset;
    // The model's up axis vs. the pelvis' (-Y) is unverified, so it's a menu
    // option: 0 = 90 pitch (Z-up model), 1 = none, 2 = -90 pitch, 3 = 180 roll.
    switch (DDL_Option('modelUp', 0))
    {
        case 1:  ddlBaseRotation = EulerAngles(0.0, yaw, 0.0);   break;
        case 2:  ddlBaseRotation = EulerAngles(-90.0, yaw, 0.0); break;
        case 3:  ddlBaseRotation = EulerAngles(0.0, yaw, 180.0); break;
        default: ddlBaseRotation = EulerAngles(90.0, yaw, 0.0);  break;
    }
    // Lean the bottom away from the leg. Pitch is the sideways lean here.
    ddlBaseRotation.Pitch += lean + ddlTunePitch;
    ddlBaseRotation.Yaw += ddlTuneYaw;
    ddlBaseRotation.Roll += ddlTuneRoll;
    ddlCarrier.SetPosition(ddlBasePosition);
    ddlCarrier.SetRotation(ddlBaseRotation);
    // Twist the body about its own axis, relative to the carrier, so the door
    // and candle face forward. Done on the child to avoid the carrier's gimbal lock.
    if (ddlBody)
        ddlBody.SetRotation(EulerAngles(ddlTwistPitch, twist + ddlTwistYaw, ddlTwistRoll));
}

// +1 when the lantern hangs on Geralt's left (-Z), -1 on his right.
@addMethod(W3PlayerWitcher)
function DDL_SideSign() : float
{
    if (DDL_Option('position', 0) == 1)
        return -1.0;
    return 1.0;
}

@addMethod(W3PlayerWitcher)
function DDL_ApplyLightSettings()
{
    if (!ddlPoint)
        return;
    ddlPoint.brightness = DDL_Num('brightness', 80.0, 1.0, 200.0);
    ddlPoint.radius = DDL_Num('radius', 12.0, 2.0, 30.0);
    ddlPoint.color = Color(255, 196, 128, 255);
    if (DDL_Bool('castShadows', false))
        ddlPoint.shadowCastingMode = LSCM_Normal;
    else
        ddlPoint.shadowCastingMode = LSCM_None;
    // A lit light only picks up new properties when it is re-enabled.
    if (ddlFlameOn)
    {
        ddlPoint.SetEnabled(false);
        ddlPoint.SetEnabled(true);
    }
}

// Menu changes are picked up on the next tick: compare the placement and
// light settings with what was last applied.
@addMethod(W3PlayerWitcher)
function DDL_ApplySettingsIfChanged()
{
    var seen : string;
    seen = DDL_Raw('position') + "|" + DDL_Raw('modelUp') + "|" + DDL_Raw('offsetForward') + "|"
        + DDL_Raw('offsetUp') + "|" + DDL_Raw('offsetOut') + "|" + DDL_Raw('brightness') + "|"
        + DDL_Raw('radius') + "|" + DDL_Raw('castShadows');
    if (seen == ddlSettingsSeen)
        return;
    ddlSettingsSeen = seen;
    DDL_ApplyPlacement();
    DDL_ApplyLightSettings();
}

@addMethod(W3PlayerWitcher)
function DDL_SetShown(shown : bool)
{
    if (!ddlEntity || shown == ddlShown)
        return;
    ddlShown = shown;
    ddlBody.SetVisible(shown);
    ddlBody.SetCastingShadows(false);
    if (!shown)
        DDL_SetFlame(false);
}

@addMethod(W3PlayerWitcher)
function DDL_SetFlame(on : bool)
{
    if (!ddlEntity || on == ddlFlameOn)
        return;
    ddlFlameOn = on;
    if (ddlFlame)
        ddlFlame.SetVisible(on);
    ddlPoint.SetEnabled(on);
    // Optional particle effect authored on the entity; harmless if absent.
    if (on)
        ddlEntity.PlayEffect('ddl_fire');
    else
        ddlEntity.StopEffect('ddl_fire');
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

@addMethod(W3PlayerWitcher)
function DDL_InScene() : bool
{
    return theGame.IsDialogOrCutscenePlaying() || theGame.isCutscenePlaying
        || theGame.IsCurrentlyPlayingNonGameplayScene() || IsInGameplayScene();
}

@addMethod(W3PlayerWitcher)
function DDL_InWater() : bool
{
    return IsSwimming() || IsDiving();
}

// Burns oil for elapsed game time (meditation and waiting count, as in DD).
@addMethod(W3PlayerWitcher)
function DDL_BurnOil()
{
    var now, elapsed : int;
    now = GameTimeToSeconds(theGame.GetGameTime());
    elapsed = now - ddlLastGameSeconds;
    ddlLastGameSeconds = now;
    if (!ddlFlameOn || !DDL_Bool('requireOil', true))
        return;
    // Ignore backwards jumps and absurd skips (loading, debug time changes).
    if (elapsed <= 0 || elapsed > 86400)
        return;
    ddlOilMinutes -= (float)elapsed / 60.0;
    if (ddlOilMinutes > 0.0)
        return;
    ddlOilMinutes = 0.0;
    if (DDL_Bool('autoRefill', true) && DDL_Refill())
        return;
    ddlLit = false;
    DDL_Notify("ddl_note_out_of_oil");
}

@addMethod(W3PlayerWitcher)
function DDL_Sync()
{
    var wanted, inWater : bool;

    if (this != thePlayer)
        return;
    if (!ddlInitialized)
    {
        ddlInitialized = true;
        ddlLit = false;
        ddlOilMinutes = DDL_BurnMinutesPerFlask();
        ddlLastGameSeconds = GameTimeToSeconds(theGame.GetGameTime());
    }

    // Auto light tracks equip changes even while the lantern is hidden,
    // so it must run before the early return below.
    DDL_AutoLight();

    // Worn while equipped in a Pockets slot, or whenever owned if the
    // "Always on the belt" option is on.
    wanted = DDL_Bool('enabled', true) && DDL_OwnsLantern() && IsAlive()
        && (DDL_IsEquipped() || DDL_Bool('showUnequipped', false));
    if (!wanted)
    {
        DDL_Despawn();
        return;
    }
    if (!DDL_Spawn())
        return;

    inWater = DDL_InWater();
    if (inWater && !ddlWasInWater && ddlLit && DDL_Bool('douseInWater', true))
    {
        ddlLit = false;
        DDL_Notify("ddl_note_doused");
    }
    ddlWasInWater = inWater;

    DDL_ApplySettingsIfChanged();
    DDL_BurnOil();
    DDL_SetShown(!DDL_InScene() || !DDL_Bool('hideInScenes', true));
    DDL_SetFlame(ddlShown && ddlLit && !inWater && DDL_HasFuel());

    if (ddlShown && DDL_Bool('swing', true) && !IsUsingHorse())
        DDL_StartSwing();
    else
        DDL_StopSwing();
}

@addMethod(W3PlayerWitcher)
function DDL_Toggle()
{
    var now : float;

    // Some input paths deliver both the throw and the use events; debounce.
    now = theGame.GetEngineTimeAsSeconds();
    if (now - ddlLastToggleAt < 0.35)
        return;
    ddlLastToggleAt = now;

    if (!ddlLit)
    {
        if (DDL_InWater())
        {
            DDL_Notify("ddl_note_wet");
            return;
        }
        if (!DDL_HasFuel() && !DDL_Refill())
        {
            DDL_Notify("ddl_note_no_oil");
            return;
        }
    }
    ddlLit = !ddlLit;
    DDL_Sync();
}

@addMethod(W3PlayerWitcher)
function DDL_IsLanternSelected() : bool
{
    var inv : CInventoryComponent;
    var item : SItemUniqueId;
    inv = GetInventory();
    item = GetSelectedItemId();
    return inv && inv.IsIdValid(item) && inv.GetItemName(item) == DDL_LanternItem();
}

@addMethod(W3PlayerWitcher)
timer function DDL_Tick(delta : float, id : int)
{
    DDL_Sync();
}

// ---------------------------------------------------------------------------
// Swing: a damped two-axis pendulum about the hook, driven by the pelvis'
// world acceleration expressed in pelvis space.
// ---------------------------------------------------------------------------

@addMethod(W3PlayerWitcher)
function DDL_StartSwing()
{
    if (ddlSwingRunning)
        return;
    ddlSwingRunning = true;
    ddlSwingReady = false;
    AddTimer('DDL_SwingTick', 0.0, true);
}

@addMethod(W3PlayerWitcher)
function DDL_StopSwing()
{
    if (ddlSwingRunning)
        RemoveTimer('DDL_SwingTick');
    ddlSwingRunning = false;
    ddlSwingReady = false;
    ddlSwingFwd = 0.0;
    ddlSwingSide = 0.0;
    ddlSwingFwdRate = 0.0;
    ddlSwingSideRate = 0.0;
    if (ddlCarrier)
        ddlCarrier.SetRotation(ddlBaseRotation);
}

@addMethod(W3PlayerWitcher)
timer function DDL_SwingTick(delta : float, id : int)
{
    var frame : Matrix;
    var pos, vel, accel, forward, left : Vector;
    var aFwd, aSide, strength, limit, dt, remaining : float;
    var rotation : EulerAngles;
    var bone, step : int;

    if (!ddlCarrier || !ddlShown)
        return;
    bone = GetBoneIndex(DDL_AttachBone());
    if (bone < 0)
        return;
    frame = GetBoneWorldMatrixByIndex(bone);
    pos = MatrixGetTranslation(frame);

    // Re-seed after hitches, teleports and the first frame.
    if (!ddlSwingReady || delta <= 0.0 || delta > 0.1 || VecDistance(pos, ddlSwingPrevPos) > 0.75)
    {
        ddlSwingPrevPos = pos;
        ddlSwingPrevVel = Vector(0.0, 0.0, 0.0);
        ddlSwingReady = delta > 0.0 && delta <= 0.1;
        return;
    }

    vel = (pos - ddlSwingPrevPos) * (1.0 / delta);
    // Smooth velocity a little so animation noise doesn't jitter the lantern.
    vel = ddlSwingPrevVel * 0.6 + vel * 0.4;
    accel = (vel - ddlSwingPrevVel) * (1.0 / delta);
    ddlSwingPrevPos = pos;
    ddlSwingPrevVel = vel;

    forward = VecNormalize(MatrixGetAxisX(frame)) * -1.0;
    left = VecNormalize(MatrixGetAxisZ(frame)) * -1.0;
    strength = DDL_Num('swingStrength', 100.0, 0.0, 200.0) / 100.0;
    aFwd = ClampF(VecDot(accel, forward), -25.0, 25.0) * strength;
    aSide = ClampF(VecDot(accel, left), -25.0, 25.0) * strength;

    // theta'' = -(g/L) sin(theta) - (a/L) cos(theta) - c * theta'
    // L = 0.15 m hook-to-centre-of-mass, c = damping. Angles in degrees.
    limit = 40.0;
    remaining = delta;
    for (step = 0; step < 6 && remaining > 0.0001; step += 1)
    {
        dt = MinF(remaining, 0.0083);
        remaining -= dt;
        ddlSwingFwdRate += (-(9.81 / 0.15) * SinF(Deg2Rad(ddlSwingFwd)) - (aFwd / 0.15) * CosF(Deg2Rad(ddlSwingFwd))) * Rad2Deg(1.0) * dt;
        ddlSwingSideRate += (-(9.81 / 0.15) * SinF(Deg2Rad(ddlSwingSide)) - (aSide / 0.15) * CosF(Deg2Rad(ddlSwingSide))) * Rad2Deg(1.0) * dt;
        ddlSwingFwdRate *= 1.0 / (1.0 + 5.0 * dt);
        ddlSwingSideRate *= 1.0 / (1.0 + 5.0 * dt);
        ddlSwingFwd = ClampF(ddlSwingFwd + ddlSwingFwdRate * dt, -limit, limit);
        ddlSwingSide = ClampF(ddlSwingSide + ddlSwingSideRate * dt, -limit, limit);
    }

    // If the lantern swings on the wrong axis in game, swap the two lines
    // below or flip their signs - the engine's Euler order is the unknown.
    rotation = ddlBaseRotation;
    rotation.Roll += ddlSwingFwd;
    rotation.Yaw += ddlSwingSide * DDL_SideSign();
    ddlCarrier.SetRotation(rotation);
}

// ---------------------------------------------------------------------------
// Engine hooks
// ---------------------------------------------------------------------------

@wrapMethod(W3PlayerWitcher)
function OnSpawned(spawnData : SEntitySpawnData)
{
    wrappedMethod(spawnData);
    ddlEntity = NULL;
    ddlSwingRunning = false;
    ddlSpawnRetryAt = 0.0;
    ddlAutoReady = false;
    ddlLastGameSeconds = GameTimeToSeconds(theGame.GetGameTime());
    AddTimer('DDL_Tick', 0.25, true);
}

@wrapMethod(W3PlayerWitcher)
function OnDestroyed()
{
    RemoveTimer('DDL_Tick');
    DDL_Despawn();
    wrappedMethod();
}

@wrapMethod(CR4Game)
function OnBeforeWorldChange(worldName : string)
{
    var player : W3PlayerWitcher;
    player = (W3PlayerWitcher)thePlayer;
    if (player)
        player.DDL_Despawn();
    wrappedMethod(worldName);
}

// Quick-slot use. In the game's own flow every use of a selected usable item,
// from the button (CPlayerInput.OnCbtThrowItem) or the radial menu, ends in
// CR4Player.OnUseSelectedItem(). force = true is the game asking to put a held
// item away, which we leave alone. For the lantern we light or douse it on the
// belt and never start the hand animation.
@wrapMethod(CR4Player)
function OnUseSelectedItem(optional force : bool)
{
    var player : W3PlayerWitcher;
    if (!force)
    {
        player = (W3PlayerWitcher)this;
        if (player && player.DDL_IsLanternSelected())
        {
            player.DDL_Toggle();
            return true;
        }
    }
    return wrappedMethod(force);
}

// Shops. The game's inventory menu treats an NPC tagged 'Merchant' as a shop
// (CR4InventoryMenu.OnConfigUI), refreshes its loot and then builds the shop
// grid. A restock during that refresh can clear items outside the merchant's
// loot table, so we stock before and check again after, redrawing the shop
// grid with the game's own UpdateShop() if anything had to be re-added.
@wrapMethod(CR4InventoryMenu)
function OnConfigUI()
{
    var data : IScriptable;
    data = GetMenuInitData();
    DDL_StockShop(data);
    wrappedMethod();
    if (DDL_StockShop(data))
        UpdateShop();
}

// Adds the lantern and oil to an innkeeper's or shopkeeper's stock when
// missing. Returns true if anything was added.
function DDL_StockShop(data : IScriptable) : bool
{
    var npc : CNewNPC;
    var initData : W3InventoryInitData;
    var merchant : W3MerchantComponent;
    var inv : CInventoryComponent;
    var pin : name;
    var added : bool;

    if (!DDL_Bool('merchants', true))
        return false;
    npc = (CNewNPC)data;
    initData = (W3InventoryInitData)data;
    if (initData)
        npc = (CNewNPC)initData.containerNPC;
    if (!npc || !npc.HasTag('Merchant'))
        return false;
    merchant = (W3MerchantComponent)npc.GetComponentByClassName('W3MerchantComponent');
    if (!merchant)
        return false;
    pin = merchant.GetMapPinType();
    if (pin != 'Innkeeper' && pin != 'Shopkeeper')
        return false;
    inv = npc.GetInventory();
    if (!inv)
        return false;
    if (!inv.HasItem(DDL_LanternItem()))
    {
        inv.AddAnItem(DDL_LanternItem(), 1);
        added = true;
    }
    if (inv.GetItemQuantityByName(DDL_OilItem()) < 3)
    {
        inv.AddAnItem(DDL_OilItem(), 5);
        added = true;
    }
    return added;
}

// ---------------------------------------------------------------------------
// Console commands (enable the debug console to use them)
// ---------------------------------------------------------------------------

exec function ddlgive()
{
    thePlayer.GetInventory().AddAnItem(DDL_LanternItem(), 1, false, false);
    thePlayer.GetInventory().AddAnItem(DDL_OilItem(), 3, false, false);
}

exec function ddltoggle()
{
    var player : W3PlayerWitcher;
    player = (W3PlayerWitcher)thePlayer;
    if (player)
        player.DDL_Toggle();
}

// Live placement tuning. Values are cm / degrees on top of the preset and
// accumulate, e.g. "ddlpos 0 10 5" = 10 cm higher, 5 cm further out.
exec function ddlpos(forward : float, up : float, outward : float)
{
    var player : W3PlayerWitcher;
    player = (W3PlayerWitcher)thePlayer;
    if (!player)
        return;
    player.ddlTuneForward += forward;
    player.ddlTuneUp += up;
    player.ddlTuneOut += outward;
    player.DDL_ApplyPlacement();
    DDL_ShowTune();
}

exec function ddlrot(pitch : float, yaw : float, roll : float)
{
    var player : W3PlayerWitcher;
    player = (W3PlayerWitcher)thePlayer;
    if (!player)
        return;
    player.ddlTunePitch += pitch;
    player.ddlTuneYaw += yaw;
    player.ddlTuneRoll += roll;
    player.DDL_ApplyPlacement();
    DDL_ShowTune();
}

// Rotate the lantern body about its own axes (degrees, accumulates).
// One of the three turns the door/candle around the handle.
exec function ddlbody(pitch : float, yaw : float, roll : float)
{
    var player : W3PlayerWitcher;
    player = (W3PlayerWitcher)thePlayer;
    if (!player)
        return;
    player.ddlTwistPitch += pitch;
    player.ddlTwistYaw += yaw;
    player.ddlTwistRoll += roll;
    player.DDL_ApplyPlacement();
    DDL_ShowTune();
}

// Set the light: brightness (1-200) and radius in metres (2-30).
// Saved to the mod menu settings, so the Brightness/Radius sliders match.
// Use 0 to keep a value, e.g. ddlglow(25, 0) changes only brightness.
exec function ddlglow(brightness : float, radius : float)
{
    var player : W3PlayerWitcher;
    var config : CInGameConfigWrapper;
    player = (W3PlayerWitcher)thePlayer;
    config = theGame.GetInGameConfigWrapper();
    if (!player || !config)
        return;
    if (brightness > 0.0)
        config.SetVarValue(DDL_Group(), 'brightness', FloatToString(ClampF(brightness, 1.0, 200.0)));
    if (radius > 0.0)
        config.SetVarValue(DDL_Group(), 'radius', FloatToString(ClampF(radius, 2.0, 30.0)));
    theGame.SaveUserSettings();
    player.DDL_ApplyLightSettings();
    theGame.GetGuiManager().ShowNotification("Lantern glow: brightness "
        + FloatToStringPrec(DDL_Num('brightness', 80.0, 1.0, 200.0), 0)
        + ", radius " + FloatToStringPrec(DDL_Num('radius', 12.0, 2.0, 30.0), 1) + " m");
}

exec function ddlreset()
{
    var player : W3PlayerWitcher;
    player = (W3PlayerWitcher)thePlayer;
    if (!player)
        return;
    player.ddlTuneForward = 0.0;
    player.ddlTuneUp = 0.0;
    player.ddlTuneOut = 0.0;
    player.ddlTunePitch = 0.0;
    player.ddlTuneYaw = 0.0;
    player.ddlTuneRoll = 0.0;
    player.ddlTwistPitch = 0.0;
    player.ddlTwistYaw = 0.0;
    player.ddlTwistRoll = 0.0;
    player.DDL_ApplyPlacement();
    DDL_ShowTune();
}

exec function ddltune()
{
    DDL_ShowTune();
}

function DDL_ShowTune()
{
    var player : W3PlayerWitcher;
    var text : string;
    player = (W3PlayerWitcher)thePlayer;
    if (!player)
        return;
    text = "Lantern tune: pos " + FloatToStringPrec(player.ddlTuneForward, 1) + " / "
        + FloatToStringPrec(player.ddlTuneUp, 1) + " / " + FloatToStringPrec(player.ddlTuneOut, 1)
        + " cm, rot " + FloatToStringPrec(player.ddlTunePitch, 0) + " / "
        + FloatToStringPrec(player.ddlTuneYaw, 0) + " / " + FloatToStringPrec(player.ddlTuneRoll, 0)
        + ", body " + FloatToStringPrec(player.ddlTwistPitch, 0) + " / "
        + FloatToStringPrec(player.ddlTwistYaw, 0) + " / " + FloatToStringPrec(player.ddlTwistRoll, 0);
    theGame.GetGuiManager().ShowNotification(text);
    LogChannel('DDLantern', text);
}

exec function ddlstatus()
{
    var player : W3PlayerWitcher;
    var text : string;
    player = (W3PlayerWitcher)thePlayer;
    if (!player)
        return;
    text = "Dragon's Lantern: owned=" + DDL_BoolText(player.DDL_OwnsLantern())
        + " entity=" + DDL_BoolText(player.DDL_HasEntity())
        + " lit=" + DDL_BoolText(player.ddlLit)
        + " flame=" + DDL_BoolText(player.ddlFlameOn)
        + " shown=" + DDL_BoolText(player.ddlShown)
        + " oil=" + FloatToStringPrec(player.ddlOilMinutes / 60.0, 1) + "h";
    theGame.GetGuiManager().ShowNotification(text);
    LogChannel('DDLantern', text);
}
