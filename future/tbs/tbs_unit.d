
enum TBSWeaponType {
    SWORD, AXE, DAGGER, SPEAR, PIKE, BOW, CROSSBOW
}

enum TBSItemType {
    WEAPON_1H, WEAPON_2H, SHIELD, ARMOR, MOUNT, MISC_ITEM
}
enum TBSItemSlot {
    WEAPON_0, WEAPON_1, ARMOR, MOUNT, ITEM_0, ITEM_1
}
enum TBSAmmoSlot {
    BROADHEAD, PIERCING, FLAMING, ICE
}

abstract class TBSItem {
    TBSItemType type;
}
bool isValidEquipForSlot (TBSItemType itemType, TBSItemSlot slot) {
    final switch (slot) {
        case TBSItemSlot.WEAPON_0: return itemType == TBSItemType.WEAPON_1H || itemType == TBSItemType.WEAPON_2H;
        case TBSItemSlot.WEAPON_1: return itemType == TBSItemType.WEAPON_1H || itemType == TBSItemType.SHIELD;
        case TBSItemSlot.ARMOR:    return itemType == TBSItemType.ARMOR;
        case TBSItemSlot.MOUNT:    return itemType == TBSItemType.MOUNT;
        case TBSItemSlot.ITEM_0:
        case TBSItemSlot.ITEM_1:   return itemType == TBSItemType.MISC_ITEM;
    }
}
void equipItem (TBSUnit unit, TBSItem item, TBSItemSlot slot) {
    enforce(item is null || isValidEquipForSlot(item.type, slot), 
        format("Invalid item type %s for slot %s (%s)",
            item.type, slot, item));

    final switch (slot) {
        case TBSItemSlot.WEAPON_0: {
            unit.stats.replaceWeaponStats(unit.items[slot], item);
            if (item.type == TBSWeaponType.WEAPON_2H) {
                unit.stats.replaceWeaponStats(unit.items[TBSItemSlot.WEAPON_1], null);
                unit.items[TBSItemSlot.WEAPON_1] = null;
            }
        } break;
        case TBSItemSlot.WEAPON_1: {
            unit.stats.replaceWeaponStats(unit.items[slot], item);
        } break;
        case TBSItemSlot.ARMOR: {
            unit.stats.replaceArmorStats(unit.items[slot], item);
        } break;
        case TBSItemSlot.MOUNT: {
            unit.stats.replaceMovementStats(unit, unit.items[slot], item);
        } break;
        default: {
            assert(slot >= TBSItemSlot.ITEM_0);
            unit.setDirty( TBSUnitFlag.DIRTY_UI_ITEM_ICONS );
        }
    }
    unit.items[slot] = item;
}

void replaceWeaponStats (ref TBSUnitStatus status, TBSItem original, TBSItem replacement) {

}
void replaceArmorStats (ref TBSUnitStatus status, TBSItem original, TBSItem replacement) {

}
// Update movement stats w/ mount items (either of which can be null).
// Uses a combination of mount stats + unit chassis stats to determine movement, armor, etc
void replaceMovementStats (TBSUnit unit, TBSItem mount, TBSItem replacement) {

}


abstract class TBSWeapon : TBSItem {
    TBSWeaponType weaponType;
    string        name;
    uint          id;

    abstract bool   isMelee ();
    abstract double getToHit  (double normalizedRoll);
    abstract double getParry  (double normalizedRoll);
    abstract double getDamage (double normalizedRoll);
}
class TBSRangedWeapon {

}
class TBSMeleeWeapon {

}

abstract class TBSAbilty {
    abstract bool isElgible (TBSUnit);
    abstract void execute   (TBSUnitContext);
}
class TBSUnit {
    TBSUnitStatus      status;
    TBSUnitChassis     chassis;
    TBSProficiencyList proficiencies;
    TBSItem[TBSItemSlot.max] items;

    TBSSkillTree       skillTree;
    TBSAbility[]       availableAbilities;
}

struct TBSHealthChangeEvent {
    TBSUnit target;
    double  hpDelta;

    private void doExec (TBSGameState state, double v) {
        auto hp = target.status.hp = clamp(target.status.hp + v, 0, target.status.maxhp);
        if (hp == 0) {
            state.dispatchKillEvent(target);
        }
    }
    void exec   (TBSGameState state) { doExec(state, hpDelta);  }
    void unexec (TBSGameState state) { doExec(state, -hpDelta); }
}
struct TBSKillEvent {
    TBSUnit target;

    void exec   (TBSGameState state) { state.removeUnit(target); }
    void unexec (TBSGameState state) { state.addUnit(target);    }
}
struct TBSSpawnEvent {
    TBSUnit target;

    void exec   (TBSGameState state) { state.addUnit(target); }
    void unexec (TBSGameState state) { state.removeUnit(target); }
}
struct TBSEquipItemEvent {
    TBSUnit target;
}



















































