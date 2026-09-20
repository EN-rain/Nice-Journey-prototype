class_name StableId
extends RefCounted

const _ALLOWED_EXTRA: String = "_-.:/"

static func is_valid(value: String) -> bool:
    if value.is_empty() or value != value.strip_edges():
        return false
    for index: int in value.length():
        var character: String = value.substr(index, 1)
        if character.to_lower() >= "a" and character.to_lower() <= "z":
            continue
        if character >= "0" and character <= "9":
            continue
        if _ALLOWED_EXTRA.contains(character):
            continue
        return false
    return true
