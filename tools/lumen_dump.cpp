// .nulm（Lumen）の構造を表示する確認用ツール
//   使い方: lumen_dump <入力.nulm> [スプライトID（詳細表示）] [表示するフレーム数]
#include <cstdio>
#include <cstdlib>
#include <map>
#include <string>

#include "Lumen.hpp"

namespace {

void CountValue(std::map<std::string, std::map<long long, int>>& stats, const char* key, long long value) {
    ++stats[key][value];
}

} // namespace

int main(int argc, char** argv) {
    if (argc < 2) {
        std::printf("usage: lumen_dump <input.nulm> [sprite_id] [frames]\n");
        return 1;
    }

    Lumen::File file;
    std::string error;
    if (!Lumen::Load(argv[1], file, &error)) {
        std::printf("error: %s\n", error.c_str());
        return 1;
    }
    // "tree" を指定すると、ルートからのインスタンス名とラベルの木を表示する
    if (argc >= 3 && std::string(argv[2]) == "tree") {
        struct Printer {
            const Lumen::File& file;
            void Print(int spriteId, int indent, int depthLimit) {
                auto found = file.sprites.find(spriteId);
                if (found == file.sprites.end() || indent > depthLimit) return;
                const Lumen::Sprite& s = found->second;
                if (!s.labels.empty()) {
                    std::printf("%*s  labels:", indent * 2, "");
                    for (const Lumen::Label& l : s.labels) std::printf(" %s@%d", l.name.c_str(), l.frame);
                    std::printf("\n");
                }
                std::map<std::string, int> seen;
                for (const auto* frames : {&s.frames}) {
                    for (const Lumen::Frame& f : *frames) {
                        for (const Lumen::FrameCommand& c : f.commands) {
                            if (c.type != Lumen::FrameCommand::Type::Place || c.place.mode == 2) continue;
                            const std::string& name = file.Symbol(c.place.nameSymbol);
                            if (name.empty() || seen.count(name + "#" + std::to_string(c.place.characterId))) continue;
                            seen[name + "#" + std::to_string(c.place.characterId)] = 1;
                            const char* kind = file.sprites.count(c.place.characterId) ? "clip"
                                             : file.texts.count(c.place.characterId) ? "text" : "shape";
                            std::printf("%*s%s (%s %d)\n", indent * 2 + 2, "", name.c_str(), kind, c.place.characterId);
                            Print(c.place.characterId, indent + 1, depthLimit);
                        }
                    }
                }
            }
        } printer{file};
        std::printf("root %d\n", file.rootId);
        printer.Print(file.rootId, 0, argc >= 4 ? std::atoi(argv[3]) : 6);
        return 0;
    }

    const int detailId = argc >= 3 ? std::atoi(argv[2]) : -1;
    const int detailFrames = argc >= 4 ? std::atoi(argv[3]) : 20;

    std::printf("root=%d fps=%.1f size=%.0fx%.0f\n", file.rootId, file.frameRate, file.width, file.height);
    std::printf("symbols=%zu colors=%zu transforms=%zu positions=%zu bounds=%zu actions=%zu\n", file.symbols.size(),
                file.colors.size(), file.transforms.size(), file.positions.size(), file.bounds.size(), file.actions.size());
    if (argc >= 3 && std::string(argv[2]) == "colors") {
        for (size_t i = 0; i < file.colors.size(); ++i)
            std::printf("color %zu: %.4f %.4f %.4f %.4f\n", i, file.colors[i].r, file.colors[i].g, file.colors[i].b, file.colors[i].a);
        for (const auto& t : file.texts) std::printf("text %d html=%s\n", t.second.id, t.second.initialHtml.c_str());
        return 0;
    }
    if (argc >= 3 && std::string(argv[2]) == "pos") {
        // 座標（配置の tf=N/8000 の N 番）を並べる
        for (size_t i = 0; i < file.positions.size(); ++i) std::printf("pos %zu: %.1f %.1f\n", i, file.positions[i].x, file.positions[i].y);
        return 0;
    }
    std::printf("properties:");
    for (uint32_t v : file.properties) std::printf(" %X", v);
    std::printf("\ndefines:");
    for (uint32_t v : file.defines) std::printf(" %X", v);
    std::printf("\n");
    for (const Lumen::Atlas& a : file.atlases) std::printf("atlas %d '%s' %.0fx%.0f\n", a.id, a.name.c_str(), a.width, a.height);
    for (size_t i = 0; i < file.bounds.size(); ++i) {
        const Lumen::Rect& b = file.bounds[i];
        std::printf("bounds %zu: %.1f %.1f %.1f %.1f\n", i, b.left, b.top, b.right, b.bottom);
    }
    for (auto& entry : file.texts) {
        const Lumen::TextField& t = entry.second;
        std::printf("text %d bounds=%d font=%d align=%d size=%.1f raw:", t.id, t.bounds, t.font, t.align, t.size);
        for (uint32_t w : t.raw) std::printf(" %X", w);
        std::printf("\n");
    }
    for (auto& t : file.unknownTags) std::printf("unknown tag %04X x%d\n", t.first, t.second);

    for (size_t i = 0; i < file.actions.size(); ++i) {
        std::printf("action %zu:", i);
        for (uint8_t b : file.actions[i]) std::printf(" %02X", b);
        std::printf("\n");
    }

    std::printf("\n-- shapes --\n");
    for (auto& entry : file.shapes) {
        const Lumen::Shape& s = entry.second;
        std::printf("shape %d bounds=%d graphics=%zu", s.id, s.bounds, s.graphics.size());
        for (const Lumen::Graphic& g : s.graphics) {
            std::printf(" [atlas=%d fill=%X v=%zu i=%zu", g.atlas, g.fillType, g.vertices.size(), g.indices.size());
            if (!g.vertices.empty()) {
                std::printf(" (%.1f,%.1f uv %.4f,%.4f)", g.vertices[0].x, g.vertices[0].y, g.vertices[0].u, g.vertices[0].v);
            }
            std::printf("]");
        }
        std::printf("\n");
    }

    std::printf("\n-- sprites --\n");
    std::map<std::string, std::map<long long, int>> stats;
    for (auto& entry : file.sprites) {
        const Lumen::Sprite& s = entry.second;
        std::printf("sprite %d frames=%zu/%u keyframes=%zu/%u header:", s.id, s.frames.size(), s.header[4],
                    s.keyFrames.size(), s.header[5]);
        for (uint32_t h : s.header) std::printf(" %X", h);
        std::printf("\n");
        for (const Lumen::Label& l : s.labels) std::printf("    label '%s' @%d\n", l.name.c_str(), l.frame);

        for (const auto* frames : {&s.frames, &s.keyFrames}) {
            for (const Lumen::Frame& f : *frames) {
                for (const Lumen::FrameCommand& c : f.commands) {
                    if (c.type == Lumen::FrameCommand::Type::Place) {
                        const Lumen::Placement& p = c.place;
                        CountValue(stats, "place.mode", p.mode);
                        CountValue(stats, "place.blend", p.blendMode);
                        CountValue(stats, "place.flags", p.transformFlags);
                        CountValue(stats, "place.w2", p.raw[2]);
                        CountValue(stats, "place.w5hi", p.raw[5] >> 16);
                        CountValue(stats, "place.w6", p.raw[6]);
                        CountValue(stats, "place.w10", p.raw[10]);
                        CountValue(stats, "place.w11", p.raw[11]);
                    } else if (c.type == Lumen::FrameCommand::Type::Remove) {
                        CountValue(stats, "remove.size", static_cast<long long>(c.raw.size()));
                        CountValue(stats, "remove.w0", c.raw.empty() ? -1 : c.raw[0]);
                    } else if (c.type == Lumen::FrameCommand::Type::Action) {
                        CountValue(stats, "action.id", c.actionId);
                        CountValue(stats, "action.w1", c.raw.size() > 1 ? c.raw[1] : -1);
                    } else {
                        CountValue(stats, "unknown.tag", c.tag);
                    }
                }
            }
        }

        if (s.id != detailId) continue;
        int shown = 0;
        for (const Lumen::Frame& f : s.frames) {
            if (shown++ >= detailFrames) break;
            std::printf("  frame %d\n", f.id);
            for (const Lumen::FrameCommand& c : f.commands) {
                if (c.type == Lumen::FrameCommand::Type::Place) {
                    const Lumen::Placement& p = c.place;
                    std::printf("    place char=%d plc=%d name='%s' mode=%d blend=%d depth=%d tf=%d/%X cm=%d ca=%d raw:",
                                p.characterId, p.placementId, file.Symbol(p.nameSymbol).c_str(), p.mode, p.blendMode,
                                p.depth, p.transformIndex, p.transformFlags, p.colorMult, p.colorAdd);
                    for (uint32_t w : p.raw) std::printf(" %X", w);
                    std::printf("\n");
                } else {
                    std::printf("    tag %04X:", c.tag);
                    for (uint32_t w : c.raw) std::printf(" %X", w);
                    std::printf("\n");
                }
            }
        }
    }

    std::printf("\n-- stats --\n");
    for (auto& s : stats) {
        std::printf("%s:", s.first.c_str());
        int n = 0;
        for (auto& v : s.second) {
            if (n++ > 12) {
                std::printf(" ...");
                break;
            }
            std::printf(" %llX(x%d)", v.first, v.second);
        }
        std::printf("\n");
    }
    return 0;
}
