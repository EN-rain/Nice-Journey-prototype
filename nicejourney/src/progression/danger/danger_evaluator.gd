class_name DangerEvaluator
extends RefCounted

enum Rank {
    I = 1,
    II = 2,
    III = 3,
    IV = 4,
    V = 5,
}

static func evaluate_rank(player_level: int, recommended_level: int) -> Rank:
    var deficit: int = maxi(0, recommended_level - player_level)
    if deficit == 0:
        return Rank.I
    if deficit == 1:
        return Rank.II
    if deficit == 2:
        return Rank.III
    if deficit <= 4:
        return Rank.IV
    return Rank.V

static func display_name(rank: Rank) -> String:
    match rank:
        Rank.I:
            return "DANGER I - Dangerous"
        Rank.II:
            return "DANGER II - Severe"
        Rank.III:
            return "DANGER III - Extreme"
        Rank.IV:
            return "DANGER IV - Lethal"
        Rank.V:
            return "DANGER V - Catastrophic"
        _:
            return "Unknown"

static func requires_explicit_travel_confirmation(rank: Rank) -> bool:
    return rank >= Rank.III
