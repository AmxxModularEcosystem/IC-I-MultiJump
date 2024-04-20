#include <amxmodx>
#include <hamsandwich>
#include <fakemeta>
#include <reapi>
#include <VipModular>
#include <ParamsController>

#pragma semicolon 1
#pragma compress 1

public stock const PluginName[] = "[IC-I] Multi Jump";
public stock const PluginVersion[] = "1.0.0";
public stock const PluginAuthor[] = "ArKaNeMaN";
public stock const PluginURL[] = "github.com/AmxxModularEcosystem/IC-I-MultiJump";
public stock const PluginDescription[] = "Multi jump item for Vip Modular's items controller.";

new const ITEM_NAME[] = "MultiJump";

new g_iUserMaxJumps[MAX_PLAYERS + 1] = {0, ...};
new Float:g_iUserVelocityMultiplier[MAX_PLAYERS + 1] = {1.0, ...};
new Float:g_fUserCooldownDuration[MAX_PLAYERS + 1] = {0.0, ...};
new g_iUserMinRound[MAX_PLAYERS + 1] = {0, ...};

new g_iUserJumpsCounter[MAX_PLAYERS + 1] = {0, ...};
new Float:g_fUserCooldownExpiresAt[MAX_PLAYERS + 1] = {0.0, ...};

public VipM_IC_OnInitTypes() {
    register_plugin(PluginName, PluginVersion, PluginAuthor);
    ParamsController_Init();

    VipM_IC_RegisterType(ITEM_NAME);
    VipM_IC_RegisterTypeEvent(ITEM_NAME, ItemType_OnRead, "@OnRead");
    VipM_IC_RegisterTypeEvent(ITEM_NAME, ItemType_OnGive, "@OnGive");

    RegisterHookChain(RG_CBasePlayer_Jump, "@OnPlayerJump", false);
    RegisterHookChain(RG_CBasePlayer_Killed, "@OnPlayerKilled", true);
}

Array:PrepareParamsBundle() {
    static Array:aParamsBundle = Invalid_Array;
    if (aParamsBundle == Invalid_Array) {
        aParamsBundle = ArrayCreate(1, 1);
        ArrayPushCell(aParamsBundle, ParamsController_Param_Construct("Count", "Integer", false));
        ArrayPushCell(aParamsBundle, ParamsController_Param_Construct("VelMult", "Float", false));
        ArrayPushCell(aParamsBundle, ParamsController_Param_Construct("Cooldown", "Float", false));
        ArrayPushCell(aParamsBundle, ParamsController_Param_Construct("Duration", "Float", false));
    }
    return aParamsBundle;
}

@OnRead(const JSON:jCfg, Trie:tParams) {
    tParams = ParamsController_Param_ReadList(PrepareParamsBundle(), jCfg);
}

@OnGive(const UserId, const Trie:tParams) {
    g_iUserMaxJumps[UserId] = VipM_Params_GetInt(tParams, "Count", 1);
    g_iUserVelocityMultiplier[UserId] = VipM_Params_GetFloat(tParams, "VelMult", 1.0);
    g_fUserCooldownDuration[UserId] = VipM_Params_GetFloat(tParams, "Cooldown", 0.0);
    
    new Float:fDuration = VipM_Params_GetFloat(tParams, "Duration", 0.0);
    if (fDuration > 0.0) {
        set_task(fDuration, "@Task_Reset", UserId);
    }
}

ResetEffect(const UserId) {
    remove_task(UserId);
    
    g_iUserMaxJumps[UserId] = 0;
    g_iUserVelocityMultiplier[UserId] = 1.0;
    g_fUserCooldownDuration[UserId] = 0.0;
    g_iUserMinRound[UserId] = 0;

    g_iUserJumpsCounter[UserId] = 0;
    g_fUserCooldownExpiresAt[UserId] = 0.0;
}

public client_disconnected(UserId) {
    ResetEffect(UserId);
}

@Task_Reset(const UserId) {
    ResetEffect(UserId);
}

@OnPlayerKilled(const UserId) {
    ResetEffect(UserId);
}

@OnPlayerJump(UserId) {
    if (
        !g_iUserMaxJumps[UserId]
        || !is_user_alive(UserId)
    ) {
        return HAM_IGNORED;
    }

    new szButton = get_entvar(UserId, var_button);
    new szOldButton = get_entvar(UserId, var_oldbuttons);

    if (!(szButton & IN_JUMP)) {
        return HAM_IGNORED;
    }

    new Float:fGameTime = get_gametime();

    if (get_entvar(UserId, var_flags) & FL_ONGROUND) {
        if (g_iUserJumpsCounter[UserId] > 0 && g_fUserCooldownDuration[UserId] > 0.0) {
            g_fUserCooldownExpiresAt[UserId] = fGameTime + g_fUserCooldownDuration[UserId];
        }

        g_iUserJumpsCounter[UserId] = 0;
        return HAM_IGNORED;
    }

    if (
        !(szOldButton & IN_JUMP)
        && (
            g_iUserMaxJumps[UserId] < 0
            || g_iUserJumpsCounter[UserId] < g_iUserMaxJumps[UserId]
        )
        && (
            g_fUserCooldownExpiresAt[UserId] <= 0.0
            || g_fUserCooldownExpiresAt[UserId] <= fGameTime
        )
    ) {
        g_iUserJumpsCounter[UserId]++;
        
        new Float:szVelocity[3];
        get_entvar(UserId, var_velocity, szVelocity);
        szVelocity[2] = random_float(295.0, 305.0);
        szVelocity[2] *= g_iUserVelocityMultiplier[UserId];
        set_entvar(UserId, var_velocity, szVelocity);
    }

    return HAM_IGNORED;
}
