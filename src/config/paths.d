module gsb.config.paths;
import gsb.engine.pathconfig;

void gsb_setupPaths (IPathConfig paths) {
    paths["MODULE_SRC"] = "${PROJ_DIR}/src/components";
    paths["SHADER_SRC"] = "${PROJ_DIR}/src/shaders";
    paths["ASSETS"]     = "${PROJ_DIR}/assets";

    version (OSX) {
        paths["DATA_DIR"] = "~/Library/Application Support/${PROJ_NAME}";
    } else version (Windows) {
        paths["DATA_DIR"] = paths.getWinAppdataDir().joinPaths("${PROJ_NAME}");
    } else version (Linux) {
        paths["DATA_DIR"] = "~/.config/${PROJ_NAME}";
    }
    paths["CACHE_DIR"]    = "${DATA_DIR}/cache";
    paths["MODULE_BUILD"] = "${CACHE_DIR}/modules/build";
    paths["MODULE_LIB"]   = "${CACHE_DIR}/modules/lib";
    paths["TEMP_DATA"]    = "${CACHE_DIR}/temp";

    paths["APP_STATE"]    = "${DATA_DIR}/state";
}
