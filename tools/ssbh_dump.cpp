// SSBH モデル（.numdlb とその参照先）の中身を表示する確認用ツール
//   使い方: ssbh_dump <モデルのフォルダ>/<名前>.numdlb
#include <algorithm>
#include <cstdio>
#include <map>
#include <string>

#include "Ssbh.hpp"

int main(int argc, char** argv) {
    if (argc < 2) {
        std::printf("usage: ssbh_dump <model.numdlb>\n");
        return 1;
    }
    const std::string modelPath = argv[1];
    const std::string dir = modelPath.substr(0, modelPath.find_last_of("/\\") + 1);

    Ssbh::Model model;
    std::string error;
    if (!Ssbh::LoadModel(modelPath, model, &error)) {
        std::printf("error: %s\n", error.c_str());
        return 1;
    }
    std::printf("skeleton=%s mesh=%s anim=%s\n", model.skeletonFile.c_str(), model.meshFile.c_str(), model.animationFile.c_str());
    for (const auto& m : model.materialFiles) std::printf("material file: %s\n", m.c_str());
    for (const auto& e : model.entries) std::printf("entry: %s[%llu] -> %s\n", e.meshObjectName.c_str(), (unsigned long long)e.subIndex, e.materialLabel.c_str());

    for (const auto& file : model.materialFiles) {
        Ssbh::Materials materials;
        if (!Ssbh::LoadMaterials(dir + file, materials, &error)) {
            std::printf("material error: %s\n", error.c_str());
            continue;
        }
        std::printf("== %s\n", file.c_str());
        for (const auto& m : materials.entries) {
            std::printf("  material %s shader=%s\n", m.label.c_str(), m.shader.c_str());
            for (const auto& p : m.params) {
                std::printf("    param id=%llu type=%llu", (unsigned long long)p.id, (unsigned long long)p.type);
                if (!p.text.empty()) std::printf(" text=%s", p.text.c_str());
                if (p.type == 1 || p.type == 5 || p.type == 2) std::printf(" value=(%.3f %.3f %.3f %.3f)", p.vector[0], p.vector[1], p.vector[2], p.vector[3]);
                std::printf("\n");
            }
        }
    }

    Ssbh::Mesh mesh;
    if (!Ssbh::LoadMesh(dir + model.meshFile, mesh, &error)) {
        std::printf("mesh error: %s\n", error.c_str());
        return 1;
    }
    std::printf("== mesh v%u.%u objects=%zu\n", mesh.major, mesh.minor, mesh.objects.size());
    for (const auto& o : mesh.objects) {
        std::printf("  object %s[%llu] parent=%s verts=%u indices=%u skin=%d influences=%zu\n", o.name.c_str(),
                    (unsigned long long)o.subIndex, o.parentBoneName.c_str(), o.vertexCount, o.indexCount, o.useSkinning,
                    o.influences.size());
        for (const auto& a : o.attributes) {
            std::printf("    attr %-12s usage=%u type=%u buffer=%u offset=%u\n", a.name.c_str(), a.usage, a.dataType, a.bufferIndex, a.bufferOffset);
        }
        if (!o.positions.empty()) {
            float mn[3] = {1e9f, 1e9f, 1e9f}, mx[3] = {-1e9f, -1e9f, -1e9f};
            for (const auto& p : o.positions) {
                for (int k = 0; k < 3; ++k) {
                    mn[k] = std::min(mn[k], p[size_t(k)]);
                    mx[k] = std::max(mx[k], p[size_t(k)]);
                }
            }
            std::printf("    bounds (%.3f %.3f %.3f) - (%.3f %.3f %.3f)\n", mn[0], mn[1], mn[2], mx[0], mx[1], mx[2]);
        }
        for (size_t u = 0; u < o.uvs.size(); ++u) {
            float mn[2] = {1e9f, 1e9f}, mx[2] = {-1e9f, -1e9f};
            for (const auto& t : o.uvs[u]) {
                for (int k = 0; k < 2; ++k) {
                    mn[k] = std::min(mn[k], t[size_t(k)]);
                    mx[k] = std::max(mx[k], t[size_t(k)]);
                }
            }
            std::printf("    uv %s (%.3f %.3f) - (%.3f %.3f)\n", o.uvNames[u].c_str(), mn[0], mn[1], mx[0], mx[1]);
        }
        uint32_t maxIndex = 0;
        for (uint32_t i : o.indices) maxIndex = std::max(maxIndex, i);
        std::printf("    max index %u\n", maxIndex);

        // 重みの合計の確認
        std::map<int, float> sums;
        for (const auto& inf : o.influences) {
            for (const auto& w : inf.weights) sums[w.vertex] += w.weight;
        }
        float minSum = 9.0f, maxSum = 0.0f;
        for (auto& s : sums) {
            minSum = std::min(minSum, s.second);
            maxSum = std::max(maxSum, s.second);
        }
        if (!sums.empty()) std::printf("    weight sums %.3f - %.3f over %zu vertices\n", minSum, maxSum, sums.size());
        for (size_t b = 0; b < o.influences.size(); ++b) std::printf("      bone %s (%zu)\n", o.influences[b].boneName.c_str(), o.influences[b].weights.size());
    }

    Ssbh::Skeleton skeleton;
    if (Ssbh::LoadSkeleton(dir + model.skeletonFile, skeleton, &error)) {
        std::printf("== skeleton bones=%zu\n", skeleton.bones.size());
        for (const auto& b : skeleton.bones) {
            std::printf("  %2d %-24s parent=%d world.t=(%.3f %.3f %.3f)\n", b.index, b.name.c_str(), b.parent, b.world[12], b.world[13], b.world[14]);
        }
    } else {
        std::printf("skeleton error: %s\n", error.c_str());
    }
    return 0;
}
