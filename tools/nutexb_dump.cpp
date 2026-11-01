// .nutexb を PNG に書き出す確認用ツール
//   使い方: nutexb_dump <入力.nutexb> [出力フォルダ]
//   レイヤーごとに <出力フォルダ>/<ファイル名>_<レイヤー番号>.png を書き出す
#include <cstdio>
#include <string>

#include "Nutexb.hpp"
#include "raylib.h"

int main(int argc, char** argv) {
    if (argc < 2) {
        std::printf("usage: nutexb_dump <input.nutexb> [output_dir]\n");
        return 1;
    }
    SetTraceLogLevel(LOG_WARNING);

    const char* input = argv[1];
    const std::string outDir = argc >= 3 ? argv[2] : GetDirectoryPath(input);

    GuminTaiko::NutexbFile file;
    std::string error;
    if (!GuminTaiko::LoadNutexb(input, file, &error)) {
        std::printf("error: %s\n", error.c_str());
        return 1;
    }

    std::printf("name=%s size=%dx%d depth=%d format=%s mips=%d layers=%d\n", file.name.c_str(), file.width,
                file.height, file.depth, GuminTaiko::NutexbFormatName(file.format), file.mipCount, file.layerCount);

    const std::string base = GetFileNameWithoutExt(input);
    for (size_t i = 0; i < file.layers.size(); ++i) {
        const std::string path = outDir + "/" + base + "_" + std::to_string(i) + ".png";
        const bool ok = ExportImage(file.layers[i], path.c_str());
        std::printf("%s %s\n", ok ? "wrote" : "failed", path.c_str());
    }

    GuminTaiko::UnloadNutexb(file);
    return 0;
}
