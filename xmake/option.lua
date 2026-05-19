-- Board variant option (mirrors presets/*.cmake + CMakePresets.json VARIANT cache variable)
-- Usage: xmake f --variant=OLLIE

option("variant")
    set_default("CANABLE")
    set_values("CANABLE", "ENTREE", "CANTACT_8", "CANTACT_16", "OLLIE")
    set_description("Target board variant")
option_end()
