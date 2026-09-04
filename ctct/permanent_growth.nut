/*
 * Permanent Growth Credit extension for City Controller.
 * Keeps per-town, per-cargo permanent delivery counters.
 * Designed for OpenTTD GameScript API 13+ / OpenTTD 15.
 */

class permanent_growth
{
	_data = {};      // town -> { unique = cargo, cargos = { cargo -> {counter, level, limit} } }
	_allCargo = [];  // cached list of cargos in current economy

	constructor()
	{
		permanent_growth._data <- {};
		permanent_growth._allCargo <- [];
	}

	function Enabled()
	{
		return GSController.GetSetting("PGC_Enable") == 1;
	}

	function Start(newgame)
	{
		permanent_growth.BuildCargoList();
		local all_towns = GSTownList();
		foreach (town, _ in all_towns) {
			permanent_growth.EnsureTown(town);
		}
		trace(2, "PGC: initialized for " + permanent_growth._data.len() + " towns and " + permanent_growth._allCargo.len() + " cargos");
	}

	function BuildCargoList()
	{
		permanent_growth._allCargo <- [];

		local cargo_list = GSCargoList();
		foreach (cargo, _ in cargo_list) {
			permanent_growth._allCargo.append(cargo);
		}

		// Failsafe: if the cargo list API returns nothing for some reason,
		// at least use the cargos known by City Controller.
		if (permanent_growth._allCargo.len() == 0) {
			foreach (cargo in towns_m._featCargo) permanent_growth.AddCargoOnce(cargo);
			foreach (item in def_m.extCargo) permanent_growth.AddCargoOnce(item.cargo);
		}
	}

	function AddCargoOnce(cargo)
	{
		if (cargo < 0) return;
		foreach (existing in permanent_growth._allCargo) {
			if (existing == cargo) return;
		}
		permanent_growth._allCargo.append(cargo);
	}

	function EnsureTown(town)
	{
		if (!permanent_growth._data.rawin(town)) {
			permanent_growth._data[town] <- {
				unique = permanent_growth.PickUniqueCargo(town),
				cargos = {}
			};
		}
		return permanent_growth._data[town];
	}

	function PickUniqueCargo(town)
	{
		if (permanent_growth._allCargo.len() == 0) permanent_growth.BuildCargoList();
		if (permanent_growth._allCargo.len() == 0) return 0;

		// Deterministic pseudo-random selection: stable across save/load and multiplayer-safe.
		local seed = town * 1103515245 + 12345;
		if (seed < 0) seed = -seed;
		local index = seed % permanent_growth._allCargo.len();
		return permanent_growth._allCargo[index];
	}

	function EnsureCargoData(town, cargo)
	{
		local town_data = permanent_growth.EnsureTown(town);
		if (!town_data.cargos.rawin(cargo)) {
			town_data.cargos[cargo] <- {
				counter = 0,
				level = 0,
				limit = max(1, GSController.GetSetting("PGC_InitialLimit"))
			};
		}
		return town_data.cargos[cargo];
	}

	function AddDelivery(town, cargo, amount, opened)
	{
		if (!permanent_growth.Enabled()) return;
		if (amount <= 0) return;

		local town_data = permanent_growth.EnsureTown(town);
		if (!opened && cargo != town_data.unique) return;

		permanent_growth.AddDeliveryRaw(town, cargo, amount);
	}

	function AddDeliveryRaw(town, cargo, amount)
	{
		local cargo_data = permanent_growth.EnsureCargoData(town, cargo);
		cargo_data.counter += amount;

		local inc = max(0, GSController.GetSetting("PGC_LimitIncrease"));
		while (cargo_data.counter >= cargo_data.limit) {
			cargo_data.counter -= cargo_data.limit;
			cargo_data.level += 1;
			cargo_data.limit += inc;
			if (cargo_data.limit < 1) cargo_data.limit = 1;
		}
	}

	function UpdateLockedUniqueCargo(town)
	{
		if (!permanent_growth.Enabled()) return;
		local town_data = permanent_growth.EnsureTown(town);
		local unique = town_data.unique;
		if (permanent_growth.IsCargoOpened(unique)) return;

		local amount = 0;
		for (local company_id = GSCompany.COMPANY_FIRST; company_id < GSCompany.COMPANY_LAST; company_id++) {
			amount += max(0, GSCargoMonitor.GetTownDeliveryAmount(company_id, unique, town, true));
		}
		permanent_growth.AddDelivery(town, unique, amount, false);
	}

	function IsCargoOpened(cargo)
	{
		foreach (opened in towns_m._featCargo) {
			if (opened == cargo) return true;
		}
		return false;
	}

	function GetBonusPercent(town)
	{
		if (!permanent_growth.Enabled()) return 0;
		local town_data = permanent_growth.EnsureTown(town);
		local total = 0;
		local normal_bonus = max(0, GSController.GetSetting("PGC_NormalBonusPercent"));
		local unique_bonus = max(0, GSController.GetSetting("PGC_UniqueBonusPercent"));

		foreach (cargo, cargo_data in town_data.cargos) {
			if (cargo == town_data.unique) {
				total += cargo_data.level * unique_bonus;
			} else if (permanent_growth.IsCargoOpened(cargo)) {
				total += cargo_data.level * normal_bonus;
			}
		}
		return total;
	}

	function ApplyBonus(town, base_target)
	{
		local bonus = permanent_growth.GetBonusPercent(town);
		if (bonus <= 0) return base_target;
		local final_target = (base_target * (100 + bonus)) / 100;
		return final_target.tointeger();
	}

	function GetSummaryText(town)
	{
		if (!permanent_growth.Enabled() || GSController.GetSetting("PGC_ShowInTownWindow") == 0) {
			return GSText(GSText.STR_EMPTY);
		}

		local town_data = permanent_growth.EnsureTown(town);
		local unique = town_data.unique;
		local cargo_data = permanent_growth.EnsureCargoData(town, unique);
		local bonus = permanent_growth.GetBonusPercent(town);
		local label = GSCargo.GetCargoLabel(unique);

		return GSText(GSText.STR_PGC_SUMMARY, bonus, label, cargo_data.level, cargo_data.counter, cargo_data.limit);
	}
};
