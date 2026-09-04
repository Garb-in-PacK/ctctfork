# City Controller PGC

Fork of City Controller for OpenTTD GameScript API 13+ / OpenTTD 15.

Adds **Permanent Growth Credit**:

- every town receives one deterministic unique cargo from all cargos available in the current economy;
- the unique cargo is counted even if it is not unlocked by the normal City Controller cargo progression yet;
- every cargo has its own permanent counter, level, and limit per town;
- default limit starts at 100 and increases by 1 after each completed level;
- normal unlocked cargos give +1% target population per level;
- the unique cargo gives +5% target population per level;
- the final town target is multiplied by the permanent bonus.

Extra settings:

- `PGC_Enable`
- `PGC_InitialLimit`
- `PGC_LimitIncrease`
- `PGC_NormalBonusPercent`
- `PGC_UniqueBonusPercent`
- `PGC_ShowInTownWindow`
- `WinTownSizePercent`
- `FinalCargoUnlockTownCount`
- `CargoUnlockTownCountStep`

Android installation:

1. Open this repository on GitHub.
2. Press **Code → Download ZIP**.
3. Extract the archive.
4. Copy the inner `ctct` folder to:

```text
Android/data/org.openttd.sdl/files/.openttd/game/
```

5. Start OpenTTD and select **City Controller PGC** in Game Script settings.

To publish it into OpenTTD Online Content / BaNaNaS, it still has to be packaged and uploaded to BaNaNaS separately. GitHub alone does not make it appear in the in-game online content browser.
