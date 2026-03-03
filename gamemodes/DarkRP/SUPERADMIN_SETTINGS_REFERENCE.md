# Plagued Paradise — Superadmin settings reference

Values you can change for RP, ghost/death, server, and admin behavior. Use this when building a superadmin settings panel or editing configs.

---

## 1. ConVars (console / cfg)

### Server (change in server.cfg or via rcon)

| ConVar | Default | Description |
|--------|---------|-------------|
| `rp_debug` | 0 | RP systems debug (0=off, 1=on). Replicated. |
| `inv_svdebug` | 0 | Inventory server debug prints. |
| `leveling_debug` | 0 | Leveling debug to console (1=on). |
| `AdminsCanPickUpPlayers` | 1 | Admins can pick up players (physgun). |
| `PlayersCanPickUpPlayers` | 0 | Non-admins can pick up players. |
| `_FAdmin_immunity` | 1 | FAdmin immunity system. |
| `FAdmin_logging` | 1 | FAdmin action logging. |
| `FAdmin_commandprefix` | "/" | Prefix for FAdmin chat commands. |
| `_FAdmin_MOTDPage` | default | MOTD page. |

### Client (change in config.cfg or options)

| ConVar | Default | Description |
|--------|---------|-------------|
| `inv_debug` | 0 | Inventory client debug. |
| `sb_debug_align` | 0 | Scoreboard column overlay (1=on). |
| `FAdmin_OverrideScoreboard` | 0 | Use FAdmin scoreboard (we force Paradise scoreboard). |
| `FAdmin_SortPlayerList` | Team | How FAdmin sorts players. |
| `FAdmin_PlayerRowSize` | 30 | FAdmin player row size. |
| `FAdmin_ShowChatNotifications` | 1 | FAdmin chat notifications. |

---

## 2. GM.Config (Lua — gamemode/config/config.lua)

Edit `gamemodes/DarkRP/gamemode/config/config.lua`. Restart map or server for many of these.

### RP / economy

| Config key | Default | Description |
|------------|---------|-------------|
| `normalsalary` | 45 | Base salary. |
| `paydelay` | 160 | Seconds between salary payments. |
| `startingmoney` | 500 | New player starting wallet. |
| `mprintamount` | 250 | Money printer payout per cycle. |
| `printeroverheat` | true | Printers can overheat. |
| `printeroverheatchance` | 22 | Overheat chance (higher = less likely). |
| `printerreward` | 950 | Reward for destroying a money printer. |
| `pricecap` | 500 | Max /price. |
| `pricemin` | 50 | Min /price. |
| `currency` | "$" | Currency symbol. |
| `currencyLeft` | true | Symbol on left (true) or right. |

### Jobs / roles

| Config key | Default | Description |
|------------|---------|-------------|
| `changejobtime` | 10 | Seconds before job change allowed. |
| `demotetime` | 120 | Seconds before rejoin after demotion. |
| `restrictallteams` | false | Restrict all teams. |
| `allowjobswitch` | true | Allow job switching. |
| `customjobs` | true | /job command. |
| `enforceplayermodel` | true | Force job model. |

### Spawn / respawn / death

| Config key | Default | Description |
|------------|---------|-------------|
| `norespawn` | true | Disable default respawn (we use death system). |
| `respawntime` | 1 | Min seconds before respawn. |
| `customspawns` | true | Use custom job spawns. |
| `respawninjail` | true | Respawn in jail if jailed. |
| `deathfee` | 30 | Money lost on death. |
| `dropmoneyondeath` | false | Drop money on death. |
| `droppocketdeath` | true | Drop pocket items on death. |
| `dropweapondeath` | false | Drop current weapon on death. |
| `babygod` | true | Spawn protection. |
| `babygodtime` | 5 | Spawn protection duration (seconds). |
| `deathblack` | false | Black screen on death. |
| `deadtalk` | true | Talk while dead. |
| `deadvoice` | true | Voice while dead. |
| `showdeaths` | true | Kill info in corner. |

### Entities / props / doors

| Config key | Default | Description |
|------------|---------|-------------|
| `maxdoors` | 20 | Max doors per player. |
| `maxvehicles` | 5 | Max vehicles per player. |
| `adminnpcs` | 3 | Who can spawn NPCs (0–3). |
| `adminsents` | 1 | Who can spawn SENTs. |
| `adminvehicles` | 3 | Who can spawn vehicles. |
| `EntitySpamTime` | 2 | Spam delay entity spawn. |
| `propcost` | 10 | Cost per prop (if proppaying). |
| `doorcost` | 30 | Cost to buy door. |
| `vehiclecost` | 40 | Cost to own vehicle. |
| `entremovedelay` | 0 | Delay before removing bought entity on disconnect. |

### Weapons / admin

| Config key | Default | Description |
|------------|---------|-------------|
| `adminweapons` | 1 | Who can spawn weapons. |
| `AdminsCopWeapons` | true | Admins get cop weapons. |
| `enablebuypistol` | true | /buy pistol. |
| `license` | false | License to pick up guns. |
| `noguns` | false | No guns. |

### Jail / mayor / misc

| Config key | Default | Description |
|------------|---------|-------------|
| `jailtimer` | 120 | Jail time (seconds). |
| `arrestspeed` | 120 | Arrest speed. |
| `lockdown` | true | Mayor lockdown. |
| `lockdowndelay` | 120 | Lockdown cooldown. |
| `maxlawboards` | 2 | Mayor law boards. |
| `maxlotterycost` | 250 | Max lottery cost. |
| `minlotterycost` | 30 | Min lottery cost. |
| `maxletters` | 10 | Max letters. |
| `maxCheques` | 5 | Max cheques. |
| `maxdrugs` | 2 | Max drugs. |
| `maxfoods` | 2 | Max microwaves. |
| `maxfooditems` | 20 | Max food items from F4. |
| `maxadvertbillboards` | 3 | Max /advert billboards. |
| `pocketitems` | 10 | Pocket slots. |
| `searchtime` | 30 | Warrant validity (seconds). |
| `wantedtime` | 120 | Wanted duration. |

### Movement / health

| Config key | Default | Description |
|------------|---------|-------------|
| `walkspeed` | 160 | Walk speed. |
| `runspeed` | 240 | Run speed. |
| `runspeedcp` | 255 | CP run speed. |
| `startinghealth` | 100 | Spawn health. |
| `realisticfalldamage` | true | Fall damage. |
| `falldamagedamper` | 15 | Fall damage damper. |
| `falldamageamount` | 10 | Base fall damage. |

### Chat / voice

| Config key | Default | Description |
|------------|---------|-------------|
| `alltalk` | false | Global chat. |
| `dynamicvoice` | true | Room-based voice. |
| `voiceradius` | true | Voice radius. |
| `talkDistance` | 250 | Talk distance. |
| `whisperDistance` | 90 | Whisper. |
| `yellDistance` | 550 | Yell. |
| `voiceDistance` | 550 | Voice. |
| `chatsounds` | true | Chat sounds. |
| `chatsoundsdelay` | 5 | Chat sound delay. |

### Hungermod (if enabled)

| Config key | Default | Description |
|------------|---------|-------------|
| `hungerspeed` | 2 | Hunger rate. |
| `starverate` | 3 | Health lost per second when starving. |

### Hitman (if used)

| Config key | Default | Description |
|------------|---------|-------------|
| `minHitPrice` | 200 | Min hit price. |
| `maxHitPrice` | 50000 | Max hit price. |
| `minHitDistance` | 150 | Min distance for deal. |
| `hitTargetCooldown` | 120 | Target cooldown. |
| `hitCustomerCooldown` | 240 | Customer cooldown. |

### AFK

| Config key | Default | Description |
|------------|---------|-------------|
| `afkdemotetime` | 600 | Inactivity before AFK demote. |
| `AFKDelay` | 300 | AFK spam prevention. |

---

## 3. Code-only / module settings

Not ConVars; change in code if you need them.

| Location | Variable / constant | Description |
|----------|---------------------|-------------|
| `gamemode/modules/resources/sv_resources.lua` | `MAX_RESOURCE_ENTITIES` (local 5) | Max dropped resource entities in world. |
| Job limits | `TEAM_*` and `RPExtraTeams` in config/jobrelated.lua | Max players per job (e.g. `max = 4`). |
| Printer entity limits | In addentities / createEntity | Max printers per player (entity `max`). |

---

## 4. Where to add a superadmin panel

- **Client:** New panel under admin menu (e.g. “Server settings” tab) that sends chosen keys/values to server.
- **Server:** Net message or concommand that checks `ply:IsSuperAdmin()` and sets `GM.Config[key] = value` (and optionally saves to a JSON/cfg file for persistence across restarts).
- Prefer ConVars for values that should persist in `cfg/` and be editable without code changes; use `GM.Config` for one-place RP tuning in `config.lua`.

---

*Generated for Plagued Paradise (DarkRP). Gamemode folder remains `DarkRP` for workshop/category.*
